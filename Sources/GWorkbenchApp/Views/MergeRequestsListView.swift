import SwiftUI
import AppKit

struct MergeRequestsListView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        VStack(spacing: 0) {
            toolbarHeader
            Divider()

            if appModel.mergeProjects.isEmpty {
                ContentUnavailableView("未检测到合并项目", systemImage: "arrow.triangle.merge")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appModel.sortedMergeRequests.isEmpty {
                ContentUnavailableView("暂无匹配\(appModel.requestSectionTitle)", systemImage: "tray", description: Text("可尝试清空搜索过滤词或在上方切换状态筛选"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if !appModel.visibleOpenMergeRequests.isEmpty {
                    batchSelectionBar
                }

                if appModel.mrOperation.isRunning || appModel.mrOperation.errorMessage != nil || appModel.mrOperation.successMessage != nil {
                    InlineOperationView(state: appModel.mrOperation)
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(Color.secondary.opacity(0.12)),
                            alignment: .bottom
                        )
                }

                mrTable
            }

            Divider()
            statusBar
        }
        .sheet(isPresented: mergeSheetBinding) {
            CreateMRSheetView()
        }
        .sheet(isPresented: batchMergeSheetBinding) {
            BatchCreateMRSheetView()
        }
    }

    // MARK: - Toolbar Header

