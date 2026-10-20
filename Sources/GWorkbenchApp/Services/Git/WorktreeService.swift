import Foundation

final class DiskUsageStore: @unchecked Sendable {
    static let shared = DiskUsageStore()
    private var cache: [String: String] = [:]
    private let lock = NSLock()

    func get(_ path: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return cache[path]
    }

    func set(_ usage: String, for path: String) {
        lock.lock()
        defer { lock.unlock() }
        cache[path] = usage
    }
}

final class WorktreeService: Sendable {
    let gitCli: GitCliService
    let configService: ConfigService

    init(
        gitCli: GitCliService = GitCliService(),
        configService: ConfigService = ConfigService()
    ) {
        self.gitCli = gitCli
        self.configService = configService
    }

    func loadWorktreeSnapshot(
        config: WorktreeConfig,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> WorktreeSnapshot {
        try await Task.detached(priority: .userInitiated) {
            onProgress(.init(title: "扫描项目", detail: "正在快速扫描本地仓库", current: 1, total: 3))
            let projects = try self.gitCli.scanLocalProjects(rootDirs: config.projectsRootDirs)
            let metadataMap = try self.configService.loadWorktreeMetadataMap(metadataPath: config.metadataPath)

            onProgress(.init(title: "读取工作树", detail: "正在并行解析工作树与提交信息", current: 2, total: 3))

            // 使用 concurrentPerform 而非 withTaskGroup：
            // TaskGroup 的任务跑在 Swift 协作线程池上，而这里每个任务都是阻塞式 Process 调用，
            // 会占满协作线程并导致任务组永远无法完成（界面因此一直空白）。
            // concurrentPerform 使用 GCD 线程池，阻塞是预期行为，不会饿死协作线程。
            final class WorktreeCollector: @unchecked Sendable {
                private var items: [WorktreeItem] = []
                private let lock = NSLock()
                func append(contentsOf newItems: [WorktreeItem]) {
                    lock.lock()
                    defer { lock.unlock() }
                    items.append(contentsOf: newItems)
                }
                var all: [WorktreeItem] {
                    lock.lock()
                    defer { lock.unlock() }
                    return items
                }
            }

            let collector = WorktreeCollector()
            let scanTargets = projects

            DispatchQueue.concurrentPerform(iterations: scanTargets.count) { index in
                let project = scanTargets[index]
                let entries = (try? self.gitCli.parseWorktreeList(projectPath: project.path)) ?? []
                var projectWorktrees: [WorktreeItem] = []
                for entry in entries {
                    var isDirectory: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDirectory),
                          isDirectory.boolValue else {
                        continue
                    }

                    let branch = entry.branch ?? "(detached)"
                    let description = entry.branch.flatMap {
                        metadataMap["\(ProcessRunner.normalizePath(project.path))#\($0)"]
                    }
                    let commitInfo = (try? self.gitCli.loadCommitInfo(worktreePath: entry.path)) ?? CommitInfo(headLine: "尚无提交记录", updatedAt: "未提交", commits: [])
                    let isMainRepo = ProcessRunner.normalizePath(entry.path) == ProcessRunner.normalizePath(project.path)
                    let upstream = (try? self.gitCli.currentUpstream(worktreePath: entry.path)) ?? "未配置"
                    let diskUsage = DiskUsageStore.shared.get(entry.path) ?? "-"
                    let dirtyStatus = (try? self.gitCli.worktreeDirtyStatus(worktreePath: entry.path)) ?? (isDirty: false, summary: "未知")
                    let summary = description?.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
                        ?? (isMainRepo ? "主仓库" : "未填写功能描述")
                    let createdDetail = isMainRepo
                        ? "主仓库"
                        : (description?.isEmpty == false ? "功能描述已写入工作树元数据" : "本地关联工作树")

                    projectWorktrees.append(
                        WorktreeItem(
                            id: ProcessRunner.normalizePath(entry.path),
                            project: project.displayName,
                            projectName: project.name,
                            projectPath: project.path,
                            branch: branch,
                            summary: summary,
                            updatedAt: commitInfo.updatedAt,
                            kind: isMainRepo ? .mainRepo : .worktree,
                            path: entry.path,
                            upstream: upstream,
                            head: commitInfo.headLine,
                            createdDetail: createdDetail,
                            diskUsage: diskUsage,
                            canRemoveRemoteBranch: !isMainRepo && entry.branch != nil,
                            commits: commitInfo.commits,
                            isDirty: dirtyStatus.isDirty,
                            dirtySummary: dirtyStatus.summary,
                            platform: project.platform
                        )
                    )
                }
                collector.append(contentsOf: projectWorktrees)
            }

            let worktrees = collector.all
            let sortedWorktrees = worktrees.sorted {
                if $0.projectName != $1.projectName {
                    return $0.projectName < $1.projectName
                }
                if $0.kind != $1.kind {
                    return $0.kind == .mainRepo
                }
                return $0.branch.localizedStandardCompare($1.branch) == .orderedAscending
            }

            onProgress(.init(title: "完成", detail: "已加载 \(projects.count) 个项目与 \(sortedWorktrees.count) 个工作树", current: 3, total: 3))
            return WorktreeSnapshot(config: config, projects: projects, worktrees: sortedWorktrees)
        }.value
    }

