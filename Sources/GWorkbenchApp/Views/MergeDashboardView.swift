import SwiftUI
import AppKit

struct MergeDashboardView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        VStack(spacing: 0) {
            toolbarHeader
            Divider()

            if appModel.worktreeProjects.isEmpty {
                ContentUnavailableView("未检测到本地项目", systemImage: "folder.badge.questionmark")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appModel.isMergeDashboardAnalyzing && appModel.mergeDashboardItems.isEmpty {
                // 仅在首次进入且完全无数据时显示整屏居中加载
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("正在分析各分支对主干的合入状态...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("正在比对 master / stage / test / uat 的合入情况")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appModel.mergeDashboardItems.isEmpty {
                ContentUnavailableView("暂无数据", systemImage: "chart.bar.xaxis", description: Text("请选择一个项目后自动分析合入状态"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // 后台静默刷新时显示一条极细的顶部加载指示条，完全不打乱已有布局
                    if appModel.isMergeDashboardAnalyzing {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .controlSize(.mini)
                    }
                    summaryCards
                    Divider()
                    mergeMatrixTable
                }
            }

            Divider()
            dashboardStatusBar
        }
        .sheet(isPresented: $appModel.showingWorktreeSweeperSheet) {
            WorktreeSweeperSheetView()
        }
    }

    // MARK: - Toolbar Header

    private var toolbarHeader: some View {
        HStack(spacing: 10) {
            Picker("项目", selection: projectBinding) {
                ForEach(appModel.worktreeProjects) { project in
                    Text("\(project.platform == .github ? "🐙 " : (project.platform == .gitlab ? "🦊 " : ""))\(project.displayName)").tag(Optional(project.id))
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 150, maxWidth: 200)

            Divider()
                .frame(height: 18)
                .padding(.horizontal, 2)

            // 合入状态筛选
            Picker("筛选", selection: dashboardFilterBinding) {
                Text("全部").tag(DashboardFilter.all)
                Text("全部合入").tag(DashboardFilter.fullyMerged)
                Text("部分合入").tag(DashboardFilter.partiallyMerged)
                Text("未合入").tag(DashboardFilter.notMerged)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 280)

            Spacer()

            Button {
                Task {
                    await appModel.forceRefreshMergeDashboard()
                }
            } label: {
                if appModel.isMergeDashboardAnalyzing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                        Text("分析中")
                    }
                } else {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
            .help("重新分析所有工作树的合入状态")
            .disabled(appModel.isMergeDashboardAnalyzing)

            Button {
                appModel.openWorktreeSweeper()
            } label: {
                Label("空间清理", systemImage: "trash.circle")
            }
            .help("分析并一键回收已合入或休眠的陈旧工作树，释放磁盘空间")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        let worktreeItems = appModel.mergeDashboardItems.filter { $0.kind != .mainRepo }
        let total = worktreeItems.count

        return HStack(spacing: 12) {
            summaryCard(
                title: "工作树总数",
                count: total,
                icon: "point.3.connected.trianglepath.dotted",
                color: .blue
            )
            summaryCard(
                title: "全部合入",
                count: appModel.mergeDashboardFullyMergedCount,
                icon: "checkmark.circle.fill",
                color: .green
            )
            summaryCard(
                title: "部分合入",
                count: appModel.mergeDashboardPartiallyMergedCount,
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )
            summaryCard(
                title: "未合入",
                count: appModel.mergeDashboardNotMergedCount,
                icon: "xmark.circle.fill",
                color: .red
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }

    private func summaryCard(title: String, count: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Merge Matrix Table

    private var mergeMatrixTable: some View {
        let targets = SweeperMergeTarget.ordered
        let items = filteredDashboardItems

        return VStack(spacing: 0) {
            // 表头
            HStack(spacing: 0) {
                Text("分支")
                    .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)

                Text("功能描述")
                    .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)

                ForEach(targets) { target in
                    Text(target.rawValue)
                        .frame(width: 64)
                }

                Text("状态")
                    .frame(width: 85)

                Text("更新时间")
                    .frame(width: 90)
                    .padding(.trailing, 8)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 数据行
            if items.isEmpty {
                ContentUnavailableView("无匹配结果", systemImage: "line.3.horizontal.decrease.circle", description: Text("当前筛选条件下没有工作树"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            matrixRow(item: item, targets: targets)
                            if item.id != items.last?.id {
                                Divider().opacity(0.5)
                            }
                        }
                    }
                }
            }
        }
    }

    private func matrixRow(item: MergeDashboardItem, targets: [SweeperMergeTarget]) -> some View {
        let isMain = item.kind == .mainRepo
        let isSelected = appModel.selectedDashboardItemID == item.id
        let worktree = appModel.worktrees.first(where: { $0.id == item.id })
        let description = worktree?.summary ?? ""
        let hasDescription = !description.isEmpty && description != "主仓库" && description != "未填写功能描述"

        let rowBg: Color
        if isSelected {
            rowBg = Color.accentColor.opacity(0.12)
        } else if item.isFullyMerged && !isMain {
            rowBg = Color.green.opacity(0.03)
        } else if item.isNotMerged && !isMain {
            rowBg = Color.red.opacity(0.03)
        } else {
            rowBg = Color.clear
        }

        return HStack(spacing: 0) {
            // 分支名
            HStack(spacing: 5) {
                Image(systemName: isMain ? "shippingbox.fill" : "arrow.triangle.branch")
                    .font(.system(size: 11))
                    .foregroundStyle(isMain ? Color.blue : Color.purple)

                Text(item.branch)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if item.isDirty {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .help("有未提交的修改")
                }
            }
            .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)

            // 功能描述
            Text(hasDescription ? description : (isMain ? "主仓库" : "—"))
                .font(.system(size: 11))
                .foregroundStyle(hasDescription ? .primary : .tertiary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)

            // 每个主干分支的合入指示器
            ForEach(targets) { target in
                mergeIndicator(
                    target: target,
                    merged: item.mergeStatus[target] ?? false,
                    matchedBranch: item.matchedBranches[target],
                    isMain: isMain
                )
                .frame(width: 64)
            }

            // 状态摘要
            statusBadge(item: item)
                .frame(width: 85)

            // 更新时间
            Text(item.updatedAt)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 90, alignment: .trailing)
                .padding(.trailing, 8)
        }
        .padding(.vertical, 6)
        .background(rowBg)
        .contentShape(Rectangle())
        .onTapGesture {
            appModel.selectedDashboardItemID = item.id
        }
    }

    private func mergeIndicator(
        target: SweeperMergeTarget,
        merged: Bool,
        matchedBranch: String?,
        isMain: Bool
    ) -> some View {
        Group {
            if isMain {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .help("\(target.rawValue): 主仓库基准")
            } else if merged {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
                    .help("\(target.rawValue): 已合入 \(matchedBranch ?? target.rawValue)")
            } else {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.6))
                    .help("\(target.rawValue): 尚未合入")
            }
        }
    }

