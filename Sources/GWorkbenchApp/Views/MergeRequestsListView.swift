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
                ContentUnavailableView("暂无匹配合并请求", systemImage: "tray", description: Text("可尝试清空搜索过滤词或在侧边栏切换状态筛选"))
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
            Picker("项目", selection: mergeProjectBinding) {
                ForEach(appModel.mergeProjects) { project in
                    Text(project.displayName).tag(Optional(project.id))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("筛选 IID、标题、分支或作者...", text: mergeSearchBinding)
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
            .frame(minWidth: 200, maxWidth: 300)

            Spacer()

            Button {
                Task {
                    await appModel.refreshMergeRequests()
                }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .help("从 GitLab 重新拉取当前项目的最新 MR 状态")

            Button {
                appModel.copySelectedMRWebURL()
            } label: {
                Label("复制链接", systemImage: "link")
            }
            .disabled(appModel.selectedMergeRequest == nil)
            .help(appModel.selectedMergeRequest != nil ? "复制当前选中的 MR 链接 (\(appModel.selectedMergeRequest!.iidLabel))" : "请先选择一条合并请求")

            Button {
                appModel.prepareBatchMergeRequests()
            } label: {
                Label("批量创建", systemImage: "square.grid.3x1.folder.badge.plus")
            }
            .help("按配置环境分支映射批量创建 MR")

            Button {
                appModel.prepareCreateMergeRequest()
            } label: {
                Label("新建 MR", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
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

            TableColumn("标题", value: \.title) { item in
                HStack(spacing: 6) {
                    Text(item.iidLabel)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(item.title)
                        .font(.system(.body))
                        .lineLimit(1)
                }
            }
            .width(min: 220, ideal: 300)

            TableColumn("分支流向", value: \.sourceBranch) { item in
                HStack(spacing: 5) {
                    Text(item.sourceBranch)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(item.targetBranch)
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .foregroundStyle(item.protectedTarget ? Color.orange : Color.primary)
                        .lineLimit(1)
                    if item.protectedTarget {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.orange)
                    }
                }
            }
            .width(min: 170, ideal: 220)

            TableColumn("审批进度", value: \.approvalProgress) { item in
                approvalPill(item)
            }
            .width(min: 90, ideal: 105, max: 120)

            TableColumn("流水线", value: \.pipeline.rawValue) { item in
                pipelinePill(item.pipeline)
            }
            .width(min: 80, ideal: 95, max: 110)

            TableColumn("作者", value: \.author) { item in
                HStack(spacing: 5) {
                    Text(item.author)
                        .font(.caption)
                        .lineLimit(1)
                    Text("@\(item.authorUsername)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .width(min: 100, ideal: 125)

            TableColumn("更新时间", value: \.updatedAt) { item in
                Text(item.updatedAt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 75, ideal: 90, max: 110)

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
                    .help("复制此 MR 链接 (\(item.iidLabel))")

                    Button {
                        appModel.openMRInBrowser(item)
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("在 GitLab 中打开 (\(item.iidLabel))")
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
            Label("在 GitLab 中打开", systemImage: "arrow.up.forward.app")
        }

        Button {
            appModel.copyMRWebURL(item)
        } label: {
            Label("复制 MR 链接", systemImage: "link")
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
                Label("审批并合并此 MR", systemImage: "checkmark.circle")
            }
            .disabled(appModel.mrOperation.isRunning)
        }

        Button(role: .destructive) {
            appModel.selectedMergeRequestID = item.id
            Task {
                await appModel.closeSelectedMR()
            }
        } label: {
            Label("关闭此 MR", systemImage: "xmark.circle")
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
                Text(appModel.appConfig?.gitlabHost ?? "GitLab 已连接")
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

            Text("GWorkbench • MR Queue")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Helper Views & Bindings

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
