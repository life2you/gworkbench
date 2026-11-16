import SwiftUI
import AppKit

struct OnboardingSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var platform: RepositoryPlatform = .gitlab
    @State private var workspaceName: String = "公司 GitLab"
    @State private var nameTouched: Bool = false
    @State private var projectDirs: [PathEntryDraft] = []
    @State private var worktreesDir: String = ""
    @State private var host: String = ""
    @State private var token: String = ""
    @State private var ghCLITokenDetected: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    platformChoiceSection
                    workspaceNameAndDirsSection
                    credentialsSection
                    environmentProbeCard

                    if let errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.red)
                            Text(errorMessage)
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
        .frame(minWidth: 630, idealWidth: 660, minHeight: 500, idealHeight: 540)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadInitialState()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("👋 欢迎使用 GWorkbench · 添加你的第一个工作区标签")
                .font(.system(size: 14.5, weight: .semibold))

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

    // MARK: - 1. Platform Choice

    private var platformChoiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每个标签对应一组本地仓库与托管平台配置，进入主界面后可随时点击左上角「+」继续添加更多标签。")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                platformCard(
                    item: .gitlab,
                    icon: "network",
                    tint: .orange,
                    title: "GitLab 工作区",
                    subtitle: "输入标签名、绑定仓库目录、配置 Host & Token"
                )
                platformCard(
                    item: .github,
                    icon: "globe.americas",
                    tint: .purple,
                    title: "GitHub 工作区",
                    subtitle: "支持 github.com / Enterprise，自动继承 gh CLI"
                )
            }
        }
    }

    private func platformCard(
        item: RepositoryPlatform,
        icon: String,
        tint: Color,
        title: String,
        subtitle: String
    ) -> some View {
        let isSelected = platform == item
        return Button {
            platform = item
            if !nameTouched {
                workspaceName = item == .github ? "GitHub" : "公司 GitLab"
            }
            if item == .github && host.isEmpty {
                host = "https://github.com"
            } else if item == .gitlab && host == "https://github.com" {
                host = ""
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(isSelected ? tint.opacity(0.12) : Color(NSColor.controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? tint.opacity(0.75) : Color.secondary.opacity(0.18), lineWidth: isSelected ? 1.2 : 0.7)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. Label Name & Directories

    private var workspaceNameAndDirsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("标签名称")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("例如：公司 GitLab", text: $workspaceName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: workspaceName) { _, _ in
                            nameTouched = true
                        }
                }
                .frame(width: 190)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Worktree 默认存放目录")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        TextField("~/worktrees", text: $worktreesDir)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11.5, design: .monospaced))
                        Button("选择...") {
                            if let path = chooseDirectory() {
                                worktreesDir = path
                            }
                        }
                        .controlSize(.small)
                    }
                }
            }

            HStack {
                Text("绑定的本地代码仓库目录")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("+ 添加目录") {
                    if let path = chooseDirectory() {
                        if !projectDirs.contains(where: { $0.path == path }) {
                            projectDirs.append(PathEntryDraft(path: path))
                        }
                    }
                }
                .controlSize(.small)
            }

            if projectDirs.isEmpty {
                HStack {
                    Text("~/Code（点击右侧按钮选择本地仓库根目录）")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("选择...") {
                        if let path = chooseDirectory() {
                            projectDirs.append(PathEntryDraft(path: path))
                        }
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 0.7)
                )
            } else {
                ForEach($projectDirs) { $entry in
                    HStack(spacing: 8) {
                        TextField("项目根目录", text: $entry.path)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11.5, design: .monospaced))
                        Button(role: .destructive) {
                            projectDirs.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.red)
                    }
                }
            }
        }
    }

    // MARK: - 3. Host & Token

    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(platform == .gitlab
                 ? "GitLab Host 与 Access Token（可选，稍后也可在设置填写）"
                 : "GitHub Host 与 Token（默认 github.com，留空 Token 自动继承 gh CLI）")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField(platform == .gitlab ? "https://gitlab.example.com" : "https://github.com", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11.5, design: .monospaced))
                SecureField(platform == .gitlab ? "glpat-..." : "可选填入 ghp_...", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11.5, design: .monospaced))
            }
        }
    }

    // MARK: - 4. Environment Probe

    private var environmentProbeCard: some View {
        let installedIDE = appModel.scannedIDEs.first(where: \.isInstalled)?.displayName ?? "默认应用"
        let ready = !appModel.gitVersion.isEmpty

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("自动环境探测")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                StatusPill(title: ready ? "全部就绪" : "检测中", tint: ready ? .green : .orange)
            }

            HStack(spacing: 6) {
                Text("✓ 检测到 \(appModel.gitVersion.isEmpty ? "Git" : appModel.gitVersion)")
                Text("·")
                Text(ghCLITokenDetected ? "✓ 检测到 gh CLI 已登录" : "○ 未检测到 gh CLI 登录")
                Text("·")
                Text("✓ 检测到 \(installedIDE)")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 0.7)
        )
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Button("稍后再说") {
                dismiss()
            }
            .controlSize(.regular)

            Spacer()

            Button {
                Task {
                    await saveAndEnter()
                }
            } label: {
                if isSaving {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.small)
                        Text("正在保存...")
                    }
                } else {
                    Text("创建工作区并进入")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Actions

    private func loadInitialState() {
        let draft = appModel.settingsDraft
        if let activeWS = appModel.activeWorkspace {
            platform = activeWS.platform
            workspaceName = activeWS.name
            projectDirs = activeWS.projectsRootDirs.map { PathEntryDraft(path: $0) }
            host = activeWS.host
            token = activeWS.token
        } else {
            platform = appModel.activePlatform == .gitlab ? .gitlab : .github
            workspaceName = platform == .github ? "GitHub" : "公司 GitLab"
            projectDirs = draft.worktreeProjectsRootDirs
            host = platform == .github ? "https://github.com" : draft.gitlabHost
            token = platform == .github ? draft.githubToken : draft.gitlabToken
        }

        worktreesDir = draft.worktreesRootDir.isEmpty
            ? (FileManager.default.homeDirectoryForCurrentUser.path as NSString).appendingPathComponent("worktrees")
            : draft.worktreesRootDir
        ghCLITokenDetected = appModel.ghCLITokenAvailable

        Task.detached(priority: .utility) {
            let detected = !GitHubProvider.resolveToken(configuredToken: "").isEmpty
            await MainActor.run {
                ghCLITokenDetected = detected
            }
        }
    }

    private func saveAndEnter() async {
        let validDirs = projectDirs
            .map { PathEntryDraft(id: $0.id, path: $0.path.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.path.isEmpty }
        guard !validDirs.isEmpty else {
            errorMessage = "请至少添加一个本地代码仓库目录"
            return
        }

        isSaving = true
        errorMessage = nil

        appModel.settingsDraft.worktreesRootDir = worktreesDir.trimmingCharacters(in: .whitespacesAndNewlines)

        let existingID = appModel.activeWorkspace?.id
        let newDraft = WorkspaceProfileDraft(
            id: existingID ?? UUID().uuidString,
            name: workspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? (platform == .github ? "GitHub" : "GitLab")
                : workspaceName.trimmingCharacters(in: .whitespacesAndNewlines),
            platform: platform,
            projectsRootDirs: validDirs,
            worktreesRootDir: "",
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            token: token.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultTargetBranch: platform == .github ? "main" : "master",
            dashboardBaselinesText: platform == .github
                ? DefaultDashboardBaselines.github.joined(separator: ", ")
                : DefaultDashboardBaselines.gitlab.joined(separator: ", "),
            envBranchesText: platform == .gitlab ? "dev, test, stage, uat" : "",
            mergeBranchMiddle: "sync",
            branchMappings: []
        )

        await appModel.saveWorkspaceEditorDraft(newDraft, switchToIt: true)
        isSaving = false

        if appModel.settingsOperation.errorMessage == nil {
            dismiss()
        } else {
            errorMessage = appModel.settingsOperation.errorMessage
        }
    }

    private func chooseDirectory() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
