import Foundation

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
                source: "\($0)_\(config.mergeBranchMiddle)_meger",
                target: $0,
                protectedTarget: config.protectedTargets.contains($0)
            )
        }

        let hasCustomMappings = config.branchMap.contains { source, target in
            source != "\(target)_\(config.mergeBranchMiddle)_meger"
        }

        if !hasCustomMappings {
            return currentDefaults.sorted { $0.source < $1.source }
        }

        var merged = Dictionary(uniqueKeysWithValues: currentDefaults.map { ($0.source, $0.target) })
        for (source, target) in config.branchMap {
            let isDefaultLike = source == "\(target)_\(config.mergeBranchMiddle)_meger"
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
            (envBranch, mergeBranchName(envBranch: envBranch, config: config, projectName: projectName))
        }
    }

    static func mergeBranchName(envBranch: String, middle: String, projectName: String) -> String {
        let actualMiddle = middle == "PROJECT_NAME" ? projectName : middle
        return "\(envBranch)_\(actualMiddle)_meger"
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
            try self.gitCli.scanLocalProjects(rootDirs: config.rootDirs)
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
        let totalSteps = max(targets.count * 2, 1)
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

        return results
    }

    func mergeToTargetsWithProgress(
        project: MergeProject,
        config _: MergeWorkflowConfig,
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

        var results: [LocalBranchExecutionResult] = []
        for (index, target) in targets.enumerated() {
            onProgress(.init(
                title: "合并并推送目标分支",
                detail: "\(sourceBranch) -> \(target)",
                current: index + 1,
                total: targets.count
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
        return results
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
}
