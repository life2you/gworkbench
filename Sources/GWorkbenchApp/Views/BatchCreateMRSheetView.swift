import SwiftUI

struct BatchCreateMRSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var appModel = appModel

        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("批量创建 MR")
                    .font(.title2.weight(.semibold))
                Text("项目：\(appModel.currentMergeProject?.displayName ?? "未选择")")
                    .foregroundStyle(.secondary)
            }

            SectionCard(title: "分支映射多选") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("默认只展示可批量创建的非保护分支映射。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("全选") {
                            appModel.selectedBatchMRMappingIDs = Set(appModel.availableBatchMRMappings.map(\.id))
                        }
                        .buttonStyle(.bordered)
                        Button("清空") {
                            appModel.selectedBatchMRMappingIDs.removeAll()
                        }
                        .buttonStyle(.bordered)
                    }

                    if appModel.availableBatchMRMappings.isEmpty {
                        ContentUnavailableView("没有可批量创建的映射", systemImage: "arrow.triangle.merge")
                            .frame(maxWidth: .infinity)
                    } else {
                        List(appModel.availableBatchMRMappings, id: \.id) { mapping in
                            Toggle(
                                isOn: Binding(
                                    get: { appModel.selectedBatchMRMappingIDs.contains(mapping.id) },
                                    set: { isOn in
                                        if isOn {
                                            appModel.selectedBatchMRMappingIDs.insert(mapping.id)
                                        } else {
                                            appModel.selectedBatchMRMappingIDs.remove(mapping.id)
                                        }
                                    }
                                )
                            ) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(mapping.source) → \(mapping.target)")
                                            .font(.headline)
                                        Text("源分支：\(mapping.source)    目标分支：\(mapping.target)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                        .frame(minHeight: 240, maxHeight: 320)
                        .listStyle(.inset)
                    }
                }
            }

            InlineOperationView(state: appModel.mrOperation)

            HStack {
                Text("会先按你勾选的映射逐条创建 MR，审批与合并仍在列表页或一键审批合并里处理。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("创建选中 MR") {
                    Task {
                        await appModel.createBatchMergeRequests()
                        if !appModel.showingBatchCreateMRSheet {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!appModel.canCreateSelectedBatchMRs)
            }
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 520)
    }
}
