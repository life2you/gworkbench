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
                Text("项目：\(appModel.currentWorktreeProject?.displayName ?? "未选择") · 工作树根目录：\(appModel.effectiveWorktreeConfig?.worktreesRootDir ?? "未配置")")
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
                    // 新建分支模式
                    Picker("基线分支", selection: $appModel.createWorktreeDraft.baseBranch) {
                        ForEach(appModel.availableBaseBranches, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }

                    // 功能描述与 AI 智能建议
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("功能描述 / 需求背景")
                                .font(.system(size: 11, weight: .medium))
                            Spacer()

                            Button {
                                Task {
                                    await appModel.generateBranchNameWithAI()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if appModel.isAIGeneratingBranch {
                                        ProgressView().controlSize(.small)
                                        Text("AI 生成中...")
                                    } else {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 10))
                                        Text("AI 生成分支名")
                                    }
                                }
                            }
                            .controlSize(.small)
                            .buttonStyle(.bordered)
                            .tint(Color.blue)
                            .disabled(appModel.createWorktreeDraft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appModel.isAIGeneratingBranch)
                        }

                        TextField("简述需求或 Bug（如：修复退款回调重复扣除手续费的边界问题）...", text: $appModel.createWorktreeDraft.description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2, reservesSpace: true)
                            .font(.system(size: 12))

                        if let err = appModel.aiGenerationError {
                            Text("AI 提示: \(err)")
                                .font(.caption2)
                                .foregroundStyle(Color.red)
                        }
                    }

                    // 新分支名输入与候选胶囊
                    VStack(alignment: .leading, spacing: 6) {
                        Text("新分支名")
                            .font(.system(size: 11, weight: .medium))

                        TextField(
                            "例如: feat/refund-fee-dedup",
                            text: $appModel.createWorktreeDraft.branchName
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .onChange(of: appModel.createWorktreeDraft.branchName) {
                            appModel.updateCreateWorktreePathFromBranch()
                        }

                        // AI 备选分支胶囊栏
                        if !appModel.aiSuggestedAlternatives.isEmpty {
                            HStack(spacing: 6) {
                                Text("候选分支:")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)

                                ForEach(appModel.aiSuggestedAlternatives, id: \.self) { alt in
                                    Button {
                                        appModel.applyAISuggestedBranch(alt)
                                    } label: {
                                        Text(alt)
                                            .font(.system(size: 10, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.12))
                                            .foregroundStyle(Color.accentColor)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    .buttonStyle(.plain)
                                    .help("点击应用此分支名")
                                }
                            }
                            .padding(.top, 1)
                        }
                    }
                } else {
                    // 已有分支模式：选择已有分支，无 AI 生成分支名按钮
                    if !appModel.availableExistingWorktreeBranchOptions.isEmpty {
                        Picker("已有分支", selection: $appModel.createWorktreeDraft.branchName) {
                            ForEach(appModel.availableExistingWorktreeBranchOptions) { option in
                                Text(option.label).tag(option.name)
                            }
                        }
                        .onChange(of: appModel.createWorktreeDraft.branchName) {
                            appModel.updateCreateWorktreePathFromBranch()
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("已有分支名")
                                .font(.system(size: 11, weight: .medium))

                            TextField(
                                "输入已有分支名",
                                text: $appModel.createWorktreeDraft.branchName
                            )
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .onChange(of: appModel.createWorktreeDraft.branchName) {
                                appModel.updateCreateWorktreePathFromBranch()
                            }
                        }
                    }

                    if let option = appModel.availableExistingWorktreeBranchOptions.first(where: { $0.name == appModel.createWorktreeDraft.branchName }) {
                        LabeledContent("分支来源") {
                            Text(option.label)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 纯功能描述/备忘输入（无 AI 生成按钮）
                    VStack(alignment: .leading, spacing: 6) {
                        Text("功能描述 / 备忘（可选）")
                            .font(.system(size: 11, weight: .medium))

                        TextField("为该工作树记录开发备忘或任务背景...", text: $appModel.createWorktreeDraft.description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2, reservesSpace: true)
                            .font(.system(size: 12))
                    }
                }

                TextField("工作树落盘路径", text: $appModel.createWorktreeDraft.path)
                    .font(.system(size: 11.5, design: .monospaced))

                Toggle("创建后用默认 IDE 打开", isOn: $appModel.createWorktreeDraft.openInIDE)
                Toggle("创建后执行依赖安装", isOn: $appModel.createWorktreeDraft.installDependencies)
            }
            .formStyle(.grouped)

            InlineOperationView(state: appModel.worktreeOperation)

            HStack {
                Text("使用标准 Git worktree 命令与配置约定。")
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
