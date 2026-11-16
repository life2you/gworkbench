import Foundation

final class CompositeHostingProvider: HostingProvider {
    let gitCli: GitCliService
    let gitLabProvider: GitLabProvider
    let gitHubProvider: GitHubProvider

    init(
        gitCli: GitCliService = GitCliService(),
        gitLabProvider: GitLabProvider? = nil,
        gitHubProvider: GitHubProvider? = nil
    ) {
        self.gitCli = gitCli
        self.gitLabProvider = gitLabProvider ?? GitLabProvider(gitCli: gitCli)
        self.gitHubProvider = gitHubProvider ?? GitHubProvider(gitCli: gitCli)
    }

    func loadMergeContext(
        config: MergeWorkflowConfig,
        localProjects: [LocalProject],
        branchMappings: [BranchMapping],
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> MergeRequestContext {
        let gitlabLocalProjects = localProjects.filter { $0.platform == .gitlab }
        let githubLocalProjects = localProjects.filter { $0.platform == .github }
        let otherLocalProjects = localProjects.filter { $0.platform == .local }

        var allProjects: [MergeProject] = []
        var resolvedUsername = ""

        // 1. 加载 GitLab 项目（仅在存在 GitLab 仓库且配置了 host + token 时请求远端 API；否则降级本地构造，不阻塞 GitHub 用户）
        if !gitlabLocalProjects.isEmpty {
            let hasGitLabCreds = !normalizedGitLabHost(config.host).isEmpty
                && !config.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if hasGitLabCreds {
                do {
                    let gitlabContext = try await gitLabProvider.loadMergeContext(
                        config: config,
                        localProjects: gitlabLocalProjects,
                        branchMappings: branchMappings,
                        onProgress: onProgress
                    )
                    allProjects.append(contentsOf: gitlabContext.projects)
                    if !gitlabContext.currentUsername.isEmpty {
                        resolvedUsername = gitlabContext.currentUsername
                    }
                } catch {
                    // GitLab 接口异常时仍保留仓库列表，避免把 GitHub 上下文也一并拖垮
                    allProjects.append(contentsOf: buildFallbackProjects(gitlabLocalProjects, branchMappings: branchMappings))
                }
            } else {
                allProjects.append(contentsOf: buildFallbackProjects(gitlabLocalProjects, branchMappings: branchMappings))
            }
        }

        // 2. 加载 GitHub 项目
        if !githubLocalProjects.isEmpty {
            let githubContext = try await gitHubProvider.loadMergeContext(
                config: config,
                localProjects: githubLocalProjects,
                branchMappings: branchMappings,
                onProgress: onProgress
            )
            allProjects.append(contentsOf: githubContext.projects)
            if resolvedUsername.isEmpty {
                resolvedUsername = githubContext.currentUsername
            }
        }

        // 3. 纯本地项目
        if !otherLocalProjects.isEmpty {
            allProjects.append(contentsOf: buildFallbackProjects(otherLocalProjects, branchMappings: branchMappings))
        }

        let sorted = allProjects.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
        return MergeRequestContext(
            config: config,
            currentUsername: resolvedUsername.isEmpty ? "me" : resolvedUsername,
            projects: sorted
        )
    }

    func loadPendingMergeRequests(
        context: MergeRequestContext,
        project: MergeProject,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [MergeRequestItem] {
        switch project.platform {
        case .github:
            return try await gitHubProvider.loadPendingMergeRequests(
                context: context,
                project: project,
                onProgress: onProgress
            )
        case .gitlab:
            guard !normalizedGitLabHost(context.config.host).isEmpty,
                  !context.config.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WorkbenchError.message("请先在「设置 → GitLab」填写服务器地址与 Personal Access Token。")
            }
            return try await gitLabProvider.loadPendingMergeRequests(
                context: context,
                project: project,
                onProgress: onProgress
            )
        case .local, .all:
            return []
        }
    }

    func createMergeRequest(
        context: MergeRequestContext,
        project: MergeProject,
        sourceBranch: String,
        targetBranch: String
    ) async throws -> MergeRequestItem {
        switch project.platform {
        case .github:
            return try await gitHubProvider.createMergeRequest(
                context: context,
                project: project,
                sourceBranch: sourceBranch,
                targetBranch: targetBranch
            )
        case .gitlab:
            return try await gitLabProvider.createMergeRequest(
                context: context,
                project: project,
                sourceBranch: sourceBranch,
                targetBranch: targetBranch
            )
        case .local, .all:
            throw WorkbenchError.message("纯本地仓库暂不支持创建远端合并请求")
        }
    }

    func approveAndMerge(
        context: MergeRequestContext,
        item: MergeRequestItem,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String] {
        switch item.platform {
        case .github:
            return try await gitHubProvider.approveAndMerge(
                context: context,
                item: item,
                onProgress: onProgress
            )
        case .gitlab, .local, .all:
            return try await gitLabProvider.approveAndMerge(
                context: context,
                item: item,
                onProgress: onProgress
            )
        }
    }

    func closeMergeRequest(
        context: MergeRequestContext,
        item: MergeRequestItem
    ) async throws {
        switch item.platform {
        case .github:
            try await gitHubProvider.closeMergeRequest(context: context, item: item)
        case .gitlab, .local, .all:
            try await gitLabProvider.closeMergeRequest(context: context, item: item)
        }
    }

    private func buildFallbackProjects(_ localProjects: [LocalProject], branchMappings: [BranchMapping]) -> [MergeProject] {
        localProjects.map { project in
            MergeProject(
                id: project.id,
                name: project.name,
                displayName: project.displayName,
                path: project.path,
                sourceRoot: project.sourceRoot,
                currentBranch: project.currentBranch,
                gitLabProjectID: nil,
                githubRepoSlug: project.platform == .github ? GitHubProvider.parseRepoSlug(from: project.remoteURL) : nil,
                branchMappings: branchMappings,
                remoteBranches: [],
                localBranches: project.localBranches,
                remoteURL: project.remoteURL,
                platform: project.platform
            )
        }
    }
}
