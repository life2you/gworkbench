import SwiftUI
import AppKit

struct MergeDashboardDetailView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if let dashItem = appModel.selectedDashboardItem,
               let worktree = appModel.selectedDashboardWorktree {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        headerSection(item: worktree, dashItem: dashItem)

                        mergeStatusCard(dashItem: dashItem)

                        quickActionRow(item: worktree)

                        inspectorCard(title: "属性概览", systemImage: "info.circle") {
                            VStack(alignment: .leading, spacing: 8) {
                                inspectorRow(label: "项目", value: worktree.project)
                                inspectorRow(label: "物理路径", value: worktree.path, isMonospaced: true, canCopy: true)
                                if worktree.platform != .local {
                                    inspectorRow(label: "托管平台", value: worktree.platform.displayName)
                                }
                                inspectorRow(label: "上游分支", value: worktree.upstream, isMonospaced: true)
                                inspectorRow(label: "最新提交", value: worktree.head, isMonospaced: true)
                                inspectorRow(label: "磁盘占用", value: worktree.diskUsage, isMonospaced: true)
                                inspectorRow(label: "创建类型", value: worktree.createdDetail)
                            }
                        }

                        inspectorCard(title: "功能描述", systemImage: "note.text") {
                            VStack(alignment: .leading, spacing: 6) {
                                let summary = worktree.summary
                                if summary == "主仓库" {
                                    Text("主仓库为生产基准目录。")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                } else if summary == "未填写功能描述" || summary.isEmpty {
                                    Text("未填写功能描述")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                        .italic()
                                } else {
                                    Text(summary)
                                        .font(.system(size: 12))
                                        .textSelection(.enabled)
                                }
                            }
                        }

                        if !worktree.commits.isEmpty {
                            inspectorCard(title: "最近提交历史", systemImage: "clock.arrow.circlepath") {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(worktree.commits.prefix(5))) { commit in
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
                                        if commit.id != worktree.commits.prefix(5).last?.id {
                                            Divider()
                                                .opacity(0.5)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(dashItem.id)
            } else {
                ContentUnavailableView("选择工作树查看详情", systemImage: "chart.bar.xaxis", description: Text("在合入看板中点击某个工作树查看其合入详情和分支信息"))
            }
        }
    }

    // MARK: - Header

    private func headerSection(item: WorktreeItem, dashItem: MergeDashboardItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(item.project)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("/")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(item.kind.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(item.branch)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .textSelection(.enabled)

            HStack(spacing: 6) {
                StatusPill(
                    title: item.kind.rawValue,
                    tint: item.kind == .mainRepo ? .blue : .purple,
                    systemImage: item.kind == .mainRepo ? "house.fill" : "point.3.connected.trianglepath.dotted"
                )

                if item.platform != .local {
                    StatusPill(
                        title: item.platform.badgeText,
                        tint: item.platform.tintColor,
                        systemImage: item.platform.icon
                    )
                }

                StatusPill(
                    title: item.dirtySummary,
                    tint: item.isDirty ? .orange : .green,
                    systemImage: item.isDirty ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                    isMonospaced: true
                )

                StatusPill(
                    title: dashItem.summaryText,
                    tint: dashItem.isFullyMerged ? .green : (dashItem.isNotMerged ? .red : .orange),
                    systemImage: dashItem.isFullyMerged ? "checkmark.seal.fill" : "chart.bar.xaxis"
                )
            }
            .padding(.top, 2)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Merge Status Card

    private func mergeStatusCard(dashItem: MergeDashboardItem) -> some View {
        let targets = SweeperMergeTarget.ordered

        return inspectorCard(title: "主干合入状态", systemImage: "chart.bar.xaxis") {
            if dashItem.kind == .mainRepo {
                Text("主仓库为基准目录，所有主干分支默认视为已合入。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(targets) { target in
                        let merged = dashItem.mergeStatus[target] ?? false

                        HStack(spacing: 10) {
                            Image(systemName: merged ? "checkmark.circle.fill" : "xmark.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(merged ? .green : .red.opacity(0.6))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(target.rawValue)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                Text(merged
                                     ? "已合入 origin/\(target.rawValue)"
                                     : "尚未合入 origin/\(target.rawValue)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(merged ? "已合入" : "未合入")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(merged ? .green : .red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background((merged ? Color.green : Color.red).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }

                        if target.id != targets.last?.id {
                            Divider().opacity(0.4)
                        }
                    }

                    // 总结
                    Divider()
                    HStack {
                        Text("总计")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(dashItem.mergedCount) / \(dashItem.totalMergeTargets) 条基线已合入")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(dashItem.isFullyMerged ? .green : (dashItem.isNotMerged ? .red : .orange))
                    }
                }
            }
        }
    }

    // MARK: - Quick Actions

    private func quickActionRow(item: WorktreeItem) -> some View {
        HStack(spacing: 6) {
            Button {
                appModel.openWorktreeInIDE(item)
            } label: {
                Label(appModel.currentIDELabel, systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            } label: {
                Label("访达", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                appModel.openWorktreeInTerminal(item)
            } label: {
                Label("终端", systemImage: "terminal")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                appModel.copyWorktreePath(item)
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Reusable Components

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
}
