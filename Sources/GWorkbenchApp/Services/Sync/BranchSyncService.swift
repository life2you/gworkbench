import Foundation

enum MainlineRestoreResult: Sendable, Equatable {
    case notConfigured
    case alreadyOnMainline(branch: String)
    case switched(branch: String)
    case branchNotFound(candidates: [String])
    case failed(branch: String, message: String)

    var logLine: String {
        switch self {
        case .notConfigured:
            return "未配置主干分支，保持停留在当前分支"
        case .alreadyOnMainline(let branch):
            return "当前已在主干分支: \(branch)"
        case .switched(let branch):
            return "已自动切换回主干分支: \(branch)"
        case .branchNotFound(let candidates):
            return "未切回主干分支: 仓库中未找到已配置的主干分支 (\(candidates.joined(separator: ", ")))"
        case .failed(let branch, let message):
            return "切回主干分支失败 (\(branch)): \(message)"
        }
    }
}

struct LocalBranchExecutionResult: Sendable {
    let sourceBranch: String
    let targetBranch: String
    let success: Bool
    let message: String
}

final class BranchSyncService: Sendable {
    let gitCli: GitCliService

    init(gitCli: GitCliService = GitCliService()) {
        self.gitCli = gitCli
    }

    func effectiveMRBranchMappings(config: MergeWorkflowConfig) -> [BranchMapping] {
        let currentDefaults = config.envBranches.map {
            BranchMapping(
                source: "\($0)_\(config.mergeBranchMiddle)",
                target: $0,
                protectedTarget: config.protectedTargets.contains($0)
            )
        }

        let hasCustomMappings = config.branchMap.contains { source, target in
            source != "\(target)_\(config.mergeBranchMiddle)"
        }

        if !hasCustomMappings {
            return currentDefaults.sorted { $0.source < $1.source }
        }

        var merged = Dictionary(uniqueKeysWithValues: currentDefaults.map { ($0.source, $0.target) })
        for (source, target) in config.branchMap {
            let isDefaultLike = source == "\(target)_\(config.mergeBranchMiddle)" || source == "\(target)_\(config.mergeBranchMiddle)_meger"
            let targetIsCurrentEnv = config.envBranches.contains(target)
            if isDefaultLike && !targetIsCurrentEnv {
                continue
            }
            merged[source] = target
        }

        return merged
            .map { source, target in
                BranchMapping(
                    source: source,
                    target: target,
                    protectedTarget: config.protectedTargets.contains(target)
                )
            }
            .sorted { lhs, rhs in
                if lhs.source != rhs.source {
                    return lhs.source < rhs.source
                }
                return lhs.target < rhs.target
            }
    }

    func localTargetMergeBranches(config: MergeWorkflowConfig, projectName: String) -> [(String, String)] {
        config.envBranches.map { envBranch in
            if let mapped = config.branchMap.first(where: { $0.value == envBranch })?.key {
                return (envBranch, mapped)
            }
            return (envBranch, mergeBranchName(envBranch: envBranch, config: config, projectName: projectName))
        }
    }

    static func mergeBranchName(envBranch: String, middle: String, projectName: String) -> String {
        let actualMiddle = middle == "PROJECT_NAME" ? projectName : middle
        return "\(envBranch)_\(actualMiddle)"
    }

    func mergeBranchName(envBranch: String, config: MergeWorkflowConfig, projectName: String) -> String {
        Self.mergeBranchName(envBranch: envBranch, middle: config.mergeBranchMiddle, projectName: projectName)
    }

