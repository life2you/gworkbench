import Foundation

final class WorkbenchService: Sendable {
    let configService: ConfigService
    let gitCliService: GitCliService
    let worktreeService: WorktreeService
    let branchSyncService: BranchSyncService
    let hostingProvider: HostingProvider

    init(
        configService: ConfigService = ConfigService(),
        gitCliService: GitCliService = GitCliService(),
        worktreeService: WorktreeService? = nil,
        branchSyncService: BranchSyncService? = nil,
        hostingProvider: HostingProvider? = nil
    ) {
        self.configService = configService
        self.gitCliService = gitCliService
        self.worktreeService = worktreeService ?? WorktreeService(gitCli: gitCliService, configService: configService)
        self.branchSyncService = branchSyncService ?? BranchSyncService(gitCli: gitCliService)
        self.hostingProvider = hostingProvider ?? GitLabProvider(gitCli: gitCliService)
    }

    func loadWorkbenchConfig() async throws -> GWorkbenchConfig {
        try await Task.detached(priority: .userInitiated) {
            try self.configService.loadOrCreateWorkbenchConfig()
        }.value
    }

    func reloadWorkbenchConfig() async throws -> GWorkbenchConfig {
        try await Task.detached(priority: .userInitiated) {
            try self.configService.loadWorkbenchConfig()
        }.value
    }

    func saveWorkbenchConfig(_ config: GWorkbenchConfig) async throws -> GWorkbenchConfig {
        try await Task.detached(priority: .userInitiated) {
            try self.configService.saveWorkbenchConfig(config)
            return try self.configService.loadWorkbenchConfig()
        }.value
    }

    func loadWorktreeSnapshot(
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> WorktreeSnapshot {
        onProgress(.init(title: "读取 GWorkbench 配置", detail: "正在定位桌面版配置文件", current: 0, total: 4))
        let config = try await Task.detached(priority: .userInitiated) {
            try self.configService.loadWorkbenchConfig().asWorktreeConfig()
        }.value
        return try await worktreeService.loadWorktreeSnapshot(config: config, onProgress: onProgress)
    }

    func createWorktree(
        config: WorktreeConfig,
        project: LocalProject,
        draft: CreateWorktreeDraft,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> CreateWorktreeResult {
        try await worktreeService.createWorktree(config: config, project: project, draft: draft, onProgress: onProgress)
    }

    func removeWorktree(
        config: WorktreeConfig,
        item: WorktreeItem,
        deleteLocalBranch: Bool,
        deleteRemoteBranch: Bool,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws {
        try await worktreeService.removeWorktree(
            config: config,
            item: item,
            deleteLocalBranch: deleteLocalBranch,
            deleteRemoteBranch: deleteRemoteBranch,
            onProgress: onProgress
        )
    }

    func updateWorktreeDescription(
        config: WorktreeConfig,
        item: WorktreeItem,
        description: String
    ) async throws {
        try await worktreeService.updateWorktreeDescription(config: config, item: item, description: description)
    }

    func loadLocalMergeContext(
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> LocalMergeContext {
        onProgress(.init(title: "读取项目配置", detail: "正在定位本地分支同步配置", current: 0, total: 3))
        let config = try await Task.detached(priority: .userInitiated) {
            let workbenchConfig = try self.configService.loadWorkbenchConfig()
            return workbenchConfig.asMergeWorkflowConfig()
        }.value

        return try await branchSyncService.loadLocalMergeContext(config: config, onProgress: onProgress)
    }

    func loadMergeContext(
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> MergeRequestContext {
        onProgress(.init(title: "读取 GWorkbench 配置", detail: "正在定位 GitLab 与分支映射配置", current: 0, total: 4))
        let config = try await Task.detached(priority: .userInitiated) {
            try self.configService.loadWorkbenchConfig().asMergeWorkflowConfig()
        }.value

        onProgress(.init(title: "扫描本地项目", detail: "正在读取可用仓库", current: 1, total: 4))
        let localProjects = try await Task.detached(priority: .userInitiated) {
            try self.gitCliService.scanLocalProjects(rootDirs: config.rootDirs)
        }.value

        let mappings = branchSyncService.effectiveMRBranchMappings(config: config)
        return try await hostingProvider.loadMergeContext(
            config: config,
            localProjects: localProjects,
            branchMappings: mappings,
            onProgress: onProgress
        )
    }

    func loadPendingMergeRequests(
        context: MergeRequestContext,
        project: MergeProject,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [MergeRequestItem] {
        try await hostingProvider.loadPendingMergeRequests(context: context, project: project, onProgress: onProgress)
    }

    func executeLocalSync(
        context: LocalMergeContext,
        project: MergeProject,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String] {
        try await branchSyncService.executeLocalSync(context: context, project: project, onProgress: onProgress)
    }

    func executeLocalMerge(
        context: LocalMergeContext,
        project: MergeProject,
        sourceBranch: String,
        targets: [String],
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String] {
        try await branchSyncService.executeLocalMerge(
            context: context,
            project: project,
            sourceBranch: sourceBranch,
            targets: targets,
            onProgress: onProgress
        )
    }

    func approveAndMerge(
        context: MergeRequestContext,
        item: MergeRequestItem,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String] {
        try await hostingProvider.approveAndMerge(context: context, item: item, onProgress: onProgress)
    }

    func closeMergeRequest(context: MergeRequestContext, item: MergeRequestItem) async throws {
        try await hostingProvider.closeMergeRequest(context: context, item: item)
    }

    func createMergeRequest(
        context: MergeRequestContext,
        project: MergeProject,
        sourceBranch: String,
        targetBranch: String
    ) async throws -> MergeRequestItem {
        try await hostingProvider.createMergeRequest(
            context: context,
            project: project,
            sourceBranch: sourceBranch,
            targetBranch: targetBranch
        )
    }

    func createBatchMergeRequests(
        context: MergeRequestContext,
        project: MergeProject,
        mappings: [BranchMapping],
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String] {
        try await hostingProvider.createBatchMergeRequests(
            context: context,
            project: project,
            mappings: mappings,
            onProgress: onProgress
        )
    }

    func approveAndMergeBatch(
        context: MergeRequestContext,
        items: [MergeRequestItem],
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String] {
        try await hostingProvider.approveAndMergeBatch(
            context: context,
            items: items,
            onProgress: onProgress
        )
    }

    func openInIDE(config: WorktreeConfig, path: String) throws {
        try worktreeService.openInIDE(config: config, path: path)
    }

    func openInTerminal(path: String, terminalName: String = "Terminal", bundleID: String? = nil) throws {
        try worktreeService.openInTerminal(path: path, terminalName: terminalName, bundleID: bundleID)
    }
}
