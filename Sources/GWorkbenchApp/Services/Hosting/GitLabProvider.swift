import Foundation

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

private struct EmptyResponse: Decodable {}

private struct MergeResponse: Decodable {
    let state: String
}

final class GitLabProvider: HostingProvider {
    let gitCli: GitCliService

    init(gitCli: GitCliService = GitCliService()) {
        self.gitCli = gitCli
    }

    func loadMergeContext(
        config: MergeWorkflowConfig,
        localProjects: [LocalProject],
        branchMappings: [BranchMapping],
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> MergeRequestContext {
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
        let gitCli = self.gitCli

        // 使用 concurrentPerform 而非 withThrowingTaskGroup：任务内含阻塞式 git 子进程，
        // 放到协作线程池上可能占满线程并导致任务组永不完成。
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
                    gitLabProjectID: remoteByName[project.name],
                    branchMappings: branchMappings,
                    remoteBranches: remoteBranches,
                    localBranches: localBranches,
                    remoteURL: project.remoteURL,
                    platform: project.platform
                )
            )
        }

        let mergeProjects = collector.all.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }

        onProgress(.init(title: "完成", detail: "已加载 \(mergeProjects.count) 个合并项目", current: 4, total: 4))
        return MergeRequestContext(config: config, currentUsername: currentUserResponse.username, projects: mergeProjects)
    }

    func loadPendingMergeRequests(
        context: MergeRequestContext,
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

        let provider = self
        let items = try await withThrowingTaskGroup(of: MergeRequestItem.self) { group in
            for mr in mergeRequests {
                group.addTask {
                    async let approvalsRequest: GitLabApprovalResponse = provider.request(
                        host: context.config.host,
                        token: context.config.token,
                        path: "/projects/\(projectID)/merge_requests/\(mr.iid)/approvals",
                        method: "GET",
                        body: nil
                    )
                    async let commitsRequest: [GitLabMergeRequestCommitResponse] = provider.request(
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
                    let approvalEntries = provider.makeApprovalEntries(
                        approvedUsers: approvedUsers,
                        currentUsername: currentUsername,
                        approvedByMe: approvedByMe
                    )
                    let commitEntries = commitResponses.map { commit in
                        CommitEntry(
                            sha: commit.short_id ?? String(commit.id.prefix(8)),
                            message: commit.title,
                            author: commit.author_name,
                            relativeTime: DateFormatterUtils.relativeDateString(fromISO8601: commit.created_at)
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
                        subtitle: provider.mrSubtitle(from: mr),
                        sourceBranch: mr.source_branch,
                        targetBranch: mr.target_branch,
                        author: mr.author.name,
                        authorUsername: mr.author.username,
                        updatedAt: DateFormatterUtils.relativeDateString(fromISO8601: mr.updated_at),
                        approvalProgress: approvedByMe ? "已审批" : "待审批",
                        approvedByMe: approvedByMe,
                        status: provider.mapMRStatus(mr),
                        pipeline: provider.mapPipelineState(mr.head_pipeline?.status),
                        labels: mr.labels ?? [],
                        protectedTarget: protectedTargets.contains(mr.target_branch),
                        approvals: approvalEntries,
                        activity: [
                            ActivityEntry(actor: mr.author.name, summary: "创建了这条 MR", relativeTime: DateFormatterUtils.relativeDateString(fromISO8601: mr.updated_at))
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

    func approveAndMerge(
        context: MergeRequestContext,
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

    func closeMergeRequest(context: MergeRequestContext, item: MergeRequestItem) async throws {
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
        context: MergeRequestContext,
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
            updatedAt: DateFormatterUtils.relativeDateString(fromISO8601: mr.updated_at),
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

    fileprivate func request<T: Decodable>(
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

        if allowEmptyResponse, data.isEmpty || T.self == EmptyResponse.self {
            if let empty = EmptyResponse() as? T {
                return empty
            }
        }

        let jsonDecoder = JSONDecoder()
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            if allowEmptyResponse, data.isEmpty {
                if let empty = EmptyResponse() as? T {
                    return empty
                }
            }
            throw WorkbenchError.message("解析 GitLab 响应失败: \(error.localizedDescription)")
        }
    }

    fileprivate func makeApprovalEntries(
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

    fileprivate func mrSubtitle(from mr: GitLabMergeRequestResponse) -> String {
        let description = mr.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let description, !description.isEmpty {
            return description
        }
        return "\(mr.source_branch) -> \(mr.target_branch)"
    }

    fileprivate func mapMRStatus(_ mr: GitLabMergeRequestResponse) -> MergeRequestStatus {
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

    fileprivate func mapPipelineState(_ status: String?) -> PipelineState {
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
}
