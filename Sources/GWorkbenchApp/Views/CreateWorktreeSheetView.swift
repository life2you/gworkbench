import SwiftUI

struct CreateWorktreeSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var appModel = appModel

        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("新建工作树")
                    .font(.title2.weight(.semibold))
                Text("项目：\(appModel.currentWorktreeProject?.displayName ?? "未选择") · 工作树根目录：\(appModel.gwtmConfig?.worktreesRootDir ?? "未配置")")
                    .foregroundStyle(.secondary)
            }

            Form {
                Picker("创建方式", selection: modeBinding) {
                    ForEach(CreateWorktreeMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if appModel.createWorktreeDraft.mode == .newBranch {
                    Picker("基线分支", selection: $appModel.createWorktreeDraft.baseBranch) {
                        ForEach(appModel.availableBaseBranches, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }
                }

                if appModel.createWorktreeDraft.mode == .existingBranch, !appModel.availableExistingWorktreeBranchOptions.isEmpty {
                    Picker("已有分支", selection: $appModel.createWorktreeDraft.branchName) {
                        ForEach(appModel.availableExistingWorktreeBranchOptions) { option in
                            Text(option.label).tag(option.name)
                        }
                    }
                    .onChange(of: appModel.createWorktreeDraft.branchName) {
                        appModel.updateCreateWorktreePathFromBranch()
                    }
                } else {
                    TextField(
                        appModel.createWorktreeDraft.mode == .existingBranch ? "已有分支名" : "新分支名",
                        text: $appModel.createWorktreeDraft.branchName
                    )
                    .onChange(of: appModel.createWorktreeDraft.branchName) {
                        appModel.updateCreateWorktreePathFromBranch()
                    }
                }

                TextField("功能描述（可选）", text: $appModel.createWorktreeDraft.description, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                TextField("工作树路径", text: $appModel.createWorktreeDraft.path)

                Toggle("创建后用默认 IDE 打开", isOn: $appModel.createWorktreeDraft.openInIDE)
                Toggle("创建后执行依赖安装", isOn: $appModel.createWorktreeDraft.installDependencies)

                if appModel.createWorktreeDraft.mode == .existingBranch,
                   let option = appModel.availableExistingWorktreeBranchOptions.first(where: { $0.name == appModel.createWorktreeDraft.branchName }) {
                    LabeledContent("分支来源") {
                        Text(option.label)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            InlineOperationView(state: appModel.worktreeOperation)

            HStack {
                Text("当前直接复用 gwtm 的配置约定与 git worktree 命令。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("创建工作树") {
                    Task {
                        await appModel.createWorktree()
                        if !appModel.showingCreateWorktreeSheet {
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

    private var modeBinding: Binding<CreateWorktreeMode> {
        Binding(
            get: { appModel.createWorktreeDraft.mode },
            set: { appModel.setCreateWorktreeMode($0) }
        )
    }
}
