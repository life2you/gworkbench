import SwiftUI

struct MergeRequestDetailView: View {
    @Environment(AppModel.self) private var appModel
    @State private var copiedLink: Bool = false

    var body: some View {
        Group {
            if let mr = appModel.selectedMergeRequest {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        InspectorHeaderView(
                            title: "\(mr.iidLabel) · \(mr.title)",
                            subtitleItems: ["\(mr.sourceBranch) → \(mr.targetBranch)"],
                            trailingPill: StatusPill(
                                title: ciBadgeTitle(mr.pipeline),
                                tint: pipelineTint(mr.pipeline)
                            )
                        )

                        reviewSummaryCard(mr)

                        actionsSection(mr)

                        if !mr.commits.isEmpty {
                            InspectorCard(title: "包含提交 (\(mr.commits.count))") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(mr.commits.prefix(5))) { commit in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(commit.message)
                                                .font(.system(size: 11.5, weight: .medium))
                                                .lineLimit(2)
                                            HStack(spacing: 6) {
                                                Text(commit.sha)
                                                    .font(.system(size: 10.5, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                Text("·")
                                                    .foregroundStyle(.tertiary)
                                                Text(commit.author)
                                                    .font(.system(size: 10.5))
                                                    .foregroundStyle(.secondary)
                                                Spacer()
                                                Text(commit.relativeTime)
                                                    .font(.system(size: 10.5))
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                        if commit.id != mr.commits.prefix(5).last?.id {
                                            Divider().opacity(0.4)
                                        }
                                    }
                                }
                            }
                        }

                        if appModel.mrOperation.isRunning || appModel.mrOperation.errorMessage != nil || appModel.mrOperation.successMessage != nil {
                            InspectorCard(title: "执行日志") {
                                InlineOperationView(state: appModel.mrOperation)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView("未选择合并请求", systemImage: "arrow.triangle.merge")
            }
        }
    }

    // MARK: - Review Details Card

    private func reviewSummaryCard(_ mr: MergeRequestItem) -> some View {
        InspectorCard(
            title: "评审详情",
            trailing: {
                if mr.protectedTarget {
                    StatusPill(title: "保护分支", tint: .orange)
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 7) {
                InspectorKeyValueRow(label: "作者", value: "@\(mr.authorUsername)")
                InspectorKeyValueRow(label: "更新时间", value: mr.updatedAt)
                InspectorKeyValueRow(label: "审批状态", value: mr.approvalProgress)
                if !mr.approvals.isEmpty {
                    Divider().opacity(0.4)
                    ForEach(mr.approvals.prefix(4)) { approval in
                        HStack(spacing: 6) {
                            Image(systemName: approval.approved ? "checkmark.circle.fill" : "clock")
                                .font(.system(size: 11))
                                .foregroundStyle(approval.approved ? Color.green : Color.orange)
                            Text(approval.reviewer)
                                .font(.system(size: 11, weight: .medium))
                            Spacer()
                            Text(approval.detail)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions Section

    private func actionsSection(_ mr: MergeRequestItem) -> some View {
        let short = mr.platform == .github ? "PR" : "MR"
        let isSelfGH = mr.platform == .github && mr.authorUsername == appModel.mergeRequestContext?.currentUsername

        return VStack(alignment: .leading, spacing: 8) {
            InspectorActionGroupLabel(title: "审阅与合并")

            Button {
                Task {
                    await appModel.approveAndMergeSelectedMR()
                }
            } label: {
                HStack(spacing: 6) {
                    if appModel.mrOperation.isRunning {
                        ProgressView().controlSize(.small)
                        Text("正在处理中...")
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text(mr.platform == .github ? "Merge \(short)" : "审批并合并 \(short)")
                    }
                }
            }
            .buttonStyle(InspectorActionButtonStyle(tone: .primary))
            .disabled(appModel.mrOperation.isRunning || !isActionable(mr))

            if isSelfGH {
                Text("注：GitHub 不允许 Approve 自己发起的 PR，将自动跳过审批步直接合并。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            if !mr.webURL.isEmpty {
                HStack(spacing: 8) {
                    Button {
                        appModel.openMRInBrowser(mr)
                    } label: {
                        Label("在浏览器中查看", systemImage: "globe")
                    }
                    .buttonStyle(InspectorActionButtonStyle(tone: .secondary))

                    Button {
                        appModel.copyMRWebURL(mr)
                        copiedLink = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copiedLink = false
                        }
                    } label: {
                        Label(copiedLink ? "已复制" : "复制链接", systemImage: copiedLink ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(InspectorActionButtonStyle(tone: .secondary))
                }
            }

            InspectorActionGroupLabel(title: "危险操作")

            Button(role: .destructive) {
                Task {
                    await appModel.closeSelectedMR()
                }
            } label: {
                Label("关闭 \(short)", systemImage: "xmark.circle")
            }
            .buttonStyle(InspectorActionButtonStyle(tone: .destructive))
            .disabled(appModel.mrOperation.isRunning || mr.status == .merged || mr.status == .closed)
        }
    }

    // MARK: - Helpers

    private func ciBadgeTitle(_ state: PipelineState) -> String {
        switch state {
        case .passed: return "CI 通过"
        case .pending: return "CI 运行中"
        case .failed: return "CI 失败"
        case .none: return "无 CI"
        }
    }

    private func pipelineTint(_ state: PipelineState) -> Color {
        switch state {
        case .passed: return .green
        case .pending: return .orange
        case .failed: return .red
        case .none: return .gray
        }
    }

    private func isActionable(_ mr: MergeRequestItem) -> Bool {
        mr.status != .merged && mr.status != .closed
    }
}
