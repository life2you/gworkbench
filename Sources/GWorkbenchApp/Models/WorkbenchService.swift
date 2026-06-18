import Foundation

struct LocalProject: Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let path: String
    let sourceRoot: String
    let currentBranch: String
    let baseBranches: [String]
    let localBranches: [String]
}

struct BranchMapping: Identifiable, Hashable {
    let source: String
    let target: String
    let protectedTarget: Bool

    var id: String { "\(source)->\(target)" }
}

struct GwtmConfig: Sendable {
    let configPath: String
    let metadataPath: String
    let projectsRootDirs: [String]
    let worktreesRootDir: String
    let ideMode: String
    let ideCommand: String
    let ideLabel: String
}

struct GmuxConfig: Sendable {
    let configPath: String
    let host: String
    let token: String
    let rootDirs: [String]
    let mergeBranchMiddle: String
    let envBranches: [String]
    let branchMap: [String: String]
    let protectedTargets: [String]
    let autoMergeDelaySeconds: Int
    let autoMergeRetryCount: Int
}

struct GwtmSnapshot: Sendable {
    let config: GwtmConfig
    let projects: [LocalProject]
    let worktrees: [WorktreeItem]
}

struct GmuxContext: Sendable {
    let config: GmuxConfig
    let currentUsername: String
    let projects: [MergeProject]
}

struct LocalMergeContext: Sendable {
    let config: GmuxConfig
    let projects: [MergeProject]
}

struct MergeProject: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let displayName: String
    let path: String
    let sourceRoot: String
    let currentBranch: String
    let gitLabProjectID: Int?
    let branchMappings: [BranchMapping]
    let localBranches: [String]
}

struct OperationProgress: Sendable {
    let title: String
    let detail: String
    let current: Int?
    let total: Int?

    var fractionCompleted: Double? {
        guard let current, let total, total > 0 else {
            return nil
        }
        return min(max(Double(current) / Double(total), 0), 1)
    }
}

enum WorkbenchError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        }
    }
}

private struct ShellResult {
    let stdout: String
    let stderr: String
    let status: Int32
}

private struct LocalBranchExecutionResult {
    let sourceBranch: String
    let targetBranch: String
    let success: Bool
    let message: String
}

struct CreateWorktreeResult: Sendable {
    let path: String
    let logs: [String]
    let successMessage: String
}

private struct WorktreeMetadataStore: Decodable {
    let descriptions: [WorktreeDescription]
}

private struct WorktreeDescription: Decodable {
    let project_path: String
    let branch: String
    let description: String
}

private struct GwtmTomlConfig: Decodable {
    let projects_root_dirs: [String]
    let worktrees_root_dir: String
    let ide_mode: String?
    let ide_command: String?
    let ide_label: String?
}

private struct GmuxTomlConfig: Decodable {
    struct GitLab: Decodable {
        let host: String
        let token: String
    }

    struct Project: Decodable {
        let root_dirs: [String]
        let merge_branch_middle: String
        let env_branches: [String]?
    }

    struct MergePolicy: Decodable {
        let protected_targets: [String]?
        let auto_merge_delay_seconds: Int?
        let auto_merge_retry_count: Int?
    }

    let gitlab: GitLab
    let project: Project
    let branch_map: [String: String]?
    let merge_policy: MergePolicy?
}

private struct GWorkbenchTomlConfig: Decodable {
    struct Worktree: Decodable {
        let projects_root_dirs: [String]
        let worktrees_root_dir: String
        let metadata_path: String?
        let ide_mode: String?
        let ide_command: String?
        let ide_label: String?
    }

    struct GitLab: Decodable {
        let host: String
        let token: String
    }

    struct Merge: Decodable {
        let root_dirs: [String]
        let merge_branch_middle: String
        let env_branches: [String]?
    }

    struct MergePolicy: Decodable {
        let protected_targets: [String]?
        let auto_merge_delay_seconds: Int?
        let auto_merge_retry_count: Int?
    }

    let worktree: Worktree
    let gitlab: GitLab
    let merge: Merge
    let branch_map: [String: String]?
    let merge_policy: MergePolicy?
}

private struct GitLabProjectResponse: Decodable {
    let id: Int
    let name: String
}

private struct GitLabCurrentUserResponse: Decodable {
    let username: String
}

private struct GitLabUserResponse: Decodable {
    let name: String
    let username: String
}

private struct GitLabPipelineResponse: Decodable {
    let status: String?
}

private struct GitLabMergeRequestResponse: Decodable {
    let id: Int
    let iid: Int
    let title: String
    let description: String?
    let web_url: String
    let state: String
    let source_branch: String
    let target_branch: String
    let author: GitLabUserResponse
    let labels: [String]?
    let updated_at: String?
    let merge_status: String?
    let detailed_merge_status: String?
    let draft: Bool?
    let head_pipeline: GitLabPipelineResponse?
}

private struct GitLabApprovalResponse: Decodable {
    struct ApprovedByEntry: Decodable {
        let user: GitLabUserResponse
    }

    let approved_by: [ApprovedByEntry]
}

private struct GitLabMergeRequestCommitResponse: Decodable {
    let id: String
    let short_id: String?
    let title: String
    let message: String
    let author_name: String
    let created_at: String?
}