    func loadLocalMergeContext(
        config: MergeWorkflowConfig,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> LocalMergeContext {
        onProgress(.init(title: "扫描本地项目", detail: "正在读取可用仓库", current: 1, total: 3))
        let localProjects = try await Task.detached(priority: .userInitiated) {
            try self.gitCli.scanLocalProjects(
                rootDirs: config.rootDirs,
                forcedPlatform: config.forcedPlatform
            )
        }.value

        onProgress(.init(title: "整理分支数据", detail: "正在读取本地分支与目标映射", current: 2, total: 3))
        let mappings = effectiveMRBranchMappings(config: config)
        let gitCli = self.gitCli

        // 使用 concurrentPerform 而非 withThrowingTaskGroup：
        // 每个任务都执行阻塞式 git 子进程，放在协作线程池上可能占满线程并导致任务组永不完成。
        final class MergeProjectCollector: @unchecked Sendable {
            private var items: [MergeProject] = []
            private let lock = NSLock()
            func append(_ item: MergeProject) {
                lock.lock()
                defer { lock.unlock() }
                items.append(item)
            }
            var all: [MergeProject] {
                lock.lock()
                defer { lock.unlock() }
                return items
            }
        }

        let collector = MergeProjectCollector()
        let targets = localProjects

        DispatchQueue.concurrentPerform(iterations: targets.count) { index in
            let project = targets[index]
            let remoteBranches = (try? gitCli.remoteBranches(projectPath: project.path)) ?? []
            let localBranches = (try? gitCli.localBranches(projectPath: project.path)) ?? []
            collector.append(
                MergeProject(
                    id: project.id,
                    name: project.name,
                    displayName: project.displayName,
                    path: project.path,
                    sourceRoot: project.sourceRoot,
                    currentBranch: project.currentBranch,
                    gitLabProjectID: nil,
                    branchMappings: mappings,
                    remoteBranches: remoteBranches,
                    localBranches: localBranches,
                    remoteURL: project.remoteURL,
                    platform: project.platform
                )
            )
        }

        let projects = collector.all.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }

        onProgress(.init(title: "完成", detail: "已加载 \(projects.count) 个本地同步项目", current: 3, total: 3))
        return LocalMergeContext(config: config, projects: projects)
    }

