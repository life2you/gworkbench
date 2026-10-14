import SwiftUI
import AppKit

struct CreateWorktreeSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var appModel = appModel

        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    modePickerCard

                    if appModel.createWorktreeDraft.mode == .newBranch {
                        newBranchCard
                    } else {
                        existingBranchCard
                    }

                    storagePathCard

                    optionsCard

                    if appModel.worktreeOperation.isRunning || appModel.worktreeOperation.errorMessage != nil {
                        InlineOperationView(state: appModel.worktreeOperation)
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }

            Divider()
            footerBar
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 520, idealHeight: 580)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: "plus.rectangle.on.folder.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("新建 Git 工作树 (Worktree)")
                    .font(.system(size: 14, weight: .semibold))

                HStack(spacing: 6) {
                    if let project = appModel.currentWorktreeProject {
                        Text(project.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        if project.platform != .local {
                            StatusPill(title: project.platform.badgeText, tint: project.platform.tintColor)
                        }
                    }
                }
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Mode Picker Card

    private var modePickerCard: some View {
        HStack {
            Text("创建方式")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Picker("创建方式", selection: modeBinding) {
                ForEach(CreateWorktreeMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 240)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
        )
    }

    // MARK: - New Branch Card

    private var newBranchCard: some View {
        @Bindable var appModel = appModel

        return SectionCard(title: "新建分支配置") {
            VStack(alignment: .leading, spacing: 14) {
                // 基线分支
                HStack(spacing: 12) {
                    Text("基线分支")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)

                    Picker("基线分支", selection: $appModel.createWorktreeDraft.baseBranch) {
                        ForEach(appModel.availableBaseBranches, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider().opacity(0.4)

                // 功能描述与 AI 智能生成
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("功能描述")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)

                        Spacer()

                        Button {
                            Task {
                                await appModel.generateBranchNameWithAI()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if appModel.isAIGeneratingBranch {
                                    ProgressView().controlSize(.small)
                                    Text("AI 推导中...")
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 10))
                                    Text("AI 生成分支名")
                                }
                            }
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                        .tint(Color.accentColor)
                        .disabled(appModel.createWorktreeDraft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appModel.isAIGeneratingBranch)
                    }

                    TextField("简述需求或 Bug（如：优化批量发票导出的内存占用）...", text: $appModel.createWorktreeDraft.description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2, reservesSpace: true)
                        .font(.system(size: 12))

                    if let err = appModel.aiGenerationError {
                        Text("AI 提示: \(err)")
                            .font(.caption2)
                            .foregroundStyle(Color.red)
                    }
                }

                Divider().opacity(0.4)

                // 新分支名与 AI 备选胶囊
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("新分支名")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)

                        TextField("例如: feat/invoice-export-perf", text: $appModel.createWorktreeDraft.branchName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .onChange(of: appModel.createWorktreeDraft.branchName) {
                                appModel.updateCreateWorktreePathFromBranch()
                            }
                    }

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
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.12))
                                        .foregroundStyle(Color.accentColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                .help("点击采用此候选分支名")
                            }
                        }
                        .padding(.leading, 82)
                    }
                }
            }
        }
    }

    // MARK: - Existing Branch Card

    private var existingBranchCard: some View {
        @Bindable var appModel = appModel

        return SectionCard(title: "已有分支配置") {
            VStack(alignment: .leading, spacing: 14) {
                // 已有分支选择
                HStack(spacing: 12) {
                    Text("已有分支")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)

                    if !appModel.availableExistingWorktreeBranchOptions.isEmpty {
                        Picker("已有分支", selection: $appModel.createWorktreeDraft.branchName) {
                            ForEach(appModel.availableExistingWorktreeBranchOptions) { option in
                                Text(option.label).tag(option.name)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: appModel.createWorktreeDraft.branchName) {
                            appModel.updateCreateWorktreePathFromBranch()
                        }
                    } else {
                        TextField("输入已有分支名", text: $appModel.createWorktreeDraft.branchName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .onChange(of: appModel.createWorktreeDraft.branchName) {
                                appModel.updateCreateWorktreePathFromBranch()
                            }
                    }
                }

                if let option = appModel.availableExistingWorktreeBranchOptions.first(where: { $0.name == appModel.createWorktreeDraft.branchName }) {
                    HStack(spacing: 8) {
                        Text("分支类型")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)
                        Text(option.label)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().opacity(0.4)

                // 纯描述/备忘输入（无 AI 按钮）
                VStack(alignment: .leading, spacing: 6) {
                    Text("功能描述 / 备忘 (可选)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("为该工作树记录开发备忘或任务背景...", text: $appModel.createWorktreeDraft.description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2, reservesSpace: true)
                        .font(.system(size: 12))
                }
            }
        }
    }

    // MARK: - Storage Path Card

    private var storagePathCard: some View {
        @Bindable var appModel = appModel

        return SectionCard(title: "工作树磁盘落盘路径") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("工作树落盘路径", text: $appModel.createWorktreeDraft.path)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11.5, design: .monospaced))

                    Button("选择目录...") {
                        if let path = chooseDirectory() {
                            appModel.createWorktreeDraft.path = path
                        }
                    }
                    .controlSize(.small)
                }

                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text("默认由工作树根目录与路径模板自动生成，亦可手动更改。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Options Card

    private var optionsCard: some View {
        @Bindable var appModel = appModel

        return SectionCard(title: "后续动作") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $appModel.createWorktreeDraft.openInIDE) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accentColor)
                        Text("创建完成后在默认 IDE (\(appModel.currentIDELabel)) 中直接打开")
                            .font(.system(size: 11.5))
                    }
                }

                Toggle(isOn: $appModel.createWorktreeDraft.installDependencies) {
                    HStack(spacing: 6) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("创建后自动检测并执行依赖安装 (pnpm / npm / cargo)")
                            .font(.system(size: 11.5))
                    }
                }
            }
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            Text("通过原生 git worktree add 创建完全独立的工作空间。")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()

            Button("取消") {
                dismiss()
            }
            .controlSize(.regular)

            Button {
                Task {
                    await appModel.createWorktree()
                    if !appModel.showingCreateWorktreeSheet {
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if appModel.worktreeOperation.isRunning {
                        ProgressView().controlSize(.small)
                        Text("正在创建...")
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("创建工作树")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(appModel.createWorktreeDraft.branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appModel.worktreeOperation.isRunning)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Helpers

    private var modeBinding: Binding<CreateWorktreeMode> {
        Binding(
            get: { appModel.createWorktreeDraft.mode },
            set: { appModel.setCreateWorktreeMode($0) }
        )
    }

    private func chooseDirectory() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
