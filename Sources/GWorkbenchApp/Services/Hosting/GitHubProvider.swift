import Foundation

private struct GitHubUserResponse: Decodable {
    let login: String
    let name: String?
}

private struct GitHubBranchRefResponse: Decodable {
    let ref: String
    let sha: String
}

private struct GitHubLabelResponse: Decodable {
    let name: String
}

private struct GitHubPullRequestResponse: Decodable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let html_url: String
    let state: String
    let draft: Bool?
    let merged_at: String?
    let mergeable: Bool?
    let mergeable_state: String?
    let updated_at: String?
    let head: GitHubBranchRefResponse
    let base: GitHubBranchRefResponse
    let user: GitHubUserResponse
    let labels: [GitHubLabelResponse]?
}

private struct GitHubReviewResponse: Decodable {
    let user: GitHubUserResponse?
    let state: String
    let submitted_at: String?
}

private struct GitHubCommitResponse: Decodable {
    struct CommitDetail: Decodable {
        struct AuthorDetail: Decodable {
            let name: String?
            let date: String?
        }

        let message: String
        let author: AuthorDetail?
    }

    let sha: String
    let commit: CommitDetail
    let author: GitHubUserResponse?
}

private struct GitHubCheckRunsResponse: Decodable {
    struct CheckRun: Decodable {
        let status: String
        let conclusion: String?
    }

    let total_count: Int?
    let check_runs: [CheckRun]?
}

private struct GitHubMergeResponse: Decodable {
    let merged: Bool?
    let message: String?
}

final class GitHubProvider: HostingProvider {
    let gitCli: GitCliService

    init(gitCli: GitCliService = GitCliService()) {
        self.gitCli = gitCli
    }