    func createWorktree(
        config: WorktreeConfig,
        project: LocalProject,
        draft: CreateWorktreeDraft,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> CreateWorktreeResult {
        try await Task.detached(priority: .userInitiated) {
            let baseBranch = draft.baseBranch.trimmingCharacters(in: .whitespacesAndNewlines)
            let newBranch = draft.branchName.trimmingCharacters(in: .whitespacesAndNewlines)
            let targetPath = ProcessRunner.expandPath(draft.path)
            let shouldPushRemote = draft.mode == .newBranch
            let totalSteps = 4 + (shouldPushRemote ? 1 : 0) + (draft.installDependencies ? 1 : 0)
            var currentStep = 0
            var logs: [String] = [
                "项目: \(project.displayName)",
                "分支: \(newBranch)",
                "路径: \(targetPath)"
            ]

            guard !baseBranch.isEmpty else {
                throw WorkbenchError.message("请选择基线分支")
            }
            guard !newBranch.isEmpty else {
                throw WorkbenchError.message("请填写新分支名")
            }
            guard !targetPath.isEmpty else {
                throw WorkbenchError.message("请填写工作树路径")
            }

            let progressDetail = draft.mode == .existingBranch
                ? "使用已有分支 \(newBranch)"
                : "\(newBranch) <- \(baseBranch)"
            currentStep += 1
            onProgress(.init(title: "准备创建工作树", detail: progressDetail, current: currentStep, total: totalSteps))
            let targetURL = URL(fileURLWithPath: targetPath)
            if FileManager.default.fileExists(atPath: targetPath) {
                throw WorkbenchError.message("目标路径已存在: \(targetPath)")
            }
            try FileManager.default.createDirectory(
                at: targetURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            currentStep += 1
            onProgress(.init(title: "同步远程信息", detail: "正在执行 git fetch origin", current: currentStep, total: totalSteps))
            try self.gitCli.fetch(projectPath: project.path, remote: "origin")

            currentStep += 1
            onProgress(.init(title: "创建 Git Worktree", detail: "正在执行 git worktree add", current: currentStep, total: totalSteps))
            if draft.mode == .existingBranch {
                let localExists = try self.gitCli.localBranchExists(projectPath: project.path, branch: newBranch)
                let remoteExists = try self.gitCli.remoteBranchExists(projectPath: project.path, branch: newBranch)

                if localExists {
                    try self.gitCli.addWorktree(projectPath: project.path, targetPath: targetPath, branch: newBranch)
                } else if remoteExists {
                    try self.gitCli.addWorktree(projectPath: project.path, targetPath: targetPath, branch: newBranch, newBranchFrom: "origin/\(newBranch)")
                } else {
                    throw WorkbenchError.message("分支不存在于本地或 origin: \(newBranch)")
                }
            } else {
                try self.gitCli.addWorktree(projectPath: project.path, targetPath: targetPath, branch: newBranch, newBranchFrom: "origin/\(baseBranch)")
                logs.append("已基于 origin/\(baseBranch) 创建本地分支")
            }

            let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
            currentStep += 1
            if !description.isEmpty {
                onProgress(.init(title: "写入功能描述", detail: "同步到工作树元数据", current: currentStep, total: totalSteps))
                try self.configService.saveWorktreeDescription(
                    metadataPath: config.metadataPath,
                    projectPath: project.path,
                    branch: newBranch,
                    description: description
                )
                logs.append("功能描述已保存: \(description)")
            } else {
                onProgress(.init(title: "写入功能描述", detail: "未填写，跳过保存", current: currentStep, total: totalSteps))
                logs.append("未填写功能描述")
            }

            if shouldPushRemote {
                currentStep += 1
                onProgress(.init(title: "推送远程分支", detail: "正在执行 git push -u origin \(newBranch)", current: currentStep, total: totalSteps))
                do {
                    try self.gitCli.push(projectPath: targetPath, remote: "origin", branch: newBranch, setUpstream: true)
                    logs.append("远程分支已创建并建立跟踪: origin/\(newBranch)")
                } catch {
                    logs.append("警告: Worktree 已创建，但远程分支推送失败: \(error.localizedDescription)")
                }
            }

            if draft.installDependencies {
                currentStep += 1
                onProgress(.init(title: "安装依赖", detail: "根据项目类型自动选择安装命令", current: currentStep, total: totalSteps))
                try self.installDependencies(at: targetPath)
                logs.append("依赖安装已完成")
            }

            return CreateWorktreeResult(
                path: targetPath,
                logs: logs,
                successMessage: shouldPushRemote ? "工作树和远程分支已创建" : "工作树创建成功"
            )
        }.value
    }

    func removeWorktree(
        config: WorktreeConfig,
        item: WorktreeItem,
        deleteLocalBranch: Bool,
        deleteRemoteBranch: Bool,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            guard item.kind == .worktree else {
                throw WorkbenchError.message("主仓库不能从这里删除")
            }

            onProgress(.init(title: "删除工作树", detail: "正在移除 \(item.branch)", current: 1, total: 3))
            try self.gitCli.removeWorktree(projectPath: item.projectPath, targetPath: item.path, force: true)

            if deleteLocalBranch {
                onProgress(.init(title: "删除本地分支", detail: item.branch, current: 2, total: 3))
                try self.gitCli.deleteLocalBranch(projectPath: item.projectPath, branch: item.branch)
            }

            if deleteRemoteBranch {
                onProgress(.init(title: "删除远程分支", detail: "origin/\(item.branch)", current: 3, total: 3))
                try self.gitCli.deleteRemoteBranch(projectPath: item.projectPath, remote: "origin", branch: item.branch)
            }

            try self.configService.clearWorktreeDescription(
                metadataPath: config.metadataPath,
                projectPath: item.projectPath,
                branch: item.branch
            )
        }.value
    }

    func updateWorktreeDescription(
        config: WorktreeConfig,
        item: WorktreeItem,
        description: String
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let normalized = description.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized.isEmpty {
                try self.configService.clearWorktreeDescription(
                    metadataPath: config.metadataPath,
                    projectPath: item.projectPath,
                    branch: item.branch
                )
            } else {
                try self.configService.saveWorktreeDescription(
                    metadataPath: config.metadataPath,
                    projectPath: item.projectPath,
                    branch: item.branch,
                    description: normalized
                )
            }
        }.value
    }

