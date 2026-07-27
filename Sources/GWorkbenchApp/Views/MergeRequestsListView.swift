import SwiftUI

struct MergeRequestsListView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        VStack(spacing: 0) {
            header
            if appModel.mergeProjects.isEmpty {
                ContentUnavailableView("未检测到 gmux 项目", systemImage: "arrow.triangle.merge")
            } else {
                List(appModel.filteredMergeRequests, selection: $appModel.selectedMergeRequestID) { item in
                    HStack(alignment: .top, spacing: 10) {
                        if isBatchSelectable(item) {
                            Toggle("选择 \(item.iidLabel)", isOn: batchSelectionBinding(for: item.id))
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                                .disabled(appModel.mrOperation.isRunning)
                                .padding(.top, 2)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(item.iidLabel) · \(item.title)")
                                    .font(.headline)
                                Spacer()
                                approvalPill(item)
                            }
                            Text("\(item.sourceBranch) → \(item.targetBranch)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(item.author)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(item.updatedAt)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .tag(item.id)
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: mergeSheetBinding) {
            CreateMRSheetView()
        }
        .sheet(isPresented: batchMergeSheetBinding) {
            BatchCreateMRSheetView()
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ViewThatFits(in: .horizontal) {
                wideHeader
                compactHeader
            }

            batchSelectionBar

            InlineOperationView(state: appModel.mrOperation)
        }
        .padding(20)
        .background(.bar)
    }

    private var wideHeader: some View {
        HStack(spacing: 12) {
            titleBlock
            Spacer()
            projectPicker
                .frame(width: 220)
            searchField
                .frame(width: 260)
            refreshButton
            approveSelectedButton
            batchCreateButton
            createButton
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleBlock

            HStack(alignment: .center, spacing: 12) {
                projectPicker
                    .frame(minWidth: 220, maxWidth: 280)
                Spacer(minLength: 0)
                refreshButton
                approveSelectedButton
                batchCreateButton
                createButton
            }

            searchField
                .frame(maxWidth: .infinity)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("合并请求")
                .font(.title2.weight(.semibold))
            Text("查看待合并列表、按配置创建 MR，并把审批与合并动作收进一个面板里。")
                .foregroundStyle(.secondary)
        }
    }

    private var projectPicker: some View {
        Picker("项目", selection: mergeProjectBinding) {
            ForEach(appModel.mergeProjects) { project in
                Text(project.displayName).tag(Optional(project.id))
            }
        }
        .pickerStyle(.menu)
    }

    private var searchField: some View {
        TextField("按 IID、标题、分支或创建人搜索", text: mergeSearchBinding)
            .textFieldStyle(.roundedBorder)
    }

    private var refreshButton: some View {
        Button("刷新") {
            Task {
                await appModel.refreshMergeRequests()
            }
        }
    }

    private var batchCreateButton: some View {
        Button("批量创建") {
            appModel.prepareBatchMergeRequests()
        }
    }

    private var approveSelectedButton: some View {
        Button("审批合并已选（\(appModel.selectedBatchApproveMRs.count)）") {
            Task {
                await appModel.approveAndMergeSelectedBatchMRs()
            }
        }
        .disabled(!appModel.canBatchApproveSelectedMRs)
    }

    private var batchSelectionBar: some View {
        HStack(spacing: 12) {
            Text("已选择 \(appModel.selectedBatchApproveMRs.count) 条 MR")
                .font(.subheadline.weight(.medium))
            Text("仅勾选项会被审批并合并")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("全选当前结果") {
                appModel.selectAllVisibleOpenMergeRequests()
            }
            .disabled(appModel.visibleOpenMergeRequests.isEmpty || appModel.areAllVisibleOpenMergeRequestsSelected || appModel.mrOperation.isRunning)
            Button("清空选择") {
                appModel.clearBatchApproveSelection()
            }
            .disabled(appModel.selectedBatchApproveMRIDs.isEmpty || appModel.mrOperation.isRunning)
        }
    }

    private var createButton: some View {
        Button("新建 MR") {
            appModel.prepareCreateMergeRequest()
        }
        .buttonStyle(.borderedProminent)
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
        return StatusPill(title: item.approvalProgress, tint: tint)
    }
}
