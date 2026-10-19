import SwiftUI
import AppKit

struct WorktreeSweeperSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var appModel = appModel

        VStack(spacing: 0) {
            headerBar
            Divider()

            summaryBanner
            Divider()

            filterBar
            Divider()

            if appModel.isSweeperAnalyzing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在全盘分析工作树合并状态与磁盘占用...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appModel.sweeperItems.isEmpty {
                ContentUnavailableView("当前项目无工作树", systemImage: "folder.badge.questionmark")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                sweeperTable
            }

            Divider()
            footerBar
        }
        .frame(minWidth: 780, idealWidth: 840, minHeight: 520, idealHeight: 580)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.red)

            Text("工作树空间智能回收站")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            if let project = appModel.currentWorktreeProject {
                Text("当前仓库: \(project.displayName) (\(appModel.currentProjectWorktreeCount) 个工作树)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Summary Banner

    private var summaryBanner: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text("总工作树")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Text("\(appModel.sweeperItems.count) 个")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("全部合入 (4/4)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Text("\(appModel.sweeperFullyMergedCount) 个")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("部分合入")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Text("\(appModel.sweeperPartiallyMergedCount) 个")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("建议安全回收")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Text("\(appModel.sweeperRecommendedCount) 个")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("建议释放磁盘")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Text(appModel.sweeperRecommendedSpaceFormatted)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.green)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(Color.green)
                        .font(.system(size: 11))
                    Text("判定基线：master / stage / test / uat；已自动排除主仓库与未提交改动")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.green.opacity(0.06))
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker("筛选分类", selection: sweeperCategoryBinding) {
                ForEach(SweeperCategoryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 300)

            Spacer()

            Button("⚡ 智能选择建议项") {
                appModel.selectSmartSweeper()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.accentColor)

            Text("|")
                .foregroundStyle(.tertiary)
                .font(.system(size: 10))

            Button("清空勾选") {
                appModel.clearSweeperSelection()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
    }

    // MARK: - Table

    private var sweeperTable: some View {
        Table(appModel.filteredSweeperItems) {
            TableColumn("选择") { item in
                if item.isProtected {
                    Image(systemName: "xmark.shield.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .help("受系统保护：主仓库或存在未提交修改")
                } else {
                    Toggle("", isOn: sweeperSelectionBinding(for: item.id))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                }
            }
            .width(36)

            TableColumn("分支 & 功能描述") { item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.worktree.branch)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(item.isProtected ? .secondary : .primary)

                        if item.worktree.kind == .mainRepo {
                            StatusPill(title: "主仓库 (基准)", tint: .blue, systemImage: "house.fill")
                        }
                    }

                    if !item.worktree.summary.isEmpty && item.worktree.summary != "主仓库" && item.worktree.summary != "未填写功能描述" {
                        Text(item.worktree.summary)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .width(min: 240, ideal: 300)

            TableColumn("工作区") { item in
                StatusPill(
                    title: item.worktree.isDirty ? "未提交改动" : "干净",
                    tint: item.worktree.isDirty ? .red : .green,
                    systemImage: item.worktree.isDirty ? "exclamationmark.circle.fill" : "checkmark"
                )
            }
            .width(min: 85, ideal: 95)

            TableColumn("流程合入 (master / stage / test / uat)") { item in
                mergeTargetLights(item)
            }
            .width(min: 235, ideal: 255)

            TableColumn("分析状态") { item in
                sweeperStatusPill(item)
            }
            .width(min: 120, ideal: 140)

            TableColumn("最后更新") { item in
                Text(item.worktree.updatedAt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 95)

            TableColumn("占用空间") { item in
                Text(item.diskUsageFormatted)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(item.isRecommended ? Color.green : Color.secondary)
            }
            .width(min: 75, ideal: 85)
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                Label("删除物理工作树目录 (释放空间)", systemImage: "checkmark.square.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)

                Toggle("同步删除本地 Git 分支", isOn: deleteLocalBranchBinding)
                    .font(.system(size: 11))

                Toggle("同步清理远端分支 (谨慎)", isOn: deleteRemoteBranchBinding)
                    .font(.system(size: 11))
            }

            Divider().opacity(0.4)

            HStack {
                if appModel.sweeperOperation.isRunning {
                    HStack(spacing: 6) {
                        ProgressView(value: appModel.sweeperOperation.fractionCompleted)
                            .frame(width: 120)
                        Text(appModel.sweeperOperation.detail)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                } else if let success = appModel.sweeperOperation.successMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                        Text(success)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.green)
                    }
                } else {
                    Text("清理后将自动执行 git worktree prune 进行元数据同步更新")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button("关闭") {
                    dismiss()
                }
                .controlSize(.regular)

                Button(role: .destructive) {
                    Task {
                        await appModel.executeSweeperPurge()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 11))
                        Text("一键回收选中项 (\(appModel.sweeperSelectedCount) 个 · 释放 \(appModel.sweeperSelectedSpaceFormatted))")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.red)
                .disabled(appModel.sweeperSelectedCount == 0 || appModel.sweeperOperation.isRunning)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sweeperStatusPill(_ item: WorktreeSweeperItem) -> some View {
        switch item.statusType {
        case .mainRepo:
            StatusPill(title: item.statusTitle, tint: .gray)
        case .dirty:
            StatusPill(title: item.statusTitle, tint: .red, systemImage: "exclamationmark.triangle.fill")
        case .fullyMerged:
            StatusPill(title: item.statusTitle, tint: .green, systemImage: "checkmark.circle.fill")
        case .partiallyMerged(let count):
            StatusPill(title: item.statusTitle, tint: count >= 2 ? .blue : .orange, systemImage: "circle.lefthalf.filled")
        case .remoteDeleted:
            StatusPill(title: item.statusTitle, tint: .purple, systemImage: "arrow.triangle.branch")
        case .stale:
            StatusPill(title: item.statusTitle, tint: .orange, systemImage: "clock")
        case .active:
            StatusPill(title: item.statusTitle, tint: .blue, systemImage: "pencil")
        }
    }

    /// 4 个亮点指示灯：master / stage / test / uat
    private func mergeTargetLights(_ item: WorktreeSweeperItem) -> some View {
        HStack(spacing: 6) {
            ForEach(item.mergeTargets) { target in
                let on = item.mergeStatus[target] == true

                HStack(spacing: 4) {
                    Circle()
                        .fill(on ? Color.green : Color.secondary.opacity(0.22))
                        .frame(width: 7, height: 7)

                    Text(target.rawValue)
                        .font(.system(size: 10.5, weight: on ? .semibold : .regular, design: .monospaced))
                        .foregroundStyle(on ? Color.primary : Color.secondary.opacity(0.7))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(on ? Color.green.opacity(0.12) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(on ? Color.green.opacity(0.3) : Color.secondary.opacity(0.12), lineWidth: 0.5)
                )
                .help("\(target.rawValue): \(on ? "已合入" : "未合入")")
            }

            if item.isFullyMerged {
                Text("全亮")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color.green)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    private func sweeperSelectionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { appModel.selectedSweeperIDs.contains(id) },
            set: { _ in appModel.toggleSweeperSelection(id: id) }
        )
    }

    private var sweeperCategoryBinding: Binding<SweeperCategoryFilter> {
        Binding(
            get: { appModel.selectedSweeperCategory },
            set: { appModel.selectedSweeperCategory = $0 }
        )
    }

    private var deleteLocalBranchBinding: Binding<Bool> {
        Binding(
            get: { appModel.sweeperDeleteLocalBranch },
            set: { appModel.sweeperDeleteLocalBranch = $0 }
        )
    }

    private var deleteRemoteBranchBinding: Binding<Bool> {
        Binding(
            get: { appModel.sweeperDeleteRemoteBranch },
            set: { appModel.sweeperDeleteRemoteBranch = $0 }
        )
    }
}