    func installDependencies(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: url.appendingPathComponent("pnpm-lock.yaml").path) {
            _ = try ProcessRunner.runCommand("pnpm", arguments: ["install"], currentDirectory: path)
            return
        }
        if fileManager.fileExists(atPath: url.appendingPathComponent("yarn.lock").path) {
            _ = try ProcessRunner.runCommand("yarn", arguments: ["install"], currentDirectory: path)
            return
        }
        if fileManager.fileExists(atPath: url.appendingPathComponent("package.json").path) {
            _ = try ProcessRunner.runCommand("npm", arguments: ["install"], currentDirectory: path)
            return
        }
        if fileManager.fileExists(atPath: url.appendingPathComponent("Cargo.toml").path) {
            _ = try ProcessRunner.runCommand("cargo", arguments: ["fetch"], currentDirectory: path)
        }
    }

    func openInIDE(config: WorktreeConfig, path: String) throws {
        let expandedPath = ProcessRunner.expandPath(path)
        switch config.ideMode {
        case "app":
            if !config.ideCommand.isEmpty {
                _ = try ProcessRunner.runCommand("open", arguments: ["-a", config.ideCommand, expandedPath])
                return
            }
            fallthrough
        case "system":
            _ = try ProcessRunner.runCommand("open", arguments: [expandedPath])
        default:
            _ = try ProcessRunner.runCommand("open", arguments: [expandedPath])
        }
    }

    func openInTerminal(path: String, terminalName: String = "Terminal", bundleID: String? = nil) throws {
        try TerminalService.shared.openDirectory(path: path, terminalName: terminalName, bundleID: bundleID)
    }
}