final class WorkbenchService: @unchecked Sendable {
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }()

    func loadWorkbenchConfig() async throws -> GWorkbenchConfig {
        try await Task.detached(priority: .userInitiated) {
            try self.loadOrCreateWorkbenchConfigSync()
        }.value
    }

    func reloadWorkbenchConfigWithoutImport() async throws -> GWorkbenchConfig {
        try await Task.detached(priority: .userInitiated) {
            try self.loadWorkbenchConfigSync(importLegacyIfMissing: false)
        }.value
    }

    func importLegacyWorkbenchConfig() async throws -> GWorkbenchConfig {
        try await Task.detached(priority: .userInitiated) {
            let imported = try self.importLegacyWorkbenchConfigSync()
            try self.saveWorkbenchConfigSync(imported)
            return imported
        }.value
    }

    func saveWorkbenchConfig(_ config: GWorkbenchConfig) async throws -> GWorkbenchConfig {
        try await Task.detached(priority: .userInitiated) {
            try self.saveWorkbenchConfigSync(config)
            return try self.loadWorkbenchConfigSync(importLegacyIfMissing: false)
        }.value
    }

    func loadWorktreeSnapshot(
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> GwtmSnapshot {
        try await Task.detached(priority: .userInitiated) {
            onProgress(.init(title: "读取 GWorkbench 配置", detail: "正在定位桌面版配置文件", current: 0, total: 4))
            let config = try self.loadWorkbenchConfigSync(importLegacyIfMissing: true).asGwtmConfig()

            onProgress(.init(title: "扫描项目", detail: "正在读取项目根目录中的 Git 仓库", current: 1, total: 4))
            let projects = try self.scanLocalProjectsSync(rootDirs: config.projectsRootDirs)
            let metadataMap = try self.loadWorktreeMetadataMapSync(metadataPath: config.metadataPath)

            var worktrees: [WorktreeItem] = []
            for (index, project) in projects.enumerated() {
                onProgress(.init(
                    title: "读取工作树",
                    detail: "正在加载 \(project.displayName) 的工作树和提交信息",
                    current: index + 2,
                    total: max(projects.count + 1, 3)
                ))

                let entries = try self.parseWorktreeListSync(projectPath: project.path)
                for entry in entries {
                    let branch = entry.branch ?? "(detached)"
                    let description = entry.branch.flatMap {
                        metadataMap["\(self.normalizePath(project.path))#\($0)"]
                    }
                    let commitInfo = try self.loadCommitInfoSync(worktreePath: entry.path)
                    let isMainRepo = self.normalizePath(entry.path) == self.normalizePath(project.path)
                    let upstream = (try? self.currentUpstreamSync(worktreePath: entry.path)) ?? "未配置"
                    let diskUsage = (try? self.diskUsageSync(path: entry.path)) ?? "未知"
                    let summary = description?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                        ?? (isMainRepo ? "主仓库" : "未填写功能描述")
                    let createdDetail = isMainRepo
                        ? "主仓库"
                        : (description?.isEmpty == false ? "功能描述已写入 gwtm 元数据" : "由 gwtm 管理的工作树")

                    worktrees.append(
                        WorktreeItem(
                            id: self.normalizePath(entry.path),
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
                            commits: commitInfo.commits
                        )
                    )
                }
            }

            let sortedWorktrees = worktrees.sorted {
                if $0.projectName != $1.projectName {
                    return $0.projectName < $1.projectName
                }
                if $0.kind != $1.kind {
                    return $0.kind == .mainRepo
                }
                return $0.branch.localizedStandardCompare($1.branch) == .orderedAscending
            }

            onProgress(.init(title: "完成", detail: "已加载 \(projects.count) 个项目与 \(sortedWorktrees.count) 个工作树", current: 1, total: 1))
            return GwtmSnapshot(config: config, projects: projects, worktrees: sortedWorktrees)
        }.value
    }

    func createWorktree(
        config: GwtmConfig,
        project: LocalProject,
        draft: CreateWorktreeDraft,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> CreateWorktreeResult {
        try await Task.detached(priority: .userInitiated) {
            let baseBranch = draft.baseBranch.trimmingCharacters(in: .whitespacesAndNewlines)
            let newBranch = draft.branchName.trimmingCharacters(in: .whitespacesAndNewlines)
            let targetPath = self.expandPath(draft.path)
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
            _ = try self.runCommand(
                "git",
                arguments: ["-C", project.path, "fetch", "origin"]
            )

            currentStep += 1
            onProgress(.init(title: "创建 Git Worktree", detail: "正在执行 git worktree add", current: currentStep, total: totalSteps))
            if draft.mode == .existingBranch {
                let localExists = try self.localBranchExistsSync(projectPath: project.path, branch: newBranch)
                let remoteExists = try self.remoteBranchExistsSync(projectPath: project.path, branch: newBranch)

                if localExists {
                    _ = try self.runCommand(
                        "git",
                        arguments: ["-C", project.path, "worktree", "add", targetPath, newBranch]
                    )
                } else if remoteExists {
                    _ = try self.runCommand(
                        "git",
                        arguments: ["-C", project.path, "worktree", "add", "-b", newBranch, targetPath, "origin/\(newBranch)"]
                    )
                } else {
                    throw WorkbenchError.message("分支不存在于本地或 origin: \(newBranch)")
                }
            } else {
                _ = try self.runCommand(
                    "git",
                    arguments: ["-C", project.path, "worktree", "add", "-b", newBranch, targetPath, "origin/\(baseBranch)"]
                )
                logs.append("已基于 origin/\(baseBranch) 创建本地分支")
            }

            let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
            currentStep += 1
            if !description.isEmpty {
                onProgress(.init(title: "写入功能描述", detail: "同步到 gwtm 元数据", current: currentStep, total: totalSteps))
                try self.saveWorktreeDescriptionSync(
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
                    _ = try self.runCommand(
                        "git",
                        arguments: ["-C", targetPath, "push", "-u", "origin", newBranch]
                    )
                    logs.append("远程分支已创建并建立跟踪: origin/\(newBranch)")
                } catch {
                    logs.append("警告: Worktree 已创建，但远程分支推送失败: \(error.localizedDescription)")
                }
            }

            if draft.installDependencies {
                currentStep += 1
                onProgress(.init(title: "安装依赖", detail: "根据项目类型自动选择安装命令", current: currentStep, total: totalSteps))
                try self.installDependenciesSync(at: targetPath)
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
        config: GwtmConfig,
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
            _ = try self.runCommand(
                "git",
                arguments: ["-C", item.projectPath, "worktree", "remove", item.path, "--force"]
            )

            if deleteLocalBranch {
                onProgress(.init(title: "删除本地分支", detail: item.branch, current: 2, total: 3))
                _ = try self.runCommand(
                    "git",
                    arguments: ["-C", item.projectPath, "branch", "-D", item.branch]
                )
            }

            if deleteRemoteBranch {
                onProgress(.init(title: "删除远程分支", detail: "origin/\(item.branch)", current: 3, total: 3))
                _ = try self.runCommand(
                    "git",
                    arguments: ["-C", item.projectPath, "push", "origin", "--delete", item.branch]
                )
            }

            try self.clearWorktreeDescriptionSync(
                metadataPath: config.metadataPath,
                projectPath: item.projectPath,
                branch: item.branch
            )
        }.value
    }

    func updateWorktreeDescription(
        config: GwtmConfig,
        item: WorktreeItem,
        description: String
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let normalized = description.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized.isEmpty {
                try self.clearWorktreeDescriptionSync(
                    metadataPath: config.metadataPath,
                    projectPath: item.projectPath,
                    branch: item.branch
                )
            } else {
                try self.saveWorktreeDescriptionSync(
                    metadataPath: config.metadataPath,
                    projectPath: item.projectPath,
                    branch: item.branch,
                    description: normalized
                )
            }
        }.value
    }

    func loadLocalMergeContext(
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> LocalMergeContext {
        onProgress(.init(title: "读取 gmux 配置", detail: "正在定位本地分支同步配置", current: 0, total: 3))
        let config = try await Task.detached(priority: .userInitiated) {
            let workbenchConfig = try self.loadWorkbenchConfigSync(importLegacyIfMissing: true)
            let gmuxConfig = workbenchConfig.asGmuxConfig()
            return GmuxConfig(
                configPath: gmuxConfig.configPath,
                host: gmuxConfig.host,
                token: gmuxConfig.token,
                rootDirs: workbenchConfig.worktreeProjectsRootDirs,
                mergeBranchMiddle: gmuxConfig.mergeBranchMiddle,
                envBranches: gmuxConfig.envBranches,
                branchMap: gmuxConfig.branchMap,
                protectedTargets: gmuxConfig.protectedTargets,
                autoMergeDelaySeconds: gmuxConfig.autoMergeDelaySeconds,
                autoMergeRetryCount: gmuxConfig.autoMergeRetryCount
            )
        }.value

        onProgress(.init(title: "扫描本地项目", detail: "正在读取可用仓库", current: 1, total: 3))
        let localProjects = try await Task.detached(priority: .userInitiated) {
            try self.scanLocalProjectsSync(rootDirs: config.rootDirs)
        }.value

        onProgress(.init(title: "整理分支数据", detail: "正在读取本地分支与目标映射", current: 2, total: 3))
        let mappings = effectiveMRBranchMappings(config: config)
        let projects = try await withThrowingTaskGroup(of: MergeProject.self) { group in
            for project in localProjects {
                group.addTask {
                    let localBranches = try self.localBranchesSync(projectPath: project.path)
                    return MergeProject(
                        id: project.id,
                        name: project.name,
                        displayName: project.displayName,
                        path: project.path,
                        sourceRoot: project.sourceRoot,
                        currentBranch: project.currentBranch,
                        gitLabProjectID: nil,
                        branchMappings: mappings,
                        localBranches: localBranches
                    )
                }
            }

            var results: [MergeProject] = []
            for try await project in group {
                results.append(project)
            }
            return results.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        }

        onProgress(.init(title: "完成", detail: "已加载 \(projects.count) 个本地同步项目", current: 3, total: 3))
        return LocalMergeContext(config: config, projects: projects)
    }

    func loadMergeContext(
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> GmuxContext {
        onProgress(.init(title: "读取 GWorkbench 配置", detail: "正在定位 GitLab 与分支映射配置", current: 0, total: 4))
        let config = try await Task.detached(priority: .userInitiated) {
            try self.loadWorkbenchConfigSync(importLegacyIfMissing: true).asGmuxConfig()
        }.value

        onProgress(.init(title: "扫描本地项目", detail: "正在读取可用仓库", current: 1, total: 4))
        let localProjects = try await Task.detached(priority: .userInitiated) {
            try self.scanLocalProjectsSync(rootDirs: config.rootDirs)
        }.value

        onProgress(.init(title: "连接 GitLab", detail: "正在读取项目列表与当前用户", current: 2, total: 4))
        async let remoteProjects: [GitLabProjectResponse] = request(
            host: config.host,
            token: config.token,
            path: "/projects?membership=true&per_page=100",
            method: "GET",
            body: nil
        )
        async let currentUser: GitLabCurrentUserResponse = request(
            host: config.host,
            token: config.token,
            path: "/user",
            method: "GET",
            body: nil
        )
        let (gitLabProjects, currentUserResponse) = try await (remoteProjects, currentUser)

        let remoteByName = Dictionary(gitLabProjects.map { ($0.name, $0.id) }, uniquingKeysWith: { first, _ in first })

        onProgress(.init(title: "整理映射", detail: "生成可创建 MR 的分支映射", current: 3, total: 4))
        let mappings = effectiveMRBranchMappings(config: config)
        let mergeProjects = try await withThrowingTaskGroup(of: MergeProject.self) { group in
            for project in localProjects {
                group.addTask {
                    let localBranches = try self.localBranchesSync(projectPath: project.path)
                    return MergeProject(
                        id: project.id,
                        name: project.name,
                        displayName: project.displayName,
                        path: project.path,
                        sourceRoot: project.sourceRoot,
                        currentBranch: project.currentBranch,
                        gitLabProjectID: remoteByName[project.name],
                        branchMappings: mappings,
                        localBranches: localBranches
                    )
                }
            }

            var results: [MergeProject] = []
            for try await project in group {
                results.append(project)
            }
            return results.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        }

        onProgress(.init(title: "完成", detail: "已加载 \(mergeProjects.count) 个 gmux 项目", current: 4, total: 4))
        return GmuxContext(config: config, currentUsername: currentUserResponse.username, projects: mergeProjects)
    }

    func loadPendingMergeRequests(
        context: GmuxContext,
        project: MergeProject,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [MergeRequestItem] {
        guard let projectID = project.gitLabProjectID else {
            return []
        }

        onProgress(.init(title: "读取待合并列表", detail: "正在从 GitLab 拉取 \(project.displayName) 的 MR", current: 1, total: 3))
        let mergeRequests: [GitLabMergeRequestResponse] = try await request(
            host: context.config.host,
            token: context.config.token,
            path: "/projects/\(projectID)/merge_requests?state=opened&scope=all&per_page=100",
            method: "GET",
            body: nil
        )

        onProgress(.init(title: "读取审批状态", detail: "正在补全每条 MR 的审批信息", current: 2, total: 3))
        let currentUsername = context.currentUsername
        let protectedTargets = Set(context.config.protectedTargets)

        let service = self
        let items = try await withThrowingTaskGroup(of: MergeRequestItem.self) { group in
            for mr in mergeRequests {
                group.addTask {
                    async let approvalsRequest: GitLabApprovalResponse = service.request(
                        host: context.config.host,
                        token: context.config.token,
                        path: "/projects/\(projectID)/merge_requests/\(mr.iid)/approvals",
                        method: "GET",
                        body: nil
                    )
                    async let commitsRequest: [GitLabMergeRequestCommitResponse] = service.request(
                        host: context.config.host,
                        token: context.config.token,
                        path: "/projects/\(projectID)/merge_requests/\(mr.iid)/commits",
                        method: "GET",
                        body: nil
                    )

                    let approvals = try await approvalsRequest
                    let commitResponses = try await commitsRequest
                    let approvedUsers = approvals.approved_by.map(\.user)
                    let approvedByMe = approvedUsers.contains(where: { $0.username == currentUsername })
                    let approvalEntries = service.makeApprovalEntries(
                        approvedUsers: approvedUsers,
                        currentUsername: currentUsername,
                        approvedByMe: approvedByMe
                    )
                    let commitEntries = commitResponses.map { commit in
                        CommitEntry(
                            sha: commit.short_id ?? String(commit.id.prefix(8)),
                            message: commit.title,
                            author: commit.author_name,
                            relativeTime: service.relativeDateString(fromISO8601: commit.created_at)
                        )
                    }

                    return MergeRequestItem(
                        id: "\(projectID)-\(mr.iid)",
                        project: project.displayName,
                        projectName: project.name,
                        projectPath: project.path,
                        projectId: projectID,
                        iid: mr.iid,
                        title: mr.title,
                        subtitle: self.mrSubtitle(from: mr),
                        sourceBranch: mr.source_branch,
                        targetBranch: mr.target_branch,
                        author: mr.author.name,
                        authorUsername: mr.author.username,
                        updatedAt: service.relativeDateString(fromISO8601: mr.updated_at),
                        approvalProgress: approvedByMe ? "已审批" : "待审批",
                        approvedByMe: approvedByMe,
                        status: service.mapMRStatus(mr),
                        pipeline: service.mapPipelineState(mr.head_pipeline?.status),
                        labels: mr.labels ?? [],
                        protectedTarget: protectedTargets.contains(mr.target_branch),
                        approvals: approvalEntries,
                        activity: [
                            ActivityEntry(actor: mr.author.name, summary: "创建了这条 MR", relativeTime: service.relativeDateString(fromISO8601: mr.updated_at)),
                            ActivityEntry(actor: "GitLab", summary: mr.web_url, relativeTime: "链接")
                        ],
                        commits: commitEntries,
                        webURL: mr.web_url
                    )
                }
            }

            var items: [MergeRequestItem] = []
            for try await item in group {
                items.append(item)
            }
            return items.sorted {
                if $0.protectedTarget != $1.protectedTarget {
                    return $0.protectedTarget
                }
                return $0.iid > $1.iid
            }
        }

        onProgress(.init(title: "完成", detail: "已加载 \(items.count) 条待处理 MR", current: 3, total: 3))
        return items
    }

    func executeLocalSync(
        context: LocalMergeContext,
        project: MergeProject,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            let results = try self.syncAndPushWithProgressSync(project: project, config: context.config, onProgress: onProgress)
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
            let results = try self.mergeToTargetsWithProgressSync(
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

    func approveAndMerge(
        context: GmuxContext,
        item: MergeRequestItem,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String] {
        var logs: [String] = []

        if !item.approvedByMe {
            onProgress(.init(title: "审批 MR", detail: "\(item.iidLabel) \(item.sourceBranch) -> \(item.targetBranch)", current: 1, total: 3))
            let _: EmptyResponse = try await request(
                host: context.config.host,
                token: context.config.token,
                path: "/projects/\(item.projectId)/merge_requests/\(item.iid)/approve",
                method: "POST",
                body: nil,
                allowEmptyResponse: true
            )
            logs.append("审批成功: \(item.iidLabel) \(item.sourceBranch) -> \(item.targetBranch)")
        } else {
            logs.append("已检测到当前账号审批过该 MR，跳过重复审批")
        }

        let totalAttempts = max(context.config.autoMergeRetryCount, 0) + 1
        for attempt in 1...totalAttempts {
            let step = min(attempt + 1, totalAttempts + 1)
            if context.config.autoMergeDelaySeconds > 0 {
                onProgress(.init(
                    title: "等待自动合并窗口",
                    detail: "第 \(attempt) 次合并前等待 \(context.config.autoMergeDelaySeconds) 秒",
                    current: step,
                    total: totalAttempts + 1
                ))
                try await Task.sleep(for: .seconds(context.config.autoMergeDelaySeconds))
            }

            onProgress(.init(
                title: "尝试合并 MR",
                detail: "第 \(attempt) 次尝试 \(item.iidLabel)",
                current: step,
                total: totalAttempts + 1
            ))
            do {
                let body = ["merge_when_pipeline_succeeds": false]
                let response: MergeResponse = try await request(
                    host: context.config.host,
                    token: context.config.token,
                    path: "/projects/\(item.projectId)/merge_requests/\(item.iid)/merge",
                    method: "PUT",
                    body: try JSONSerialization.data(withJSONObject: body)
                )
                if response.state == "merged" {
                    logs.append(attempt == 1
                        ? "自动合并成功: \(item.sourceBranch) -> \(item.targetBranch)"
                        : "自动合并成功: \(item.sourceBranch) -> \(item.targetBranch)（第 \(attempt) 次尝试）")
                    return logs
                }
                logs.append("第 \(attempt) 次合并返回状态: \(response.state)")
            } catch {
                logs.append("第 \(attempt) 次合并失败: \(error.localizedDescription)")
                if attempt == totalAttempts {
                    throw WorkbenchError.message(logs.joined(separator: "\n"))
                }
            }
        }

        return logs
    }

    func closeMergeRequest(context: GmuxContext, item: MergeRequestItem) async throws {
        let body = ["state_event": "close"]
        let _: EmptyResponse = try await request(
            host: context.config.host,
            token: context.config.token,
            path: "/projects/\(item.projectId)/merge_requests/\(item.iid)",
            method: "PUT",
            body: try JSONSerialization.data(withJSONObject: body),
            allowEmptyResponse: true
        )
    }

    func createMergeRequest(
        context: GmuxContext,
        project: MergeProject,
        sourceBranch: String,
        targetBranch: String
    ) async throws -> MergeRequestItem {
        guard let projectID = project.gitLabProjectID else {
            throw WorkbenchError.message("当前项目未匹配到 GitLab 项目")
        }

        let body = [
            "source_branch": sourceBranch,
            "target_branch": targetBranch,
            "title": "Auto MR: \(project.name) \(sourceBranch) -> \(targetBranch)",
            "description": "由 GWorkbench 创建的合并请求"
        ]
        let mr: GitLabMergeRequestResponse = try await request(
            host: context.config.host,
            token: context.config.token,
            path: "/projects/\(projectID)/merge_requests",
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: body)
        )

        return MergeRequestItem(
            id: "\(projectID)-\(mr.iid)",
            project: project.displayName,
            projectName: project.name,
            projectPath: project.path,
            projectId: projectID,
            iid: mr.iid,
            title: mr.title,
            subtitle: mrSubtitle(from: mr),
            sourceBranch: mr.source_branch,
            targetBranch: mr.target_branch,
            author: "我",
            authorUsername: context.currentUsername,
            updatedAt: relativeDateString(fromISO8601: mr.updated_at),
            approvalProgress: "待审批",
            approvedByMe: false,
            status: mapMRStatus(mr),
            pipeline: mapPipelineState(mr.head_pipeline?.status),
            labels: mr.labels ?? [],
            protectedTarget: context.config.protectedTargets.contains(mr.target_branch),
            approvals: [ApprovalEntry(reviewer: "我", detail: "刚创建，尚未审批", approved: false)],
            activity: [ActivityEntry(actor: "我", summary: "创建了这条 MR", relativeTime: "刚刚")],
            commits: [],
            webURL: mr.web_url
        )
    }

    func createBatchMergeRequests(
        context: GmuxContext,
        project: MergeProject,
        mappings: [BranchMapping],
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String] {
        guard !mappings.isEmpty else {
            return ["没有可批量创建的非保护分支映射"]
        }

        var messages: [String] = []
        for (index, mapping) in mappings.enumerated() {
            onProgress(.init(
                title: "批量创建 MR",
                detail: "\(mapping.source) -> \(mapping.target)",
                current: index + 1,
                total: mappings.count
            ))
            do {
                let mr = try await createMergeRequest(
                    context: context,
                    project: project,
                    sourceBranch: mapping.source,
                    targetBranch: mapping.target
                )
                messages.append("创建成功: \(mr.iidLabel) \(mapping.source) -> \(mapping.target)")
            } catch {
                messages.append("创建失败: \(mapping.source) -> \(mapping.target) - \(error.localizedDescription)")
            }
        }
        return messages
    }

    func approveAndMergeBatch(
        context: GmuxContext,
        items: [MergeRequestItem],
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String] {
        guard !items.isEmpty else {
            return ["没有可审批并合并的 MR"]
        }

        var logs: [String] = []
        for (index, item) in items.enumerated() {
            let prefix = "[\(index + 1)/\(items.count)] \(item.iidLabel)"
            do {
                let itemLogs = try await approveAndMerge(context: context, item: item) { progress in
                    onProgress(.init(
                        title: "批量审批并合并",
                        detail: "\(prefix) \(progress.title) · \(progress.detail)",
                        current: index + 1,
                        total: items.count
                    ))
                }
                if let finalLine = itemLogs.last {
                    logs.append("\(prefix) \(finalLine)")
                } else {
                    logs.append("\(prefix) 审批并合并完成")
                }
            } catch {
                logs.append("\(prefix) 失败: \(error.localizedDescription)")
            }
        }

        return logs
    }

    func openInIDE(config: GwtmConfig, path: String) throws {
        let expandedPath = expandPath(path)
        switch config.ideMode {
        case "app":
            if !config.ideCommand.isEmpty {
                _ = try runCommand("open", arguments: ["-a", config.ideCommand, expandedPath])
                return
            }
            fallthrough
        case "system":
            _ = try runCommand("open", arguments: [expandedPath])
        default:
            _ = try runCommand("open", arguments: [expandedPath])
        }
    }

    func openInTerminal(path: String) throws {
        _ = try runCommand("open", arguments: ["-a", "Terminal", expandPath(path)])
    }

    private func loadOrCreateWorkbenchConfigSync() throws -> GWorkbenchConfig {
        if let loaded = try? loadWorkbenchConfigSync(importLegacyIfMissing: false) {
            return loaded
        }

        let imported = try importLegacyWorkbenchConfigSync()
        try saveWorkbenchConfigSync(imported)
        return imported
    }

    private func loadWorkbenchConfigSync(importLegacyIfMissing: Bool) throws -> GWorkbenchConfig {
        let configPath = resolveConfigPath(appName: "gworkbench", fileName: "config.toml")
        guard FileManager.default.fileExists(atPath: configPath) else {
            if importLegacyIfMissing {
                return try loadOrCreateWorkbenchConfigSync()
            }
            throw WorkbenchError.message("GWorkbench 配置文件不存在: \(configPath)")
        }

        let config: GWorkbenchTomlConfig = try loadTomlFileSync(path: configPath)
        let configDirectory = URL(fileURLWithPath: configPath).deletingLastPathComponent()
        let metadataPath = expandPath(
            config.worktree.metadata_path
                ?? configDirectory.appendingPathComponent("worktree-metadata.toml").path
        )
        let envBranches = config.merge.env_branches ?? ["uat", "test", "stage", "pre_prod"]
        let mergeBranchMiddle = config.merge.merge_branch_middle
        let branchMap = config.branch_map ?? Dictionary(
            uniqueKeysWithValues: envBranches.map { ("\($0)_\(mergeBranchMiddle)_meger", $0) }
        )

        return GWorkbenchConfig(
            configPath: configPath,
            metadataPath: metadataPath,
            worktreeProjectsRootDirs: config.worktree.projects_root_dirs.map(expandPath),
            worktreesRootDir: expandPath(config.worktree.worktrees_root_dir),
            ideMode: config.worktree.ide_mode ?? "app",
            ideCommand: config.worktree.ide_command ?? "open",
            ideLabel: config.worktree.ide_label ?? (config.worktree.ide_command ?? "默认应用"),
            gitlabHost: config.gitlab.host,
            gitlabToken: config.gitlab.token,
            mergeRootDirs: config.merge.root_dirs.map(expandPath),
            mergeBranchMiddle: mergeBranchMiddle,
            envBranches: envBranches,
            branchMap: branchMap,
            protectedTargets: config.merge_policy?.protected_targets ?? ["master", "main"],
            autoMergeDelaySeconds: config.merge_policy?.auto_merge_delay_seconds ?? 10,
            autoMergeRetryCount: config.merge_policy?.auto_merge_retry_count ?? 3
        )
    }

    private func importLegacyWorkbenchConfigSync() throws -> GWorkbenchConfig {
        let configPath = resolveConfigPath(appName: "gworkbench", fileName: "config.toml")
        let configDirectory = URL(fileURLWithPath: configPath).deletingLastPathComponent()
        let metadataPath = configDirectory.appendingPathComponent("worktree-metadata.toml").path

        let legacyWorktree = try loadLegacyGwtmConfigSync()
        let legacyMerge = try loadLegacyGmuxConfigSync()

        if !FileManager.default.fileExists(atPath: metadataPath),
           FileManager.default.fileExists(atPath: legacyWorktree.metadataPath) {
            try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(
                at: URL(fileURLWithPath: legacyWorktree.metadataPath),
                to: URL(fileURLWithPath: metadataPath)
            )
        }

        return GWorkbenchConfig(
            configPath: configPath,
            metadataPath: metadataPath,
            worktreeProjectsRootDirs: legacyWorktree.projectsRootDirs,
            worktreesRootDir: legacyWorktree.worktreesRootDir,
            ideMode: legacyWorktree.ideMode,
            ideCommand: legacyWorktree.ideCommand,
            ideLabel: legacyWorktree.ideLabel,
            gitlabHost: legacyMerge.host,
            gitlabToken: legacyMerge.token,
            mergeRootDirs: legacyMerge.rootDirs,
            mergeBranchMiddle: legacyMerge.mergeBranchMiddle,
            envBranches: legacyMerge.envBranches,
            branchMap: legacyMerge.branchMap,
            protectedTargets: legacyMerge.protectedTargets,
            autoMergeDelaySeconds: legacyMerge.autoMergeDelaySeconds,
            autoMergeRetryCount: legacyMerge.autoMergeRetryCount
        )
    }

    private func saveWorkbenchConfigSync(_ config: GWorkbenchConfig) throws {
        let configPath = resolveConfigPath(appName: "gworkbench", fileName: "config.toml")
        let normalized = normalizeWorkbenchConfig(config, configPath: configPath)
        let configURL = URL(fileURLWithPath: configPath)
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try serializeWorkbenchConfig(normalized).write(to: configURL, atomically: true, encoding: .utf8)
    }

    private func loadLegacyGwtmConfigSync() throws -> GwtmConfig {
        let configPath = resolveConfigPath(appName: "gwtm", fileName: "config.toml")
        let config: GwtmTomlConfig = try loadTomlFileSync(path: configPath)
        return GwtmConfig(
            configPath: configPath,
            metadataPath: URL(fileURLWithPath: configPath).deletingLastPathComponent().appendingPathComponent("worktree-metadata.toml").path,
            projectsRootDirs: config.projects_root_dirs.map(expandPath),
            worktreesRootDir: expandPath(config.worktrees_root_dir),
            ideMode: config.ide_mode ?? "app",
            ideCommand: config.ide_command ?? "open",
            ideLabel: config.ide_label ?? (config.ide_command ?? "默认应用")
        )
    }

    private func loadLegacyGmuxConfigSync() throws -> GmuxConfig {
        let configPath = resolveConfigPath(appName: "gmux", fileName: "gmux.toml")
        let config: GmuxTomlConfig = try loadTomlFileSync(path: configPath)
        let envBranches = config.project.env_branches ?? ["uat", "test", "stage", "pre_prod"]
        let mergeBranchMiddle = config.project.merge_branch_middle
        let branchMap = config.branch_map ?? Dictionary(
            uniqueKeysWithValues: envBranches.map { ("\($0)_\(mergeBranchMiddle)_meger", $0) }
        )
        return GmuxConfig(
            configPath: configPath,
            host: config.gitlab.host,
            token: config.gitlab.token,
            rootDirs: config.project.root_dirs.map(expandPath),
            mergeBranchMiddle: mergeBranchMiddle,
            envBranches: envBranches,
            branchMap: branchMap,
            protectedTargets: config.merge_policy?.protected_targets ?? ["master", "main"],
            autoMergeDelaySeconds: config.merge_policy?.auto_merge_delay_seconds ?? 10,
            autoMergeRetryCount: config.merge_policy?.auto_merge_retry_count ?? 3
        )
    }

    private func loadTomlFileSync<T: Decodable>(path: String) throws -> T {
        guard FileManager.default.fileExists(atPath: path) else {
            throw WorkbenchError.message("配置文件不存在: \(path)")
        }
        let script = """
        import json
        import sys
        import tomli

        with open(sys.argv[1], "rb") as file:
            data = tomli.load(file)
        print(json.dumps(data, ensure_ascii=False))
        """
        let result = try runCommand("python3", arguments: ["-c", script, path])
        guard let data = result.stdout.data(using: .utf8) else {
            throw WorkbenchError.message("TOML 解析结果为空: \(path)")
        }
        return try jsonDecoder.decode(T.self, from: data)
    }

    private func normalizeWorkbenchConfig(_ config: GWorkbenchConfig, configPath: String) -> GWorkbenchConfig {
        let configDirectory = URL(fileURLWithPath: configPath).deletingLastPathComponent()
        let metadataDefaultPath = configDirectory.appendingPathComponent("worktree-metadata.toml").path
        return GWorkbenchConfig(
            configPath: configPath,
            metadataPath: expandPath(config.metadataPath.nonEmpty ?? metadataDefaultPath),
            worktreeProjectsRootDirs: dedupe(config.worktreeProjectsRootDirs.map(expandPath).filterNonEmpty()),
            worktreesRootDir: expandPath(config.worktreesRootDir),
            ideMode: config.ideMode.nonEmpty ?? "app",
            ideCommand: config.ideCommand.nonEmpty ?? "open",
            ideLabel: config.ideLabel.nonEmpty ?? (config.ideCommand.nonEmpty ?? "默认应用"),
            gitlabHost: normalizedGitLabHost(config.gitlabHost),
            gitlabToken: config.gitlabToken.trimmingCharacters(in: .whitespacesAndNewlines),
            mergeRootDirs: dedupe(config.mergeRootDirs.map(expandPath).filterNonEmpty()),
            mergeBranchMiddle: config.mergeBranchMiddle.nonEmpty ?? "henry",
            envBranches: dedupe(config.envBranches.filterNonEmpty()),
            branchMap: config.branchMap
                .filter { !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            protectedTargets: dedupe(config.protectedTargets.filterNonEmpty()),
            autoMergeDelaySeconds: max(config.autoMergeDelaySeconds, 0),
            autoMergeRetryCount: max(config.autoMergeRetryCount, 0)
        )
    }

    private func serializeWorkbenchConfig(_ config: GWorkbenchConfig) -> String {
        let branchMapLines = config.branchMap
            .sorted { lhs, rhs in
                if lhs.key != rhs.key {
                    return lhs.key < rhs.key
                }
                return lhs.value < rhs.value
            }
            .map { "\($0.key) = \"\(escapeTomlString($0.value))\"" }

        let lines: [String] = [
            "[worktree]",
            "projects_root_dirs = \(tomlArray(config.worktreeProjectsRootDirs))",
            "worktrees_root_dir = \"\(escapeTomlString(config.worktreesRootDir))\"",
            "metadata_path = \"\(escapeTomlString(config.metadataPath))\"",
            "ide_mode = \"\(escapeTomlString(config.ideMode))\"",
            "ide_command = \"\(escapeTomlString(config.ideCommand))\"",
            "ide_label = \"\(escapeTomlString(config.ideLabel))\"",
            "",
            "[gitlab]",
            "host = \"\(escapeTomlString(config.gitlabHost))\"",
            "token = \"\(escapeTomlString(config.gitlabToken))\"",
            "",
            "[merge]",
            "root_dirs = \(tomlArray(config.mergeRootDirs))",
            "merge_branch_middle = \"\(escapeTomlString(config.mergeBranchMiddle))\"",
            "env_branches = \(tomlArray(config.envBranches))",
            "",
            "[branch_map]",
            branchMapLines.isEmpty ? "# source_branch = \"target_branch\"" : branchMapLines.joined(separator: "\n"),
            "",
            "[merge_policy]",
            "protected_targets = \(tomlArray(config.protectedTargets))",
            "auto_merge_delay_seconds = \(config.autoMergeDelaySeconds)",
            "auto_merge_retry_count = \(config.autoMergeRetryCount)",
            ""
        ]
        return lines.joined(separator: "\n")
    }

    private func loadWorktreeMetadataMapSync(metadataPath: String) throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: metadataPath) else {
            return [:]
        }
        let metadata: WorktreeMetadataStore = try loadTomlFileSync(path: metadataPath)
        return Dictionary(
            uniqueKeysWithValues: metadata.descriptions.map {
                ("\(normalizePath($0.project_path))#\($0.branch)", $0.description)
            }
        )
    }

    private func saveWorktreeDescriptionSync(
        metadataPath: String,
        projectPath: String,
        branch: String,
        description: String
    ) throws {
        let normalizedProjectPath = normalizePath(projectPath)
        var entries = try loadMetadataEntriesSync(metadataPath: metadataPath)
        entries.removeAll { $0.projectPath == normalizedProjectPath && $0.branch == branch }
        entries.append(.init(projectPath: normalizedProjectPath, branch: branch, description: description))
        try writeMetadataEntriesSync(entries, metadataPath: metadataPath)
    }

    private func clearWorktreeDescriptionSync(
        metadataPath: String,
        projectPath: String,
        branch: String
    ) throws {
        let normalizedProjectPath = normalizePath(projectPath)
        var entries = try loadMetadataEntriesSync(metadataPath: metadataPath)
        entries.removeAll { $0.projectPath == normalizedProjectPath && $0.branch == branch }
        try writeMetadataEntriesSync(entries, metadataPath: metadataPath)
    }

    private func loadMetadataEntriesSync(metadataPath: String) throws -> [MetadataEntry] {
        guard FileManager.default.fileExists(atPath: metadataPath) else {
            return []
        }
        let metadata: WorktreeMetadataStore = try loadTomlFileSync(path: metadataPath)
        return metadata.descriptions.map {
            MetadataEntry(
                projectPath: normalizePath($0.project_path),
                branch: $0.branch,
                description: $0.description
            )
        }
    }

    private func writeMetadataEntriesSync(_ entries: [MetadataEntry], metadataPath: String) throws {
        let sortedEntries = entries.sorted {
            if $0.projectPath != $1.projectPath {
                return $0.projectPath < $1.projectPath
            }
            return $0.branch < $1.branch
        }

        let lines = sortedEntries.flatMap { entry in
            [
                "[[descriptions]]",
                "project_path = \"\(escapeTomlString(entry.projectPath))\"",
                "branch = \"\(escapeTomlString(entry.branch))\"",
                "description = \"\(escapeTomlString(entry.description))\"",
                ""
            ]
        }

        let metadataURL = URL(fileURLWithPath: metadataPath)
        try FileManager.default.createDirectory(at: metadataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try lines.joined(separator: "\n").write(to: metadataURL, atomically: true, encoding: .utf8)
    }

    private func scanLocalProjectsSync(rootDirs: [String]) throws -> [LocalProject] {
        guard !rootDirs.isEmpty else {
            throw WorkbenchError.message("至少需要一个项目根目录")
        }

        var seen = Set<String>()
        var projects: [(name: String, path: String, sourceRoot: String, currentBranch: String, baseBranches: [String], localBranches: [String])] = []

        for rootDir in rootDirs {
            let expandedRoot = expandPath(rootDir)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: expandedRoot, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw WorkbenchError.message("项目根目录不存在: \(expandedRoot)")
            }

            let children = try FileManager.default.contentsOfDirectory(atPath: expandedRoot)
            for child in children {
                let candidate = URL(fileURLWithPath: expandedRoot).appendingPathComponent(child).path
                var isCandidateDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: candidate, isDirectory: &isCandidateDirectory), isCandidateDirectory.boolValue else {
                    continue
                }
                guard FileManager.default.fileExists(atPath: URL(fileURLWithPath: candidate).appendingPathComponent(".git").path) else {
                    continue
                }

                let normalized = normalizePath(candidate)
                guard seen.insert(normalized).inserted else {
                    continue
                }

                let currentBranch = (try? currentLocalBranchSync(projectPath: normalized)) ?? "detached"
                let baseBranches = (try? remoteBranchesSync(projectPath: normalized)) ?? []
                let localBranches = (try? localBranchesSync(projectPath: normalized)) ?? []
                projects.append((
                    name: URL(fileURLWithPath: normalized).lastPathComponent,
                    path: normalized,
                    sourceRoot: normalizePath(expandedRoot),
                    currentBranch: currentBranch,
                    baseBranches: baseBranches,
                    localBranches: localBranches
                ))
            }
        }

        let nameCounts = Dictionary(grouping: projects, by: \.name).mapValues(\.count)
        return projects
            .sorted {
                if $0.name != $1.name {
                    return $0.name < $1.name
                }
                return $0.path < $1.path
            }
            .map { project in
                let displayName: String
                if nameCounts[project.name, default: 0] > 1 {
                    displayName = "\(project.name) (\(URL(fileURLWithPath: project.sourceRoot).lastPathComponent))"
                } else {
                    displayName = project.name
                }
                return LocalProject(
                    id: project.path,
                    name: project.name,
                    displayName: displayName,
                    path: project.path,
                    sourceRoot: project.sourceRoot,
                    currentBranch: project.currentBranch,
                    baseBranches: project.baseBranches,
                    localBranches: project.localBranches
                )
            }
    }

    private func currentLocalBranchSync(projectPath: String) throws -> String {
        let result = try runCommand(
            "git",
            arguments: ["-C", projectPath, "symbolic-ref", "--quiet", "--short", "HEAD"],
            allowFailure: true
        )

        if result.status == 0 {
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "detached"
        }

        let emptyRepoCheck = try runCommand(
            "git",
            arguments: ["-C", projectPath, "rev-parse", "--verify", "HEAD"],
            allowFailure: true
        )
        if emptyRepoCheck.status != 0 {
            return "未提交"
        }

        return "detached"
    }

    private func remoteBranchesSync(projectPath: String) throws -> [String] {
        let output = try runCommand(
            "git",
            arguments: [
                "-C",
                projectPath,
                "for-each-ref",
                "--format=%(refname:short)",
                "--sort=-committerdate",
                "refs/remotes/origin"
            ]
        ).stdout

        let branches = output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: "origin/", with: "") }
            .filter { !$0.isEmpty && $0 != "HEAD" }

        return Array(NSOrderedSet(array: branches)) as? [String] ?? branches
    }

    private func localBranchesSync(projectPath: String) throws -> [String] {
        let output = try runCommand(
            "git",
            arguments: [
                "-C",
                projectPath,
                "for-each-ref",
                "--format=%(refname:short)",
                "--sort=-committerdate",
                "refs/heads"
            ]
        ).stdout
        let branches = output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(NSOrderedSet(array: branches)) as? [String] ?? branches
    }

    private func localBranchExistsSync(projectPath: String, branch: String) throws -> Bool {
        let result = try runCommand(
            "git",
            arguments: ["-C", projectPath, "show-ref", "--verify", "--quiet", "refs/heads/\(branch)"],
            allowFailure: true
        )
        return result.status == 0
    }

    private func remoteBranchExistsSync(projectPath: String, branch: String) throws -> Bool {
        let result = try runCommand(
            "git",
            arguments: ["-C", projectPath, "show-ref", "--verify", "--quiet", "refs/remotes/origin/\(branch)"],
            allowFailure: true
        )
        return result.status == 0
    }

    private func parseWorktreeListSync(projectPath: String) throws -> [ParsedWorktreeEntry] {
        let output = try runCommand(
            "git",
            arguments: ["-C", projectPath, "worktree", "list", "--porcelain"]
        ).stdout

        var entries: [ParsedWorktreeEntry] = []
        var current: ParsedWorktreeEntry?

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let current {
                    entries.append(current)
                }
                current = nil
                continue
            }

            if line.hasPrefix("worktree ") {
                if let current {
                    entries.append(current)
                }
                let path = String(line.dropFirst("worktree ".count))
                current = ParsedWorktreeEntry(path: path.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), head: "", branch: nil)
                continue
            }

            guard var currentEntry = current else {
                continue
            }

            if line.hasPrefix("HEAD ") {
                let head = String(line.dropFirst("HEAD ".count))
                currentEntry.head = head.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            } else if line.hasPrefix("branch ") {
                let branch = String(line.dropFirst("branch ".count))
                currentEntry.branch = branch
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    .replacingOccurrences(of: "refs/heads/", with: "")
            }
            current = currentEntry
        }

        if let current {
            entries.append(current)
        }

        return entries
    }

    private func loadCommitInfoSync(worktreePath: String) throws -> CommitInfo {
        let result = try runCommand(
            "git",
            arguments: [
                "-C",
                worktreePath,
                "log",
                "-5",
                "--pretty=format:%h%x1f%s%x1f%an%x1f%ct"
            ],
            allowFailure: true
        )

        if result.status != 0 {
            let errorText = [result.stderr, result.stdout]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if errorText.contains("does not have any commits yet")
                || errorText.contains("your current branch")
                || errorText.contains("fatal: bad revision")
            {
                return CommitInfo(
                    headLine: "尚无提交记录",
                    updatedAt: "未提交",
                    commits: []
                )
            }

            throw WorkbenchError.message(errorText.isEmpty ? "读取提交记录失败" : errorText)
        }

        let output = result.stdout

        let commits = output
            .split(separator: "\n")
            .map { line -> CommitEntry? in
                let parts = line.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
                guard parts.count == 4 else { return nil }
                let relative = self.relativeDateString(fromUnixTimestamp: parts[3])
                return CommitEntry(sha: parts[0], message: parts[1], author: parts[2], relativeTime: relative)
            }
            .compactMap { $0 }

        if let first = commits.first {
            return CommitInfo(
                headLine: "\(first.sha) · \(first.message)",
                updatedAt: first.relativeTime,
                commits: commits
            )
        }

        return CommitInfo(headLine: "无提交记录", updatedAt: "未知", commits: [])
    }

    private func currentUpstreamSync(worktreePath: String) throws -> String {
        let result = try runCommand(
            "git",
            arguments: ["-C", worktreePath, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
            allowFailure: true
        )
        if result.status == 0 {
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "未配置"
    }

    private func diskUsageSync(path: String) throws -> String {
        try runCommand("du", arguments: ["-sh", path]).stdout
            .split(separator: "\t")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知"
    }

    private func installDependenciesSync(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: url.appendingPathComponent("pnpm-lock.yaml").path) {
            _ = try runCommand("pnpm", arguments: ["install"], currentDirectory: path)
            return
        }
        if fileManager.fileExists(atPath: url.appendingPathComponent("yarn.lock").path) {
            _ = try runCommand("yarn", arguments: ["install"], currentDirectory: path)
            return
        }
        if fileManager.fileExists(atPath: url.appendingPathComponent("package.json").path) {
            _ = try runCommand("npm", arguments: ["install"], currentDirectory: path)
            return
        }
        if fileManager.fileExists(atPath: url.appendingPathComponent("Cargo.toml").path) {
            _ = try runCommand("cargo", arguments: ["fetch"], currentDirectory: path)
        }
    }

    private func makeApprovalEntries(
        approvedUsers: [GitLabUserResponse],
        currentUsername: String,
        approvedByMe: Bool
    ) -> [ApprovalEntry] {
        var entries = approvedUsers.map {
            ApprovalEntry(reviewer: $0.name, detail: "@\($0.username) 已审批", approved: true)
        }

        if !approvedByMe {
            entries.insert(
                ApprovalEntry(reviewer: "我", detail: "@\(currentUsername) 尚未审批", approved: false),
                at: 0
            )
        }

        if entries.isEmpty {
            entries = [ApprovalEntry(reviewer: "暂无审批", detail: "当前还没有人审批这条 MR", approved: false)]
        }
        return entries
    }

    private func mrSubtitle(from mr: GitLabMergeRequestResponse) -> String {
        let description = mr.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let description, !description.isEmpty {
            return description
        }
        return "\(mr.source_branch) -> \(mr.target_branch)"
    }

    private func mapMRStatus(_ mr: GitLabMergeRequestResponse) -> MergeRequestStatus {
        if mr.state == "merged" {
            return .merged
        }
        if mr.state == "closed" {
            return .closed
        }
        if mr.draft == true {
            return .draft
        }

        let mergeStatus = mr.detailed_merge_status ?? mr.merge_status ?? ""
        if mergeStatus.contains("cannot") || mergeStatus.contains("conflict") || mergeStatus.contains("broken") {
            return .blocked
        }
        if (mr.head_pipeline?.status ?? "") == "success" {
            return .ready
        }
        return .open
    }

    private func mapPipelineState(_ status: String?) -> PipelineState {
        switch status {
        case "success":
            return .passed
        case "running", "pending":
            return .pending
        case "failed", "canceled":
            return .failed
        default:
            return .none
        }
    }

    private func effectiveMRBranchMappings(config: GmuxConfig) -> [BranchMapping] {
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

    private func syncAndPushWithProgressSync(
        project: MergeProject,
        config: GmuxConfig,
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
                try updateBranchSync(projectPath: project.path, branch: envBranch)
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
                let message = try syncToMergeBranchSync(projectPath: project.path, sourceBranch: envBranch, mergeBranch: mergeBranch)
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

    private func mergeToTargetsWithProgressSync(
        project: MergeProject,
        config _: GmuxConfig,
        sourceBranch: String,
        targets: [String],
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) throws -> [LocalBranchExecutionResult] {
        guard !targets.isEmpty else {
            throw WorkbenchError.message("未选择目标分支")
        }

        guard try localBranchExistsSync(projectPath: project.path, branch: sourceBranch) else {
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
                let message = try syncToMergeBranchSync(projectPath: project.path, sourceBranch: sourceBranch, mergeBranch: target)
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

    private func updateBranchSync(projectPath: String, branch: String) throws {
        if try localBranchExistsSync(projectPath: projectPath, branch: branch) {
            try checkoutBranchSync(projectPath: projectPath, branch: branch)
        } else if try remoteBranchExistsSync(projectPath: projectPath, branch: branch) {
            try checkoutNewBranchSync(projectPath: projectPath, branch: branch, from: "origin/\(branch)")
        } else {
            throw WorkbenchError.message("分支不存在: \(branch)")
        }

        _ = try runCommand("git", arguments: ["-C", projectPath, "pull", "origin", branch])
    }

    private func syncToMergeBranchSync(projectPath: String, sourceBranch: String, mergeBranch: String) throws -> String {
        if try localBranchExistsSync(projectPath: projectPath, branch: mergeBranch) {
            try checkoutBranchSync(projectPath: projectPath, branch: mergeBranch)
        } else if try remoteBranchExistsSync(projectPath: projectPath, branch: mergeBranch) {
            try checkoutNewBranchSync(projectPath: projectPath, branch: mergeBranch, from: "origin/\(mergeBranch)")
        } else {
            try checkoutNewBranchSync(projectPath: projectPath, branch: mergeBranch, from: sourceBranch)
            _ = try runCommand("git", arguments: ["-C", projectPath, "push", "origin", mergeBranch])
            return "创建并推送新分支: \(mergeBranch)"
        }

        switch try mergeBranchSync(projectPath: projectPath, sourceBranch: sourceBranch) {
        case .success:
            _ = try runCommand("git", arguments: ["-C", projectPath, "push", "origin", mergeBranch])
            return "同步完成: \(sourceBranch) -> \(mergeBranch)"
        case .alreadyUpToDate:
            return "已是最新: \(sourceBranch) -> \(mergeBranch)"
        case .conflict(let files):
            let fileList = files.isEmpty ? "（无法获取冲突文件）" : files.joined(separator: ", ")
            throw WorkbenchError.message("合并冲突已自动中止: \(sourceBranch) -> \(mergeBranch)，冲突文件: \(fileList)")
        }
    }

    private func checkoutBranchSync(projectPath: String, branch: String) throws {
        _ = try runCommand("git", arguments: ["-C", projectPath, "checkout", branch])
    }

    private func checkoutNewBranchSync(projectPath: String, branch: String, from: String) throws {
        _ = try runCommand("git", arguments: ["-C", projectPath, "checkout", "-b", branch, from])
    }

    private func mergeBranchSync(projectPath: String, sourceBranch: String) throws -> GitMergeExecutionResult {
        let result = try runCommand(
            "git",
            arguments: ["-C", projectPath, "merge", sourceBranch, "--no-edit"],
            allowFailure: true
        )

        if result.status == 0 {
            let output = [result.stdout, result.stderr].joined(separator: "\n")
            if output.contains("Already up to date") {
                return .alreadyUpToDate
            }
            return .success
        }

        if try hasActiveMergeHeadSync(projectPath: projectPath) {
            let files = try conflictFilesSync(projectPath: projectPath)
            _ = try? runCommand("git", arguments: ["-C", projectPath, "merge", "--abort"], allowFailure: true)
            return .conflict(files)
        }

        let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? "合并失败: \(sourceBranch)"
        throw WorkbenchError.message(detail)
    }

    private func hasActiveMergeHeadSync(projectPath: String) throws -> Bool {
        let gitDirRaw = try runCommand("git", arguments: ["-C", projectPath, "rev-parse", "--git-dir"]).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let gitDirURL: URL
        if gitDirRaw.hasPrefix("/") {
            gitDirURL = URL(fileURLWithPath: gitDirRaw)
        } else {
            gitDirURL = URL(fileURLWithPath: projectPath).appendingPathComponent(gitDirRaw)
        }
        return FileManager.default.fileExists(atPath: gitDirURL.appendingPathComponent("MERGE_HEAD").path)
    }

    private func conflictFilesSync(projectPath: String) throws -> [String] {
        let result = try runCommand(
            "git",
            arguments: ["-C", projectPath, "diff", "--name-only", "--diff-filter=U"],
            allowFailure: true
        )
        return result.stdout
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func localTargetMergeBranches(config: GmuxConfig, projectName: String) -> [(String, String)] {
        config.envBranches.map { envBranch in
            (envBranch, mergeBranchName(envBranch: envBranch, config: config, projectName: projectName))
        }
    }

    private func mergeBranchName(envBranch: String, config: GmuxConfig, projectName: String) -> String {
        let middle = config.mergeBranchMiddle == "PROJECT_NAME" ? projectName : config.mergeBranchMiddle
        return "\(envBranch)_\(middle)_meger"
    }

    private func request<T: Decodable>(
        host: String,
        token: String,
        path: String,
        method: String,
        body: Data?,
        allowEmptyResponse: Bool = false
    ) async throws -> T {
        guard let url = URL(string: normalizedGitLabHost(host) + "/api/v4" + path) else {
            throw WorkbenchError.message("GitLab 地址无效: \(host)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkbenchError.message("GitLab 响应无效")
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let text = String(decoding: data, as: UTF8.self)
            throw WorkbenchError.message("HTTP \(httpResponse.statusCode): \(text)")
        }

        if allowEmptyResponse, data.isEmpty {
            return EmptyResponse() as! T
        }

        if allowEmptyResponse, T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            if allowEmptyResponse, data.isEmpty {
                return EmptyResponse() as! T
            }
            throw WorkbenchError.message("解析 GitLab 响应失败: \(error.localizedDescription)")
        }
    }

    private func runCommand(
        _ command: String,
        arguments: [String],
        currentDirectory: String? = nil,
        allowFailure: Bool = false
    ) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        if let currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let result = ShellResult(stdout: stdout, stderr: stderr, status: process.terminationStatus)

        if !allowFailure && result.status != 0 {
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            throw WorkbenchError.message(detail.isEmpty ? "\(command) 执行失败" : detail)
        }

        return result
    }

    private func resolveConfigPath(appName: String, fileName: String) -> String {
        let environment = ProcessInfo.processInfo.environment
        if let xdgConfigHome = environment["XDG_CONFIG_HOME"], !xdgConfigHome.isEmpty {
            return URL(fileURLWithPath: xdgConfigHome)
                .appendingPathComponent(appName)
                .appendingPathComponent(fileName)
                .path
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".config")
            .appendingPathComponent(appName)
            .appendingPathComponent(fileName)
            .path
    }

    private func normalizedGitLabHost(_ host: String) -> String {
        var host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        while host.hasSuffix("/") {
            host.removeLast()
        }
        return host
    }

    private func normalizePath(_ path: String) -> String {
        URL(fileURLWithPath: expandPath(path)).standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func expandPath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    private func relativeDateString(fromUnixTimestamp timestamp: String) -> String {
        guard let seconds = Double(timestamp) else {
            return "未知"
        }
        return relativeDateString(from: Date(timeIntervalSince1970: seconds))
    }

    private func relativeDateString(fromISO8601 value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "未知"
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return relativeDateString(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return relativeDateString(from: date)
        }
        return value
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func escapeTomlString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func tomlArray(_ values: [String]) -> String {
        let items = values.map { "\"\(escapeTomlString($0))\"" }.joined(separator: ", ")
        return "[\(items)]"
    }

    private func dedupe(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

private struct MetadataEntry {
    let projectPath: String
    let branch: String
    let description: String
}

private struct ParsedWorktreeEntry {
    var path: String
    var head: String
    var branch: String?
}

private struct CommitInfo {
    let headLine: String
    let updatedAt: String
    let commits: [CommitEntry]
}

private struct EmptyResponse: Decodable {}

private struct MergeResponse: Decodable {
    let state: String
}

private enum GitMergeExecutionResult {
    case success
    case alreadyUpToDate
    case conflict([String])
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Array where Element == String {
    func filterNonEmpty() -> [String] {
        compactMap { $0.nonEmpty }
    }
}
