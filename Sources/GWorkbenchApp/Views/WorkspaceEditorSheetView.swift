import SwiftUI
import AppKit

struct WorkspaceEditorSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: WorkspaceProfileDraft
    @State private var isEditing: Bool
    @State private var newDirInput: String = ""
    @State private var tokenVisible: Bool = false
    @State private var nameTouched: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var testResultMessage: String?
    @State private var testResultSuccess: Bool = false
    @State private var validationError: String?

    init(initialDraft: WorkspaceProfileDraft?, isEditing: Bool) {
        let base = initialDraft ?? WorkspaceProfileDraft()
        _draft = State(initialValue: base)
        _isEditing = State(initialValue: isEditing)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    platformPickerSection
                    nameSection
                    directoriesSection
                    platformConfigSection
                    worktreeOverrideSection

                    if let validationError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.red)
                            Text(validationError)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Color.red)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }

            Divider()
            footerBar
        }
        .frame(minWidth: 660, idealWidth: 700, minHeight: 580, idealHeight: 680)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .foregroundStyle(draft.platform == .github ? Color.purple : Color.orange)
                Text(isEditing ? "编辑工作区标签" : "新建工作区标签")
                    .font(.system(size: 14.5, weight: .semibold))
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.bar)
    }

    // MARK: - 1. Platform Picker

    private var platformPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("1. 选择托管平台类型")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                platformCard(
                    platform: .gitlab,
                    title: "GitLab（自建 / SaaS）",
                    subtitle: "绑定内网或私有 GitLab Host、Access Token、环境分支链与 Merge Requests",
                    tint: .orange
                )
                platformCard(
                    platform: .github,
                    title: "GitHub（含 Enterprise）",
                    subtitle: "支持 github.com 或企业版 Host，自动继承 gh CLI 或填写 PAT",
                    tint: .purple
                )
            }
        }
    }

    private func platformCard(
        platform: RepositoryPlatform,
        title: String,
        subtitle: String,
        tint: Color
    ) -> some View {
        let isSelected = draft.platform == platform
        return Button {
            selectPlatform(platform)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: platform.icon)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(isSelected ? tint : .secondary)
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(isSelected ? tint.opacity(0.12) : Color(NSColor.controlBackgroundColor).opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isSelected ? tint.opacity(0.75) : Color.secondary.opacity(0.18), lineWidth: isSelected ? 1.3 : 0.7)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectPlatform(_ platform: RepositoryPlatform) {
        guard draft.platform != platform else { return }
        draft.platform = platform
        testResultMessage = nil
        if !isEditing && !nameTouched {
            draft.name = platform == .github ? "GitHub" : "私有 GitLab"
        }
        if platform == .github {
            if draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.host = "https://github.com"
            }
            if draft.mainlineBranchesText == "master" || draft.mainlineBranchesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.mainlineBranchList = ["main"]
            }
            if draft.dashboardBaselinesText == DefaultDashboardBaselines.gitlab.joined(separator: ", ") {
                draft.dashboardBaselinesText = DefaultDashboardBaselines.github.joined(separator: ", ")
            }
        } else {
            if draft.host == "https://github.com" {
                draft.host = ""
            }
            if draft.mainlineBranchesText == "main" || draft.mainlineBranchesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.mainlineBranchList = ["master"]
            }
            if draft.dashboardBaselinesText == DefaultDashboardBaselines.github.joined(separator: ", ") {
                draft.dashboardBaselinesText = DefaultDashboardBaselines.gitlab.joined(separator: ", ")
            }
            if draft.envBranchesText.isEmpty {
                draft.envBranchesText = "dev, test, stage, uat"
            }
        }
    }

    // MARK: - 2. Label Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("2. 标签显示名称（显示在左上角切换栏）")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("例如：公司 GitLab、个人 GitHub、开源项目", text: $draft.name)
                .textFieldStyle(.roundedBorder)
                .onChange(of: draft.name) { _, _ in
                    nameTouched = true
                }
        }
    }

    // MARK: - 3. Bound Directories

    private var directoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("3. 绑定的本地代码仓库目录")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("直接归属此标签 · 不再按 URL 猜测")
                    .font(.system(size: 10.5, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.14))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(draft.projectsRootDirs) { entry in
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(entry.path)
                            .font(.system(size: 11.5, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("移除") {
                            draft.projectsRootDirs.removeAll { $0.id == entry.id }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.red)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                HStack(spacing: 8) {
                    TextField("输入或选择本地目录，如 ~/vibeCodes/company-repos", text: $newDirInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11.5, design: .monospaced))
                        .onSubmit { addDirFromInput() }

                    Button("添加") {
                        addDirFromInput()
                    }
                    .disabled(newDirInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("选择目录...") {
                        if let path = chooseDirectory() {
                            appendDir(path)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 0.7)
            )
        }
    }

    // MARK: - 4. Platform-Specific Config

    private var platformConfigSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(draft.platform == .gitlab ? "4. GitLab 实例与工作流配置" : "4. GitHub 实例与工作流配置")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(draft.platform == .gitlab ? "私有 / SaaS 通用" : "支持 github.com / Enterprise")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.platform == .gitlab ? "GitLab Host 地址" : "GitHub Host 地址（支持 Enterprise）")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        TextField(
                            draft.platform == .gitlab ? "https://gitlab.example.com" : "https://github.com",
                            text: $draft.host
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11.5, design: .monospaced))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.platform == .gitlab ? "Access Token" : "Personal Access Token（留空继承 gh CLI）")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            if tokenVisible {
                                TextField(draft.platform == .gitlab ? "glpat-..." : "ghp_... / github_pat_...", text: $draft.token)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11.5, design: .monospaced))
                            } else {
                                SecureField(draft.platform == .gitlab ? "glpat-..." : "可选填入 ghp_...", text: $draft.token)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11.5, design: .monospaced))
                            }
                            Button {
                                tokenVisible.toggle()
                            } label: {
                                Image(systemName: tokenVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                BranchArchitectureEditorView(draft: $draft)

                HStack(spacing: 10) {
                    Button {
                        Task { await runConnectionTest() }
                    } label: {
                        Label(
                            isTestingConnection ? "正在测试..." : "测试 \(draft.platform.shortName) 连通性",
                            systemImage: "bolt.horizontal.circle"
                        )
                    }
                    .disabled(isTestingConnection)

                    if let testResultMessage {
                        Text(testResultMessage)
                            .font(.system(size: 11.5))
                            .foregroundStyle(testResultSuccess ? Color.green : Color.red)
                            .lineLimit(2)
                    }
                    Spacer()
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 0.7)
            )
        }
    }

    // MARK: - 5. Optional Worktree Root Override

    private var worktreeOverrideSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("5. Worktree 存放目录（可选覆盖，留空继承全局默认）")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("留空则使用全局 Worktrees 根目录", text: $draft.worktreesRootDir)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11.5, design: .monospaced))
                Button("选择...") {
                    if let path = chooseDirectory() {
                        draft.worktreesRootDir = path
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Spacer()
            Button("取消") {
                dismiss()
            }
            Button(isEditing ? "保存更改" : "创建并切换到此标签") {
                submit()
            }
            .buttonStyle(.borderedProminent)
            .disabled(appModel.settingsOperation.isRunning)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Helpers

    private func addDirFromInput() {
        let trimmed = newDirInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appendDir(trimmed)
        newDirInput = ""
    }

    private func appendDir(_ path: String) {
        let expanded = ProcessRunner.expandPath(path)
        if !draft.projectsRootDirs.contains(where: { $0.path == expanded }) {
            draft.projectsRootDirs.append(PathEntryDraft(path: expanded))
        }
    }

    private func chooseDirectory() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择目录"
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    private func runConnectionTest() async {
        isTestingConnection = true
        testResultMessage = nil
        defer { isTestingConnection = false }

        do {
            if draft.platform == .github {
                let msg = try await GitHubProvider.testConnection(configuredToken: draft.token, host: draft.host)
                testResultSuccess = true
                testResultMessage = "✓ \(msg)"
            } else {
                let msg = try await GitLabProvider.testConnection(host: draft.host, token: draft.token)
                testResultSuccess = true
                testResultMessage = "✓ \(msg)"
            }
        } catch {
            testResultSuccess = false
            testResultMessage = error.localizedDescription
        }
    }

    private func submit() {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationError = "请填写工作区标签名称"
            return
        }
        let validDirs = draft.projectsRootDirs.map { $0.path.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !validDirs.isEmpty else {
            validationError = "请至少绑定一个本地代码仓库目录"
            return
        }
        validationError = nil
        Task {
            await appModel.saveWorkspaceEditorDraft(draft, switchToIt: true)
            dismiss()
        }
    }
}
