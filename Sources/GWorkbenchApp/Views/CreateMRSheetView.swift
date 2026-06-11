import SwiftUI

struct CreateMRSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var appModel = appModel

        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("新建 MR")
                    .font(.title2.weight(.semibold))
                Text("项目：\(appModel.currentMergeProject?.displayName ?? "未选择")")
                    .foregroundStyle(.secondary)
            }

            Form {
                Picker("来源分支", selection: $appModel.createMRDraft.sourceBranch) {
                    ForEach(sourceBranchOptions, id: \.self) { branch in
                        Text(branch).tag(branch)
                    }
                }

                Picker("目标分支", selection: $appModel.createMRDraft.targetBranch) {
                    ForEach(targetBranchOptions, id: \.self) { branch in
                        Text(branch).tag(branch)
                    }
                }
            }
            .formStyle(.grouped)

            if !appModel.availableMRMappings.isEmpty {
                SectionCard(title: "当前配置映射") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(appModel.availableMRMappings) { mapping in
                            HStack {
                                Text("\(mapping.source) → \(mapping.target)")
                                Spacer()
                                if mapping.protectedTarget {
                                    StatusPill(title: "保护目标", tint: .red)
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }

            InlineOperationView(state: appModel.mrOperation)

            HStack {
                Text("当前先按 gmux 配置创建 MR，审批与合并仍在列表页执行。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("创建 MR") {
                    Task {
                        await appModel.createMergeRequest()
                        if !appModel.showingCreateMRSheet {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 420)
    }

    private var sourceBranchOptions: [String] {
        let fromMappings = appModel.availableMRMappings.map(\.source)
        let fromLocal = appModel.currentMergeProject?.localBranches ?? []
        let combined = fromMappings + fromLocal
        let ordered = Array(NSOrderedSet(array: combined)) as? [String] ?? combined
        return ordered.isEmpty ? [""] : ordered
    }

    private var targetBranchOptions: [String] {
        let ordered = Array(NSOrderedSet(array: appModel.availableMRMappings.map(\.target))) as? [String]
        return ordered?.isEmpty == false ? ordered! : [""]
    }
}
