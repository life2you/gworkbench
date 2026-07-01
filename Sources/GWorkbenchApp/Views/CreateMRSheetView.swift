import SwiftUI

struct CreateMRSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var sourceBranchSearchText = ""
    @State private var targetBranchSearchText = ""

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
                Section("来源分支") {
                    TextField("搜索远程 origin 分支", text: $sourceBranchSearchText)
                        .textFieldStyle(.roundedBorder)

                    if filteredSourceBranchOptions.isEmpty {
                        Text("没有匹配的远程来源分支")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("来源分支", selection: $appModel.createMRDraft.sourceBranch) {
                            ForEach(filteredSourceBranchOptions, id: \.self) { branch in
                                Text(branch).tag(branch)
                            }
                        }
                        .labelsHidden()
                    }
                }

                Section("目标分支") {
                    TextField("搜索目标分支", text: $targetBranchSearchText)
                        .textFieldStyle(.roundedBorder)

                    if filteredTargetBranchOptions.isEmpty {
                        Text("没有匹配的目标分支")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("目标分支", selection: $appModel.createMRDraft.targetBranch) {
                            ForEach(filteredTargetBranchOptions, id: \.self) { branch in
                                Text(branch).tag(branch)
                            }
                        }
                        .labelsHidden()
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
                Text("单个 MR 会按你当前选择的源分支和目标分支创建，审批与合并仍在列表页执行。")
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
        .onAppear {
            syncBranchSelections()
        }
        .onChange(of: sourceBranchSearchText) { _, _ in
            syncSourceBranchSelection()
        }
        .onChange(of: targetBranchSearchText) { _, _ in
            syncTargetBranchSelection()
        }
    }

    private var sourceBranchOptions: [String] {
        appModel.availableMRSourceBranches
    }

    private var filteredSourceBranchOptions: [String] {
        filterBranches(sourceBranchOptions, query: sourceBranchSearchText)
    }

    private var targetBranchOptions: [String] {
        appModel.availableMRTargetBranches
    }

    private var filteredTargetBranchOptions: [String] {
        filterBranches(targetBranchOptions, query: targetBranchSearchText)
    }

    private func filterBranches(_ branches: [String], query: String) -> [String] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return branches
        }
        return branches.filter { $0.localizedCaseInsensitiveContains(normalizedQuery) }
    }

    private func syncBranchSelections() {
        syncSourceBranchSelection()
        syncTargetBranchSelection()
    }

    private func syncSourceBranchSelection() {
        if filteredSourceBranchOptions.contains(appModel.createMRDraft.sourceBranch) {
            return
        }
        appModel.createMRDraft.sourceBranch = filteredSourceBranchOptions.first ?? ""
    }

    private func syncTargetBranchSelection() {
        if filteredTargetBranchOptions.contains(appModel.createMRDraft.targetBranch) {
            return
        }
        appModel.createMRDraft.targetBranch = filteredTargetBranchOptions.first ?? ""
    }
}