    static func apiBaseURL(from host: String) -> String {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "https://api.github.com" }
        var withScheme = trimmed
        if !withScheme.contains("://") {
            withScheme = "https://\(withScheme)"
        }
        while withScheme.hasSuffix("/") {
            withScheme.removeLast()
        }
        let lower = withScheme.lowercased()
        if lower == "https://github.com" || lower == "http://github.com" || lower == "https://api.github.com" {
            return "https://api.github.com"
        }
        if lower.hasSuffix("/api/v3") {
            return withScheme
        }
        return withScheme + "/api/v3"
    }

    static func cliHostname(from host: String) -> String? {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var withScheme = trimmed
        if !withScheme.contains("://") {
            withScheme = "https://\(withScheme)"
        }
        guard let parsed = URL(string: withScheme)?.host?.lowercased(), !parsed.isEmpty else {
            return nil
        }
        if parsed == "github.com" || parsed == "api.github.com" {
            return nil
        }
        return parsed
    }

    static func testConnection(configuredToken: String, host: String = "") async throws -> String {
        let token = resolveToken(configuredToken: configuredToken, host: host)
        guard !token.isEmpty else {
            throw WorkbenchError.message("未检测到 GitHub PAT 或 gh auth token")
        }
        let user: GitHubUserResponse = try await GitHubProvider().request(
            host: host,
            token: token,
            path: "/user",
            method: "GET",
            body: nil
        )
        let hostLabel = cliHostname(from: host) ?? "github.com"
        return "已认证 GitHub (\(hostLabel)) 账号 @\(user.login)"
    }

    /// 解析 GitHub 访问令牌：优先使用配置里的 PAT，其次尝试继承本机 `gh auth token`
    static func resolveToken(configuredToken: String, host: String = "") -> String {
        let trimmed = configuredToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        var args = ["auth", "token"]
        if let hostname = cliHostname(from: host) {
            args.append(contentsOf: ["--hostname", hostname])
        }
        if let result = try? ProcessRunner.runCommand(
            "gh",
            arguments: args,
            allowFailure: true
        ), result.status == 0 {
            let cliToken = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cliToken.isEmpty {
                return cliToken
            }
        }
        return ""
    }

    /// 从 remote URL 提取 `owner/repo`
    static func parseRepoSlug(from remoteURL: String?) -> String? {
        guard let raw = remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        var pathPart: String?
        if raw.hasPrefix("git@") {
            // git@github.com:owner/repo.git
            if let colonIndex = raw.firstIndex(of: ":") {
                pathPart = String(raw[raw.index(after: colonIndex)...])
            }
        } else if let url = URL(string: raw), !url.path.isEmpty {
            pathPart = url.path
        }

        guard var cleaned = pathPart else { return nil }
        while cleaned.hasPrefix("/") {
            cleaned.removeFirst()
        }
        if cleaned.hasSuffix(".git") {
            cleaned.removeLast(4)
        }
        while cleaned.hasSuffix("/") {
            cleaned.removeLast()
        }

        let parts = cleaned.split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return nil }
        return "\(parts[parts.count - 2])/\(parts[parts.count - 1])"
    }

    func loadMergeContext(
        config: MergeWorkflowConfig,
        localProjects: [LocalProject],
        branchMappings: [BranchMapping],
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> MergeRequestContext {
        let token = Self.resolveToken(configuredToken: config.githubToken, host: config.githubHost)
        var currentUsername = "me"

        if !token.isEmpty {
            onProgress(.init(title: "连接 GitHub", detail: "正在校验当前 GitHub 账号", current: 2, total: 4))
            if let user: GitHubUserResponse = try? await request(
                host: config.githubHost,
                token: token,
                path: "/user",
                method: "GET",
                body: nil
            ) {
                currentUsername = user.login
            }
        }

        onProgress(.init(title: "整理 GitHub 仓库", detail: "解析本地仓库 owner/repo 标识", current: 3, total: 4))
        let gitCli = self.gitCli
        let githubMappings = Self.buildDefaultMappings(config: config)

        final class Collector: @unchecked Sendable {
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

        let collector = Collector()
        DispatchQueue.concurrentPerform(iterations: localProjects.count) { index in
            let project = localProjects[index]
            let remoteBranches = (try? gitCli.remoteBranches(projectPath: project.path)) ?? []
            let localBranches = (try? gitCli.localBranches(projectPath: project.path)) ?? []
            let slug = Self.parseRepoSlug(from: project.remoteURL)

            collector.append(
                MergeProject(
                    id: project.id,
                    name: project.name,
                    displayName: project.displayName,
                    path: project.path,
                    sourceRoot: project.sourceRoot,
                    currentBranch: project.currentBranch,
                    gitLabProjectID: nil,
                    githubRepoSlug: slug,
                    branchMappings: githubMappings.isEmpty ? branchMappings : githubMappings,
                    remoteBranches: remoteBranches,
                    localBranches: localBranches,
                    remoteURL: project.remoteURL,
                    platform: project.platform
                )
            )
        }

        let projects = collector.all.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        onProgress(.init(title: "完成", detail: "已加载 \(projects.count) 个 GitHub 项目", current: 4, total: 4))
        return MergeRequestContext(config: config, currentUsername: currentUsername, projects: projects)
    }

    func loadPendingMergeRequests(
        context: MergeRequestContext,
        project: MergeProject,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [MergeRequestItem] {
        guard let slug = project.githubRepoSlug ?? Self.parseRepoSlug(from: project.remoteURL) else {
            throw WorkbenchError.message("无法从远程仓库地址解析 GitHub owner/repo：\(project.remoteURL ?? "未知")")
        }

        let token = Self.resolveToken(configuredToken: context.config.githubToken, host: context.config.githubHost)
        guard !token.isEmpty else {
            throw WorkbenchError.message("未检测到 GitHub 访问令牌。请在「设置」填写 Token，或在本机终端执行 `gh auth login`。")
        }

        onProgress(.init(title: "读取 Pull Requests", detail: "正在从 GitHub 拉取 \(slug) 的 PR", current: 1, total: 3))
        let pulls: [GitHubPullRequestResponse] = try await request(
            host: context.config.githubHost,
            token: token,
            path: "/repos/\(slug)/pulls?state=open&per_page=100",
            method: "GET",
            body: nil
        )

        onProgress(.init(title: "读取评审与检查状态", detail: "正在补全 \(pulls.count) 条 PR 的评审与 CI 信息", current: 2, total: 3))
        let currentUsername = context.currentUsername
        let protectedTargets = Set(context.config.protectedTargets)
        let provider = self

        let items = try await withThrowingTaskGroup(of: MergeRequestItem.self) { group in
            for pr in pulls {
                group.addTask {
                    async let reviewsTask: [GitHubReviewResponse] = (try? await provider.request(
                        host: context.config.githubHost,
                        token: token,
                        path: "/repos/\(slug)/pulls/\(pr.number)/reviews?per_page=100",
                        method: "GET",
                        body: nil
                    )) ?? []
                    async let commitsTask: [GitHubCommitResponse] = (try? await provider.request(
                        host: context.config.githubHost,
                        token: token,
                        path: "/repos/\(slug)/pulls/\(pr.number)/commits?per_page=50",
                        method: "GET",
                        body: nil
                    )) ?? []
                    async let checksTask: GitHubCheckRunsResponse? = try? await provider.request(
                        host: context.config.githubHost,
                        token: token,
                        path: "/repos/\(slug)/commits/\(pr.head.sha)/check-runs?per_page=50",
                        method: "GET",
                        body: nil
                    )

                    let reviews = await reviewsTask
                    let commitResponses = await commitsTask
                    let checksResponse = await checksTask

                    let approvedUsernames = Set(
                        reviews
                            .filter { $0.state.uppercased() == "APPROVED" }
                            .compactMap { $0.user?.login }
                    )
                    let approvedByMe = approvedUsernames.contains(currentUsername)
                    let approvalEntries = provider.makeApprovalEntries(
                        reviews: reviews,
                        currentUsername: currentUsername,
                        authorUsername: pr.user.login,
                        approvedByMe: approvedByMe
                    )

                    let commitEntries = commitResponses.map { commit in
                        let titleLine = commit.commit.message
                            .split(separator: "\n", maxSplits: 1)
                            .first
                            .map(String.init) ?? commit.commit.message
                        return CommitEntry(
                            sha: String(commit.sha.prefix(8)),
                            message: titleLine,
                            author: commit.author?.login ?? commit.commit.author?.name ?? "unknown",
                            relativeTime: DateFormatterUtils.relativeDateString(fromISO8601: commit.commit.author?.date)
                        )
                    }

                    let pipeline = provider.mapPipelineState(checksResponse)
                    let status = provider.mapPRStatus(pr, pipeline: pipeline)

                    let approvalProgressText: String
                    if !approvedUsernames.isEmpty {
                        approvalProgressText = approvedByMe ? "我已批准 (\(approvedUsernames.count))" : "已获批准 (\(approvedUsernames.count))"
                    } else if pr.user.login == currentUsername {
                        approvalProgressText = "自己的 PR"
                    } else {
                        approvalProgressText = "待评审"
                    }

                    return MergeRequestItem(
                        id: "gh-\(slug)-\(pr.number)",
                        project: project.displayName,
                        projectName: project.name,
                        projectPath: project.path,
                        projectId: pr.id,
                        iid: pr.number,
                        title: pr.title,
                        subtitle: provider.prSubtitle(from: pr),
                        sourceBranch: pr.head.ref,
                        targetBranch: pr.base.ref,
                        author: pr.user.name ?? pr.user.login,
                        authorUsername: pr.user.login,
                        updatedAt: DateFormatterUtils.relativeDateString(fromISO8601: pr.updated_at),
                        approvalProgress: approvalProgressText,
                        approvedByMe: approvedByMe,
                        status: status,
                        pipeline: pipeline,
                        labels: (pr.labels ?? []).map(\.name),
                        protectedTarget: protectedTargets.contains(pr.base.ref),
                        approvals: approvalEntries,
                        activity: [
                            ActivityEntry(
                                actor: pr.user.login,
                                summary: "创建了这条 PR",
                                relativeTime: DateFormatterUtils.relativeDateString(fromISO8601: pr.updated_at)
                            )
                        ],
                        commits: commitEntries,
                        webURL: pr.html_url,
                        platform: .github,
                        repoSlug: slug
                    )
                }
            }

            var collected: [MergeRequestItem] = []
            for try await item in group {
                collected.append(item)
            }
            return collected.sorted {
                if $0.protectedTarget != $1.protectedTarget {
                    return $0.protectedTarget
                }
                return $0.iid > $1.iid
            }
        }

        onProgress(.init(title: "完成", detail: "已加载 \(items.count) 条开放 PR", current: 3, total: 3))
        return items
    }

    func createMergeRequest(
        context: MergeRequestContext,
        project: MergeProject,
        sourceBranch: String,
        targetBranch: String
    ) async throws -> MergeRequestItem {
        guard let slug = project.githubRepoSlug ?? Self.parseRepoSlug(from: project.remoteURL) else {
            throw WorkbenchError.message("当前项目未匹配到 GitHub owner/repo")
        }

        let token = Self.resolveToken(configuredToken: context.config.githubToken, host: context.config.githubHost)
        guard !token.isEmpty else {
            throw WorkbenchError.message("未检测到 GitHub 访问令牌。请在设置填写 Token 或执行 `gh auth login`。")
        }

        let body: [String: Any] = [
            "title": "\(sourceBranch) -> \(targetBranch)",
            "head": sourceBranch,
            "base": targetBranch,
            "body": "Created by GWorkbench"
        ]

        let pr: GitHubPullRequestResponse = try await request(
            host: context.config.githubHost,
            token: token,
            path: "/repos/\(slug)/pulls",
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: body)
        )

        return MergeRequestItem(
            id: "gh-\(slug)-\(pr.number)",
            project: project.displayName,
            projectName: project.name,
            projectPath: project.path,
            projectId: pr.id,
            iid: pr.number,
            title: pr.title,
            subtitle: prSubtitle(from: pr),
            sourceBranch: pr.head.ref,
            targetBranch: pr.base.ref,
            author: pr.user.name ?? pr.user.login,
            authorUsername: pr.user.login,
            updatedAt: DateFormatterUtils.relativeDateString(fromISO8601: pr.updated_at),
            approvalProgress: "刚创建",
            approvedByMe: false,
            status: mapPRStatus(pr, pipeline: .none),
            pipeline: .none,
            labels: (pr.labels ?? []).map(\.name),
            protectedTarget: context.config.protectedTargets.contains(pr.base.ref),
            approvals: [ApprovalEntry(reviewer: "待评审", detail: "刚创建 Pull Request", approved: false)],
            activity: [ActivityEntry(actor: context.currentUsername, summary: "创建了这条 PR", relativeTime: "刚刚")],
            commits: [],
            webURL: pr.html_url,
            platform: .github,
            repoSlug: slug
        )
    }

    func approveAndMerge(
        context: MergeRequestContext,
        item: MergeRequestItem,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String] {
        guard let slug = item.repoSlug ?? Self.parseRepoSlug(from: context.projects.first(where: { $0.path == item.projectPath })?.remoteURL) else {
            throw WorkbenchError.message("无法解析 PR 所属的 GitHub owner/repo")
        }

        let token = Self.resolveToken(configuredToken: context.config.githubToken, host: context.config.githubHost)
        guard !token.isEmpty else {
            throw WorkbenchError.message("未检测到 GitHub 访问令牌。请在设置填写 Token 或执行 `gh auth login`。")
        }

        var logs: [String] = []

        if !item.approvedByMe && item.authorUsername != context.currentUsername {
            onProgress(.init(title: "批准 PR", detail: "\(item.iidLabel) \(item.sourceBranch) -> \(item.targetBranch)", current: 1, total: 3))
            let reviewBody = ["event": "APPROVE"]
            do {
                let _: GitHubReviewResponse = try await request(
                    host: context.config.githubHost,
                    token: token,
                    path: "/repos/\(slug)/pulls/\(item.iid)/reviews",
                    method: "POST",
                    body: try JSONSerialization.data(withJSONObject: reviewBody)
                )
                logs.append("已批准 PR: \(item.iidLabel)")
            } catch {
                logs.append("跳过批准（可能受仓库权限或作者限制）: \(error.localizedDescription)")
            }
        } else if item.authorUsername == context.currentUsername {
            logs.append("GitHub 不允许批准自己发起的 PR，直接执行合并")
        } else {
            logs.append("已批准过该 PR，跳过重复批准")
        }

        let totalAttempts = max(context.config.autoMergeRetryCount, 0) + 1
        for attempt in 1...totalAttempts {
            let step = min(attempt + 1, totalAttempts + 1)
            if attempt > 1 && context.config.autoMergeDelaySeconds > 0 {
                onProgress(.init(
                    title: "等待重试合并",
                    detail: "第 \(attempt) 次合并前等待 \(context.config.autoMergeDelaySeconds) 秒",
                    current: step,
                    total: totalAttempts + 1
                ))
                try await Task.sleep(for: .seconds(context.config.autoMergeDelaySeconds))
            }

            onProgress(.init(
                title: "合并 PR",
                detail: "第 \(attempt) 次尝试合并 \(item.iidLabel)",
                current: step,
                total: totalAttempts + 1
            ))

            do {
                let mergeBody = ["merge_method": "merge"]
                let response: GitHubMergeResponse = try await request(
                    host: context.config.githubHost,
                    token: token,
                    path: "/repos/\(slug)/pulls/\(item.iid)/merge",
                    method: "PUT",
                    body: try JSONSerialization.data(withJSONObject: mergeBody)
                )
                if response.merged == true {
                    logs.append("PR 合并成功: \(item.sourceBranch) -> \(item.targetBranch)")
                    return logs
                }
                let msg = response.message ?? "GitHub 未确认合并"
                logs.append("第 \(attempt) 次合并未完成: \(msg)")
            } catch {
                logs.append("第 \(attempt) 次合并失败: \(error.localizedDescription)")
                if attempt == totalAttempts {
                    throw WorkbenchError.message(logs.joined(separator: "\n"))
                }
            }
        }

        return logs
    }

    func closeMergeRequest(context: MergeRequestContext, item: MergeRequestItem) async throws {
        guard let slug = item.repoSlug ?? Self.parseRepoSlug(from: context.projects.first(where: { $0.path == item.projectPath })?.remoteURL) else {
            throw WorkbenchError.message("无法解析 PR 所属的 GitHub owner/repo")
        }

        let token = Self.resolveToken(configuredToken: context.config.githubToken, host: context.config.githubHost)
        guard !token.isEmpty else {
            throw WorkbenchError.message("未检测到 GitHub 访问令牌")
        }

        let body = ["state": "closed"]
        let _: GitHubPullRequestResponse = try await request(
            host: context.config.githubHost,
            token: token,
            path: "/repos/\(slug)/pulls/\(item.iid)",
            method: "PATCH",
            body: try JSONSerialization.data(withJSONObject: body)
        )
    }

    // MARK: - Private Helpers

    private static func buildDefaultMappings(config: MergeWorkflowConfig) -> [BranchMapping] {
        let target = config.githubDefaultTargetBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "main"
            : config.githubDefaultTargetBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            BranchMapping(
                source: "HEAD",
                target: target,
                protectedTarget: config.protectedTargets.contains(target)
            )
        ]
    }

    private func request<T: Decodable>(
        host: String = "",
        token: String,
        path: String,
        method: String,
        body: Data?
    ) async throws -> T {
        let baseURL = Self.apiBaseURL(from: host)
        guard let url = URL(string: baseURL + path) else {
            throw WorkbenchError.message("GitHub API 路径无效: \(baseURL)\(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkbenchError.message("GitHub 响应无效")
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let text = String(decoding: data, as: UTF8.self)
            throw WorkbenchError.message("GitHub HTTP \(httpResponse.statusCode): \(text)")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw WorkbenchError.message("解析 GitHub 响应失败: \(error.localizedDescription)")
        }
    }

    private func makeApprovalEntries(
        reviews: [GitHubReviewResponse],
        currentUsername: String,
        authorUsername: String,
        approvedByMe: Bool
    ) -> [ApprovalEntry] {
        var latestByUser: [String: String] = [:]
        for review in reviews {
            if let login = review.user?.login {
                latestByUser[login] = review.state.uppercased()
            }
        }

        var entries: [ApprovalEntry] = latestByUser.map { login, state in
            let approved = state == "APPROVED"
            let label = approved ? "已批准 (APPROVED)" : state
            return ApprovalEntry(reviewer: "@\(login)", detail: label, approved: approved)
        }
        .sorted { $0.reviewer < $1.reviewer }

        if !approvedByMe && authorUsername != currentUsername && !currentUsername.isEmpty && currentUsername != "me" {
            entries.insert(
                ApprovalEntry(reviewer: "我", detail: "@\(currentUsername) 尚未评审", approved: false),
                at: 0
            )
        }

        if entries.isEmpty {
            entries = [ApprovalEntry(reviewer: "暂无评审", detail: "当前还没有 Review 记录", approved: false)]
        }

        return entries
    }

    private func prSubtitle(from pr: GitHubPullRequestResponse) -> String {
        let trimmed = pr.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        return "\(pr.head.ref) -> \(pr.base.ref)"
    }

    private func mapPipelineState(_ checks: GitHubCheckRunsResponse?) -> PipelineState {
        guard let runs = checks?.check_runs, !runs.isEmpty else {
            return .none
        }
        if runs.contains(where: {
            let conclusion = ($0.conclusion ?? "").lowercased()
            return conclusion == "failure" || conclusion == "cancelled" || conclusion == "timed_out"
        }) {
            return .failed
        }
        if runs.contains(where: { $0.status.lowercased() != "completed" }) {
            return .pending
        }
        if runs.allSatisfy({
            let conclusion = ($0.conclusion ?? "").lowercased()
            return conclusion == "success" || conclusion == "neutral" || conclusion == "skipped"
        }) {
            return .passed
        }
        return .none
    }

    private func mapPRStatus(_ pr: GitHubPullRequestResponse, pipeline: PipelineState) -> MergeRequestStatus {
        if pr.merged_at != nil {
            return .merged
        }
        if pr.state.lowercased() == "closed" {
            return .closed
        }
        if pr.draft == true {
            return .draft
        }
        let state = (pr.mergeable_state ?? "").lowercased()
        if pr.mergeable == false || state == "dirty" || state == "blocked" {
            return .blocked
        }
        if pipeline == .passed || state == "clean" {
            return .ready
        }
        return .open
    }
}