    private func statusBadge(item: MergeDashboardItem) -> some View {
        let color: Color
        if item.kind == .mainRepo {
            color = .blue
        } else if item.isFullyMerged {
            color = .green
        } else if item.isNotMerged {
            color = .red
        } else {
            color = .orange
        }

        return Text(item.summaryText)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - Status Bar

    private var dashboardStatusBar: some View {
        let total = appModel.mergeDashboardItems.filter { $0.kind != .mainRepo }.count
        let fullyMerged = appModel.mergeDashboardFullyMergedCount

        return HStack(spacing: 8) {
            if appModel.isMergeDashboardAnalyzing {
                ProgressView()
                    .controlSize(.mini)
                Text("正在分析...")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else if total > 0 {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("共 \(total) 个工作树 · \(fullyMerged) 个已全部合入主干 · 检测基线: master / stage / test / uat")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                Text("选择项目后自动分析")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if let project = appModel.currentWorktreeProject {
                Text(project.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(.bar)
    }

    // MARK: - Bindings & Filtering

    @State private var dashboardFilter: DashboardFilter = .all

    private var projectBinding: Binding<String?> {
        Binding(
            get: { appModel.selectedProjectID },
            set: { if let value = $0 { appModel.selectDashboardProject(value) } }
        )
    }

    private var dashboardFilterBinding: Binding<DashboardFilter> {
        Binding(
            get: { dashboardFilter },
            set: { dashboardFilter = $0 }
        )
    }

    private var filteredDashboardItems: [MergeDashboardItem] {
        switch dashboardFilter {
        case .all:
            return appModel.mergeDashboardItems
        case .fullyMerged:
            return appModel.mergeDashboardItems.filter { $0.isFullyMerged && $0.kind != .mainRepo }
        case .partiallyMerged:
            return appModel.mergeDashboardItems.filter { !$0.isFullyMerged && !$0.isNotMerged && $0.kind != .mainRepo }
        case .notMerged:
            return appModel.mergeDashboardItems.filter { $0.isNotMerged && $0.kind != .mainRepo }
        }
    }
}

enum DashboardFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case fullyMerged = "全部合入"
    case partiallyMerged = "部分合入"
    case notMerged = "未合入"

    var id: String { rawValue }
}