    func executeLocalSync(
        context: LocalMergeContext,
        project: MergeProject,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            let results = try self.syncAndPushWithProgress(project: project, config: context.config, onProgress: onProgress)
            return results.map { result in
                let prefix = result.success ? "成功" : "失败"
                return "\(prefix): \(result.sourceBranch) -> \(result.targetBranch): \(result.message)"
            }
        }.value
    }

    func executeLocalMerge(
        context: LocalMergeContext,
        project: MergeProject,
        sourceBranch: String,
        targets: [String],
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            let results = try self.mergeToTargetsWithProgress(
                project: project,
                config: context.config,
                sourceBranch: sourceBranch,
                targets: targets,
                onProgress: onProgress
            )
            return results.map { result in
                let prefix = result.success ? "成功" : "失败"
                return "\(prefix): \(result.sourceBranch) -> \(result.targetBranch): \(result.message)"
            }
        }.value
    }

    func syncAndPushWithProgress(
        project: MergeProject,
        config: MergeWorkflowConfig,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) throws -> [LocalBranchExecutionResult] {
        let targets = localTargetMergeBranches(config: config, projectName: project.name)
        var results: [LocalBranchExecutionResult] = []
        let hasMainline = !config.mainlineBranches.filterNonEmpty().isEmpty
        let totalSteps = max(targets.count * 2 + (hasMainline ? 1 : 0), 1)
        var currentStep = 0

        for (envBranch, mergeBranch) in targets {
            currentStep += 1
            onProgress(.init(
                title: "更新环境分支",
                detail: "\(envBranch) -> \(mergeBranch)",
                current: currentStep,
                total: totalSteps
            ))

            do {
                try updateBranch(projectPath: project.path, branch: envBranch)
            } catch {
                results.append(.init(
                    sourceBranch: envBranch,
                    targetBranch: mergeBranch,
                    success: false,
                    message: "更新分支失败: \(error.localizedDescription)"
                ))
                continue
            }

            currentStep += 1
            onProgress(.init(
                title: "同步合并分支",
                detail: "\(envBranch) -> \(mergeBranch)",
                current: currentStep,
                total: totalSteps
            ))

            do {
                let message = try syncToMergeBranch(projectPath: project.path, sourceBranch: envBranch, mergeBranch: mergeBranch)
                results.append(.init(
                    sourceBranch: envBranch,
                    targetBranch: mergeBranch,
                    success: true,
                    message: message
                ))
            } catch {
                results.append(.init(
                    sourceBranch: envBranch,
                    targetBranch: mergeBranch,
                    success: false,
                    message: error.localizedDescription
                ))
            }
        }

        let restoreResult = restoreMainlineBranchIfConfigured(
            projectPath: project.path,
            mainlineBranches: config.mainlineBranches
        )
        if case .notConfigured = restoreResult {
            onProgress(.init(
                title: "保持当前分支",
                detail: restoreResult.logLine,
                current: totalSteps,
                total: totalSteps
            ))
        } else {
            currentStep += 1
            onProgress(.init(
                title: "切回主干分支",
                detail: restoreResult.logLine,
                current: totalSteps,
                total: totalSteps
            ))
        }

        return results
    }

    func mergeToTargetsWithProgress(
        project: MergeProject,
        config: MergeWorkflowConfig,
        sourceBranch: String,
        targets: [String],
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) throws -> [LocalBranchExecutionResult] {
        guard !targets.isEmpty else {
            throw WorkbenchError.message("未选择目标分支")
        }

        guard try gitCli.localBranchExists(projectPath: project.path, branch: sourceBranch) else {
            throw WorkbenchError.message("源分支不存在: \(sourceBranch)")
        }

        let hasMainline = !config.mainlineBranches.filterNonEmpty().isEmpty
        let totalSteps = targets.count + (hasMainline ? 1 : 0)
        var results: [LocalBranchExecutionResult] = []
        for (index, target) in targets.enumerated() {
            onProgress(.init(
                title: "合并并推送目标分支",
                detail: "\(sourceBranch) -> \(target)",
                current: index + 1,
                total: totalSteps
            ))

            do {
                let message = try syncToMergeBranch(projectPath: project.path, sourceBranch: sourceBranch, mergeBranch: target)
                results.append(.init(
                    sourceBranch: sourceBranch,
                    targetBranch: target,
                    success: true,
                    message: message
                ))
            } catch {
                results.append(.init(
                    sourceBranch: sourceBranch,
                    targetBranch: target,
                    success: false,
                    message: error.localizedDescription
                ))
            }
        }

        let restoreResult = restoreMainlineBranchIfConfigured(
            projectPath: project.path,
            mainlineBranches: config.mainlineBranches
        )
        if case .notConfigured = restoreResult {
            onProgress(.init(
                title: "保持当前分支",
                detail: restoreResult.logLine,
                current: totalSteps,
                total: totalSteps
            ))
        } else {
            onProgress(.init(
                title: "切回主干分支",
                detail: restoreResult.logLine,
                current: totalSteps,
                total: totalSteps
            ))
        }

        return results
    }

    /// 同步/合并完成后，若配置了主干分支，则自动切回首个命中的主干分支；未配置则不做任何切换。
    func restoreMainlineBranchIfConfigured(
        projectPath: String,
        mainlineBranches: [String]
    ) -> MainlineRestoreResult {
        let candidates = mainlineBranches.filterNonEmpty()
        guard !candidates.isEmpty else {
            return .notConfigured
        }

        let current = (try? gitCli.currentLocalBranch(projectPath: projectPath))?.trimmingCharacters(in: .whitespacesAndNewlines)

        for candidate in candidates {
            if current == candidate {
                return .alreadyOnMainline(branch: candidate)
            }
            do {
                if try gitCli.localBranchExists(projectPath: projectPath, branch: candidate) {
                    try gitCli.checkoutBranch(projectPath: projectPath, branch: candidate)
                    return .switched(branch: candidate)
                }
                if try gitCli.remoteBranchExists(projectPath: projectPath, branch: candidate) {
                    try gitCli.checkoutNewBranch(projectPath: projectPath, branch: candidate, from: "origin/\(candidate)")
                    return .switched(branch: candidate)
                }
            } catch {
                return .failed(branch: candidate, message: error.localizedDescription)
            }
        }

        return .branchNotFound(candidates: candidates)
    }

    func updateBranch(projectPath: String, branch: String) throws {
        if try gitCli.localBranchExists(projectPath: projectPath, branch: branch) {
            try gitCli.checkoutBranch(projectPath: projectPath, branch: branch)
        } else if try gitCli.remoteBranchExists(projectPath: projectPath, branch: branch) {
            try gitCli.checkoutNewBranch(projectPath: projectPath, branch: branch, from: "origin/\(branch)")
        } else {
            throw WorkbenchError.message("分支不存在: \(branch)")
        }

        try gitCli.pull(projectPath: projectPath, remote: "origin", branch: branch)
    }

    func syncToMergeBranch(projectPath: String, sourceBranch: String, mergeBranch: String) throws -> String {
        if try gitCli.localBranchExists(projectPath: projectPath, branch: mergeBranch) {
            try gitCli.checkoutBranch(projectPath: projectPath, branch: mergeBranch)
        } else if try gitCli.remoteBranchExists(projectPath: projectPath, branch: mergeBranch) {
            try gitCli.checkoutNewBranch(projectPath: projectPath, branch: mergeBranch, from: "origin/\(mergeBranch)")
        } else {
            try gitCli.checkoutNewBranch(projectPath: projectPath, branch: mergeBranch, from: sourceBranch)
            try gitCli.push(projectPath: projectPath, remote: "origin", branch: mergeBranch)
            return "创建并推送新分支: \(mergeBranch)"
        }

        switch try gitCli.mergeBranch(projectPath: projectPath, sourceBranch: sourceBranch) {
        case .success:
            try gitCli.push(projectPath: projectPath, remote: "origin", branch: mergeBranch)
            return "同步完成: \(sourceBranch) -> \(mergeBranch)"
        case .alreadyUpToDate:
            return "已是最新: \(sourceBranch) -> \(mergeBranch)"
        case .conflict(let files):
            let fileList = files.isEmpty ? "（无法获取冲突文件）" : files.joined(separator: ", ")
            throw WorkbenchError.message("合并冲突已自动中止: \(sourceBranch) -> \(mergeBranch)，冲突文件: \(fileList)")
        }
    }

    /// 交互式单步同步目标分支：发生冲突时不中止，返回 `.conflict(files)` 留给上层处理
    func syncToMergeBranchInteractive(projectPath: String, sourceBranch: String, mergeBranch: String) throws -> GitMergeExecutionResult {
        if try gitCli.localBranchExists(projectPath: projectPath, branch: mergeBranch) {
            try gitCli.checkoutBranch(projectPath: projectPath, branch: mergeBranch)
            try? gitCli.pull(projectPath: projectPath, remote: "origin", branch: mergeBranch)
        } else if try gitCli.remoteBranchExists(projectPath: projectPath, branch: mergeBranch) {
            try gitCli.checkoutNewBranch(projectPath: projectPath, branch: mergeBranch, from: "origin/\(mergeBranch)")
        } else {
            try gitCli.checkoutNewBranch(projectPath: projectPath, branch: mergeBranch, from: sourceBranch)
            try gitCli.push(projectPath: projectPath, remote: "origin", branch: mergeBranch)
            return .success
        }

        let result = try gitCli.mergeBranchInteractive(projectPath: projectPath, sourceBranch: sourceBranch)
        if case .success = result {
            try gitCli.push(projectPath: projectPath, remote: "origin", branch: mergeBranch)
        }
        return result
    }

    /// 完成冲突解决并提交推送
    func commitAndPushResolvedMerge(projectPath: String, mergeBranch: String) throws {
        try gitCli.commitMerge(projectPath: projectPath)
        try gitCli.push(projectPath: projectPath, remote: "origin", branch: mergeBranch)
    }

    /// 中止当前目标分支的合并现场
    func abortMerge(projectPath: String) throws {
        try gitCli.abortMerge(projectPath: projectPath)
    }
}
