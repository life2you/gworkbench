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
                    .padding(.vertical, 6)
                    .tag(item.id)
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: mergeSheetBinding) {
            CreateMRSheetView()
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ViewThatFits(in: .horizontal) {
                wideHeader
                compactHeader
            }

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
            approveAllButton
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
                approveAllButton
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
            Task {
                await appModel.createBatchMergeRequests()
            }
        }
    }

    private var approveAllButton: some View {
        Button("一键审批合并") {
            Task {
                await appModel.approveAndMergeVisibleMRs()
            }
        }
        .disabled(!appModel.canBatchApproveAndMergeVisibleMRs)
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
