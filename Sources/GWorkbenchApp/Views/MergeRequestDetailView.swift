import SwiftUI
import AppKit

struct MergeRequestDetailView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if let mr = appModel.selectedMergeRequest {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(mr)

                        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                            DetailLabelRow(title: "项目", value: mr.project)
                            DetailLabelRow(title: "源分支", value: mr.sourceBranch)
                            DetailLabelRow(title: "目标分支", value: mr.targetBranch)
                            DetailLabelRow(title: "作者", value: mr.author)
                            DetailLabelRow(title: "创建人账号", value: "@\(mr.authorUsername)")
                            DetailLabelRow(title: "流水线", value: mr.pipeline.rawValue)
                            DetailLabelRow(title: "更新时间", value: mr.updatedAt)
                        }

                        actionSection

                        SectionCard(title: "审批状态") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    StatusPill(title: "审批进度 \(mr.approvalProgress)", tint: mr.approvedByMe ? .green : .orange)
                                    if mr.protectedTarget {
                                        StatusPill(title: "保护目标分支", tint: .red)
                                    }
                                }
                                ForEach(mr.approvals) { approval in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: approval.approved ? "checkmark.circle.fill" : "clock")
                                            .foregroundStyle(approval.approved ? .green : .orange)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(approval.reviewer)
                                                .font(.subheadline.weight(.medium))
                                            Text(approval.detail)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }

                        SectionCard(title: "最近活动") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(mr.activity) { activity in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(activity.actor)
                                            .font(.subheadline.weight(.medium))
                                        Text(activity.summary)
                                            .font(.subheadline)
                                        Text(activity.relativeTime)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        SectionCard(title: "执行状态") {
                            InlineOperationView(state: appModel.mrOperation)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView("未选择合并请求", systemImage: "arrow.triangle.merge")
            }
        }
    }

    private func header(_ mr: MergeRequestItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("合并请求 · \(mr.status.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(mr.iid) · \(mr.title)")
                .font(.largeTitle.weight(.semibold))
            Text(mr.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                StatusPill(title: "审批 \(mr.approvalProgress)", tint: mr.approvedByMe ? .green : .orange)
                StatusPill(title: mr.pipeline.rawValue, tint: pipelineTint(mr.pipeline))
                if mr.protectedTarget {
                    StatusPill(title: "保护目标分支", tint: .red)
                }
                ForEach(mr.labels, id: \.self) { label in
                    StatusPill(title: label, tint: .gray)
                }
            }
        }
    }

    private var actionSection: some View {
        SectionCard(title: "快捷操作") {
            HStack {
                Button("审批并合并") {
                    Task {
                        await appModel.approveAndMergeSelectedMR()
                    }
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(appModel.mrOperation.isRunning)
                Button("关闭 MR", role: .destructive) {
                    Task {
                        await appModel.closeSelectedMR()
                    }
                }
                .disabled(appModel.mrOperation.isRunning)
                Button("刷新状态") {
                    Task {
                        await appModel.refreshMergeRequests()
                    }
                }
                Button("打开 GitLab") {
                    if let url = URL(string: appModel.selectedMergeRequest?.webURL ?? "") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    private func pipelineTint(_ state: PipelineState) -> Color {
        switch state {
        case .passed:
            return .green
        case .pending:
            return .orange
        case .failed:
            return .red
        case .none:
            return .gray
        }
    }
}
