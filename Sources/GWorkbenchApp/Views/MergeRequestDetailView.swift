import SwiftUI
import AppKit

struct MergeRequestDetailView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if let mr = appModel.selectedMergeRequest {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        headerSection(mr)

                        quickActionRow(mr)

                        mainActionCard(mr)

                        inspectorCard(title: "属性概览", systemImage: "info.circle") {
                            VStack(alignment: .leading, spacing: 8) {
                                inspectorRow(label: "所属项目", value: mr.project)
                                inspectorRow(label: "创建作者", value: "\(mr.author) (@\(mr.authorUsername))")
                                inspectorRow(label: "源分支", value: mr.sourceBranch, isMonospaced: true, canCopy: true)
                                inspectorRow(label: "目标分支", value: mr.targetBranch, isMonospaced: true, canCopy: true)
                                inspectorRow(label: "CI 流水线", value: mr.pipeline.rawValue)
                                inspectorRow(label: "更新时间", value: mr.updatedAt)
                            }
                        }

                        inspectorCard(title: "审批名单 (\(mr.approvalProgress))", systemImage: "person.2.badge.gearshape") {
                            VStack(alignment: .leading, spacing: 9) {
                                if mr.approvals.isEmpty {
                                    Text("暂无详细审批人名单记录。")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(mr.approvals) { approval in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: approval.approved ? "checkmark.circle.fill" : "clock")
                                                .font(.system(size: 12))
                                                .foregroundStyle(approval.approved ? Color.green : Color.orange)
                                                .padding(.top, 1)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(approval.reviewer)
                                                    .font(.system(size: 11.5, weight: .medium))
                                                Text(approval.detail)
                                                    .font(.system(size: 10.5))
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            StatusPill(
                                                title: approval.approved ? "已审批" : "待审批",
                                                tint: approval.approved ? .green : .orange
                                            )
                                        }
                                        if approval.id != mr.approvals.last?.id {
                                            Divider().opacity(0.4)
                                        }
                                    }
                                }
                            }
                        }

                        if !mr.commits.isEmpty {
                            inspectorCard(title: "包含提交 (\(mr.commits.count))", systemImage: "shippingbox") {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(mr.commits.prefix(5))) { commit in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(commit.message)
                                                .font(.system(size: 12, weight: .medium))
                                                .lineLimit(2)
                                            HStack(spacing: 6) {
                                                Text(commit.sha)
                                                    .font(.system(size: 10.5, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                Text("•")
                                                    .font(.system(size: 9))
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

                        if !mr.activity.isEmpty {
                            inspectorCard(title: "最近活动", systemImage: "clock.arrow.circlepath") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(mr.activity) { act in
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(act.actor)
                                                    .font(.system(size: 11.5, weight: .semibold))
                                                Spacer()
                                                Text(act.relativeTime)
                                                    .font(.system(size: 10.5))
                                                    .foregroundStyle(.secondary)
                                            }
                                            Text(act.summary)
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                        }
                                        if act.id != mr.activity.last?.id {
                                            Divider().opacity(0.4)
                                        }
                                    }
                                }
                            }
                        }

                        if appModel.mrOperation.isRunning || appModel.mrOperation.errorMessage != nil || appModel.mrOperation.successMessage != nil {
                            inspectorCard(title: "执行日志", systemImage: "terminal") {
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

    // MARK: - Header Section

    private func headerSection(_ mr: MergeRequestItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("合并请求")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("/")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(mr.status.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text("\(mr.iidLabel) · \(mr.title)")
                .font(.system(size: 16, weight: .semibold))
                .textSelection(.enabled)

            HStack(spacing: 6) {
                Text(mr.sourceBranch)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(mr.targetBranch)
                    .font(.system(size: 11.5, design: .monospaced).weight(.medium))
                    .foregroundStyle(mr.protectedTarget ? Color.orange : Color.primary)
            }

            HStack(spacing: 6) {
                StatusPill(
                    title: "审批 \(mr.approvalProgress)",
                    tint: mr.approvedByMe ? .green : .orange,
                    systemImage: mr.approvedByMe ? "checkmark.circle.fill" : "clock"
                )

                StatusPill(
                    title: mr.pipeline.rawValue,
                    tint: pipelineTint(mr.pipeline),
                    systemImage: pipelineSystemImage(mr.pipeline)
                )

                if mr.protectedTarget {
                    StatusPill(title: "保护分支", tint: .orange, systemImage: "lock.fill")
                }

                ForEach(mr.labels, id: \.self) { label in
                    StatusPill(title: label, tint: .gray)
                }
            }
            .padding(.top, 2)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Quick Action Row

    private func quickActionRow(_ mr: MergeRequestItem) -> some View {
        HStack(spacing: 6) {
            Button {
                appModel.openMRInBrowser(mr)
            } label: {
                Label("在 GitLab 打开", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                appModel.copyMRWebURL(mr)
            } label: {
                Label("复制链接", systemImage: "link")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                appModel.copyMRSourceBranch(mr)
            } label: {
                Label("复制分支", systemImage: "arrow.triangle.branch")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                Task {
                    await appModel.refreshMergeRequests()
                }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Main Action Card

    private func mainActionCard(_ mr: MergeRequestItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("审批并通过合并此 MR")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 28)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.green)
            .disabled(appModel.mrOperation.isRunning || !isActionable(mr))

            HStack {
                Spacer()
                Button("关闭此 MR", role: .destructive) {
                    Task {
                        await appModel.closeSelectedMR()
                    }
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
                .disabled(appModel.mrOperation.isRunning || mr.status == .merged || mr.status == .closed)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
        )
    }

    // MARK: - Inspector Helpers

    private func inspectorRow(label: String, value: String, isMonospaced: Bool = false, canCopy: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)

            Text(value)
                .font(isMonospaced ? .system(size: 11.5, design: .monospaced) : .system(size: 11.5))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if canCopy {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("复制")
            }
        }
    }

    private func inspectorCard<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            content()
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
        )
    }

    private func isActionable(_ mr: MergeRequestItem) -> Bool {
        [.open, .ready, .blocked, .draft].contains(mr.status)
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

    private func pipelineSystemImage(_ state: PipelineState) -> String {
        switch state {
        case .passed:
            return "checkmark.circle.fill"
        case .pending:
            return "hourglass"
        case .failed:
            return "xmark.circle.fill"
        case .none:
            return "minus.circle"
        }
    }
}
