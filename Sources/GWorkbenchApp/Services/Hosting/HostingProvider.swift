import Foundation

protocol HostingProvider: Sendable {
    func loadMergeContext(
        config: MergeWorkflowConfig,
        localProjects: [LocalProject],
        branchMappings: [BranchMapping],
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> MergeRequestContext

    func loadPendingMergeRequests(
        context: MergeRequestContext,
        project: MergeProject,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [MergeRequestItem]

    func createMergeRequest(
        context: MergeRequestContext,
        project: MergeProject,
        sourceBranch: String,
        targetBranch: String
    ) async throws -> MergeRequestItem

    func approveAndMerge(
        context: MergeRequestContext,
        item: MergeRequestItem,
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String]

    func closeMergeRequest(
        context: MergeRequestContext,
        item: MergeRequestItem
    ) async throws

    func createBatchMergeRequests(
        context: MergeRequestContext,
        project: MergeProject,
        mappings: [BranchMapping],
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String]

    func approveAndMergeBatch(
        context: MergeRequestContext,
        items: [MergeRequestItem],
        onProgress: @escaping @Sendable (OperationProgress) -> Void
    ) async throws -> [String]
}

extension HostingProvider {
    func createBatchMergeRequests(
        context: MergeRequestContext,
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
        context: MergeRequestContext,
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
}