    private var toolbarHeader: some View {
        HStack(spacing: 10) {
            Picker("状态筛选", selection: mergeFilterBinding) {
                ForEach(MergeRequestFilter.allCases) { filter in
                    let count = appModel.mergeCountByFilter[filter, default: 0]
                    Text(count > 0 && filter == .open ? "\(filter.title) (\(count))" : filter.title)
                        .tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("搜索 \(appModel.requestShortLabel) 编号、标题、分支...", text: mergeSearchBinding)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !appModel.mergeRequestSearchText.isEmpty {
                    Button {
                        appModel.mergeRequestSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .frame(minWidth: 170, maxWidth: 250)

            if appModel.activePlatform != .github {
                Button {
                    appModel.prepareBatchMergeRequests()
                } label: {
                    Label("批量创建", systemImage: "square.grid.3x1.folder.badge.plus")
                }
                .help("按配置环境分支映射批量创建 MR")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.25))
    }

    // MARK: - Batch Selection Bar

    private var batchSelectionBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.badge.questionmark")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                Text("已勾选 \(appModel.selectedBatchApproveMRs.count) 条合并请求")
                    .font(.system(size: 11.5, weight: .semibold))
            }

            Text("•")
                .foregroundStyle(.tertiary)
            Text("一键评审通过并批量合入目标分支")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            Button("全选当前可合并") {
                appModel.selectAllVisibleOpenMergeRequests()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(Color.accentColor)
            .disabled(appModel.visibleOpenMergeRequests.isEmpty || appModel.areAllVisibleOpenMergeRequestsSelected || appModel.mrOperation.isRunning)

            Text("|")
                .foregroundStyle(.tertiary)
                .font(.system(size: 10))

            Button("清空选择") {
                appModel.clearBatchApproveSelection()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .disabled(appModel.selectedBatchApproveMRIDs.isEmpty || appModel.mrOperation.isRunning)

            Button {
                Task {
                    await appModel.approveAndMergeSelectedBatchMRs()
                }
            } label: {
                HStack(spacing: 4) {
                    if appModel.mrOperation.isRunning {
                        ProgressView().controlSize(.small)
                        Text("审批中...")
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("审批并合并已选 (\(appModel.selectedBatchApproveMRs.count))")
                    }
                }
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .disabled(!appModel.canBatchApproveSelectedMRs || appModel.mrOperation.isRunning)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.08))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.accentColor.opacity(0.18)),
            alignment: .bottom
        )
    }

    // MARK: - MR Table

    private var mrTable: some View {
        Table(appModel.sortedMergeRequests, selection: selectedMRBinding, sortOrder: mrSortOrderBinding) {
            TableColumn("") { item in
                if isBatchSelectable(item) {
                    Toggle("", isOn: batchSelectionBinding(for: item.id))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .disabled(appModel.mrOperation.isRunning)
                }
            }
            .width(28)

            TableColumn("单号", value: \.iid) { item in
                Text(item.iidLabel)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .width(56)

            TableColumn("标题与分支流向", value: \.title) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(item.sourceBranch)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8.5))
                        Text(item.targetBranch)
                        if item.protectedTarget {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.orange)
                        }
                    }
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                .padding(.vertical, 2)
            }
            .width(min: 250, ideal: 340)

            TableColumn("作者", value: \.authorUsername) { item in
                Text("@\(item.authorUsername)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 80, ideal: 105)

            TableColumn("CI 状态", value: \.pipeline.rawValue) { item in
                pipelinePill(item.pipeline)
            }
            .width(min: 75, ideal: 88, max: 100)

            TableColumn("审批进度", value: \.approvalProgress) { item in
                Text(item.approvalProgress)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 85, ideal: 100, max: 120)

            TableColumn("状态", value: \.status.rawValue) { item in
                statusPill(item)
            }
            .width(min: 75, ideal: 88, max: 105)

            TableColumn("操作") { item in
                HStack(spacing: 8) {
                    Button {
                        appModel.copyMRWebURL(item)
                    } label: {
                        Image(systemName: "link")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .help("复制此 \(appModel.requestShortLabel) 链接 (\(item.iidLabel))")

                    Button {
                        appModel.openMRInBrowser(item)
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("在 \(item.platform == .github ? "GitHub" : "GitLab") 中打开 (\(item.iidLabel))")
                }
            }
            .width(55)
        }
        .contextMenu(forSelectionType: MergeRequestItem.ID.self) { selection in
            if let id = selection.first, let item = appModel.mergeRequests.first(where: { $0.id == id }) {
                mrContextMenu(for: item)
            }
        } primaryAction: { selection in
            if let id = selection.first, let item = appModel.mergeRequests.first(where: { $0.id == id }) {
                appModel.openMRInBrowser(item)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func mrContextMenu(for item: MergeRequestItem) -> some View {
        Button {
            appModel.openMRInBrowser(item)
        } label: {
            Label("在 \(item.platform == .github ? "GitHub" : "GitLab") 中打开", systemImage: "arrow.up.forward.app")
        }

        Button {
            appModel.copyMRWebURL(item)
        } label: {
            Label("复制 \(item.platform == .github ? "PR" : "MR") 链接", systemImage: "link")
        }

        Divider()

        Button {
            appModel.copyMRSourceBranch(item)
        } label: {
            Label("复制源分支名 (\(item.sourceBranch))", systemImage: "arrow.triangle.branch")
        }

        Button {
            appModel.copyMRTargetBranch(item)
        } label: {
            Label("复制目标分支名 (\(item.targetBranch))", systemImage: "arrow.right.to.line")
        }

        Divider()

        if isBatchSelectable(item) {
            Button {
                appModel.selectedMergeRequestID = item.id
                Task {
                    await appModel.approveAndMergeSelectedMR()
                }
            } label: {
                Label("审批并合并此 \(item.platform == .github ? "PR" : "MR")", systemImage: "checkmark.circle")
            }
            .disabled(appModel.mrOperation.isRunning)
        }

        Button(role: .destructive) {
            appModel.selectedMergeRequestID = item.id
            Task {
                await appModel.closeSelectedMR()
            }
        } label: {
            Label("关闭此 \(item.platform == .github ? "PR" : "MR")", systemImage: "xmark.circle")
        }
        .disabled(appModel.mrOperation.isRunning)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text(appModel.activePlatform == .github
                     ? "GitHub (\(GitHubProvider.cliHostname(from: appModel.activeWorkspace?.host ?? appModel.appConfig?.githubHost ?? "") ?? "api.github.com"))"
                     : ((appModel.activeWorkspace?.host.trimmedNonEmpty ?? appModel.appConfig?.gitlabHost.trimmedNonEmpty) ?? "GitLab 未配置"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text("•")
                .foregroundStyle(.tertiary)

            HStack(spacing: 4) {
                Text("当前列表:")
                    .foregroundStyle(.tertiary)
                Text("\(appModel.filteredMergeRequests.count) 条")
                    .font(.system(size: 10.5, weight: .medium))
            }

            Text("•")
                .foregroundStyle(.tertiary)

            HStack(spacing: 4) {
                Text("待我审批:")
                    .foregroundStyle(.tertiary)
                Text("\(appModel.mergeCountByFilter[.awaitingMine, default: 0]) 个")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(appModel.mergeCountByFilter[.awaitingMine, default: 0] > 0 ? Color.orange : Color.secondary)
            }

            Text("•")
                .foregroundStyle(.tertiary)

            HStack(spacing: 4) {
                Text("待处理:")
                    .foregroundStyle(.tertiary)
                Text("\(appModel.mergeCountByFilter[.open, default: 0]) 个")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.green)
            }

            Spacer()

            Text("GWorkbench • \(appModel.requestShortLabel) Queue")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Helper Views & Bindings

    private var mergeFilterBinding: Binding<MergeRequestFilter> {
        Binding(
            get: { appModel.selectedMergeFilter },
            set: { appModel.selectMergeFilter($0) }
        )
    }

    private func statusPill(_ item: MergeRequestItem) -> some View {
        let tint: Color = switch item.status {
        case .ready: .green
        case .blocked: .red
        case .draft: .gray
        case .merged: .purple
        case .closed: .gray
        case .open: item.approvedByMe ? .green : .orange
        }
        let label: String = switch item.status {
        case .ready: "可合并"
        case .blocked: "有冲突"
        case .draft: "Draft"
        case .merged: "已合并"
        case .closed: "已关闭"
        case .open: item.approvedByMe ? "已批准" : "待审批"
        }
        return StatusPill(title: label, tint: tint)
    }

    private func approvalPill(_ item: MergeRequestItem) -> some View {
        let tint: Color = switch item.status {
        case .ready:
            .green
        case .blocked:
            .red
        case .draft:
            .gray
        default:
            item.approvedByMe ? .green : .orange
        }
        let icon: String = switch item.status {
        case .ready:
            "checkmark.circle.fill"
        case .blocked:
            "exclamationmark.triangle.fill"
        case .draft:
            "pencil"
        default:
            item.approvedByMe ? "checkmark.circle.fill" : "clock"
        }
        return StatusPill(title: item.approvalProgress, tint: tint, systemImage: icon)
    }

    private func pipelinePill(_ state: PipelineState) -> some View {
        let tint: Color = switch state {
        case .passed:
            .green
        case .pending:
            .orange
        case .failed:
            .red
        case .none:
            .gray
        }
        let icon: String = switch state {
        case .passed:
            "checkmark.circle.fill"
        case .pending:
            "hourglass"
        case .failed:
            "xmark.circle.fill"
        case .none:
            "minus.circle"
        }
        return StatusPill(title: state.rawValue, tint: tint, systemImage: icon)
    }

    private var selectedMRBinding: Binding<MergeRequestItem.ID?> {
        Binding(
            get: { appModel.selectedMergeRequestID },
            set: { appModel.selectedMergeRequestID = $0 }
        )
    }

    private var mrSortOrderBinding: Binding<[KeyPathComparator<MergeRequestItem>]> {
        Binding(
            get: { appModel.mrSortOrder },
            set: { appModel.mrSortOrder = $0 }
        )
    }

    private var mergeProjectBinding: Binding<String?> {
        Binding(
            get: { appModel.selectedMergeProjectID },
            set: { if let value = $0 { appModel.selectMergeProject(value) } }
        )
    }

    private var mergeSearchBinding: Binding<String> {
        Binding(
            get: { appModel.mergeRequestSearchText },
            set: { appModel.mergeRequestSearchText = $0 }
        )
    }

    private var mergeSheetBinding: Binding<Bool> {
        Binding(
            get: { appModel.showingCreateMRSheet },
            set: { appModel.showingCreateMRSheet = $0 }
        )
    }

    private var batchMergeSheetBinding: Binding<Bool> {
        Binding(
            get: { appModel.showingBatchCreateMRSheet },
            set: { appModel.showingBatchCreateMRSheet = $0 }
        )
    }

    private func batchSelectionBinding(for mrID: String) -> Binding<Bool> {
        Binding(
            get: { appModel.selectedBatchApproveMRIDs.contains(mrID) },
            set: { isSelected in
                let currentlySelected = appModel.selectedBatchApproveMRIDs.contains(mrID)
                if isSelected != currentlySelected {
                    appModel.toggleBatchApproveMR(mrID)
                }
            }
        )
    }

    private func isBatchSelectable(_ item: MergeRequestItem) -> Bool {
        [.open, .ready, .blocked, .draft].contains(item.status)
    }
}
