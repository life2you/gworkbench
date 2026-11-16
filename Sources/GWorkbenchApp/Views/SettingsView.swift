import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case workspaces
    case currentWorkspace
    case general
    case ide
    case ai
    case policy

    var id: String { rawValue }

    func title(for workspaceName: String?) -> String {
        switch self {
        case .workspaces:
            return "工作区标签管理"
        case .currentWorkspace:
            let name = workspaceName?.trimmingCharacters(in: .whitespacesAndNewlines)
            return name?.isEmpty == false ? "当前标签「\(name!)」" : "当前标签配置"
        case .general:
            return "全局默认目录与模板"
        case .ide:
            return "IDE 与终端偏好"
        case .ai:
            return "AI 分支命名"
        case .policy:
            return "合并策略与安全"
        }
    }

    func systemImage(for platform: RepositoryPlatform) -> String {
        switch self {
        case .workspaces:
            return "tag.fill"
        case .currentWorkspace:
            return platform.icon
        case .general:
            return "folder.fill"
        case .ide:
            return "wrench.and.screwdriver.fill"
        case .ai:
            return "sparkles"
        case .policy:
            return "shield.checkered"
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    var onClose: (() -> Void)? = nil
    @State private var selectedTab: SettingsTab = .workspaces
    @State private var ghCLIDetected: Bool = false

    private var visibleTabs: [SettingsTab] {
        if appModel.settingsDraft.workspaces.isEmpty {
            return [.workspaces, .general, .ide, .ai, .policy]
        }
        return SettingsTab.allCases
    }

    var body: some View {
        @Bindable var appModel = appModel

        VStack(spacing: 0) {
            toolbarHeader
            Divider()

            HStack(spacing: 0) {
                settingsNavColumn
                Divider()
                settingsContentColumn
            }
        }
        .onAppear {
            if !visibleTabs.contains(selectedTab) {
                selectedTab = visibleTabs.first ?? .workspaces
            }
            Task.detached(priority: .utility) {
                let detected = !GitHubProvider.resolveToken(configuredToken: "").isEmpty
                await MainActor.run {
                    ghCLIDetected = detected
                }
            }
        }
    }

    // MARK: - Toolbar Header

    private var toolbarHeader: some View {
        HStack(spacing: 10) {
            Text("系统设置 · 工作区标签与全局偏好")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

            Spacer()

            Button {
                appModel.showingOnboardingSheet = true
            } label: {
                Label("配置向导", systemImage: "wand.and.stars")
            }
            .help("重新打开首次启动引导向导")

            Button {
                Task { await appModel.reloadSettingsOnly() }
            } label: {
                Text("还原更改")
            }
            .help("丢弃未保存的草稿，重新从本地 config.toml 读取")

            Button {
                Task { await appModel.saveSettings() }
            } label: {
                Label("保存设置", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(appModel.settingsOperation.isRunning)

            if let onClose {
                Divider()
                    .frame(height: 18)
                Button("关闭") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.bar)
    }

    // MARK: - Left Vertical Settings Nav

    private var settingsNavColumn: some View {
        let wsName = appModel.activeWorkspace?.name
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(visibleTabs) { tab in
                let isSelected = selectedTab == tab
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.systemImage(for: appModel.activePlatform))
                            .font(.system(size: 11.5, weight: .medium))
                            .frame(width: 15)
                            .foregroundStyle(isSelected ? Color.white : navIconColor(for: tab))
                        Text(tab.title(for: wsName))
                            .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(isSelected ? Color.accentColor : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(width: 195)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.22))
    }

    private func navIconColor(for tab: SettingsTab) -> Color {
        switch tab {
        case .workspaces:
            return .accentColor
        case .currentWorkspace:
            return appModel.activePlatform.tintColor
        case .general:
            return .blue
        case .ide:
            return .orange
        case .ai:
            return .purple
        case .policy:
            return .green
        }
    }

    // MARK: - Right Settings Content Column

    private var settingsContentColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if appModel.settingsOperation.isRunning
                    || appModel.settingsOperation.errorMessage != nil
                    || (appModel.settingsOperation.successMessage != nil && appModel.settingsOperation.successMessage != "配置读取完成") {
                    InlineOperationView(state: appModel.settingsOperation)
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                        )
                }

                switch selectedTab {
                case .workspaces:
                    workspacesManagerSection
                case .currentWorkspace:
                    currentWorkspaceSection
                case .general:
                    generalSection
                case .ide:
                    ideAndTerminalSection
                case .ai:
                    aiSection
                case .policy:
                    policySection
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Tab 1: Workspace Profiles Manager

    private var workspacesManagerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionCard(title: "自定义工作区标签（共 \(appModel.settingsDraft.workspaces.count) 个）") {
                HStack(spacing: 12) {
                    Text("每个标签独立绑定一个代码平台（GitHub / GitLab）、一组本地仓库目录和对应凭据与分支规则。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        appModel.openNewWorkspaceEditor()
                    } label: {
                        Label("新建工作区标签", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if appModel.settingsDraft.workspaces.isEmpty {
                SectionCard(title: "尚未配置任何工作区标签") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("点击右上角「新建工作区标签」，选择 GitLab 或 GitHub 并绑定对应的本地代码目录。")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Button {
                            appModel.openNewWorkspaceEditor()
                        } label: {
                            Label("立即创建第一个标签", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                ForEach(appModel.settingsDraft.workspaces) { draft in
                    let isCurrent = draft.id == (appModel.activeWorkspace?.id ?? appModel.settingsDraft.activeWorkspaceID)
                    let profile = draft.toWorkspaceProfile()
                    workspaceProfileCard(profile: profile, isCurrent: isCurrent)
                }
            }
        }
    }

    private func workspaceProfileCard(profile: WorkspaceProfile, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: profile.platform.icon)
                    .foregroundStyle(profile.platform.tintColor)
                Text(profile.name)
                    .font(.system(size: 13.5, weight: .semibold))
                StatusPill(title: profile.platform.shortName, tint: profile.platform.tintColor)
                if isCurrent {
                    StatusPill(title: "当前激活", tint: .blue)
                }
                Spacer()
                if !isCurrent {
                    Button("切换至此标签") {
                        appModel.selectWorkspace(profile.id)
                    }
                    .controlSize(.small)
                }
                Button("编辑配置") {
                    appModel.openEditWorkspaceEditor(profile)
                }
                .controlSize(.small)

                if appModel.settingsDraft.workspaces.count > 1 {
                    Button("删除", role: .destructive) {
                        Task { await appModel.deleteWorkspaceProfile(id: profile.id) }
                    }
                    .controlSize(.small)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("绑定的仓库目录 (\(profile.projectsRootDirs.count))")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    if profile.projectsRootDirs.isEmpty {
                        Text("未绑定目录")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(profile.projectsRootDirs, id: \.self) { dir in
                            Text(dir)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("平台连接与分支角色")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    Text("Host: \(profile.effectiveHostDisplay)")
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("生产主干: \(profile.configuredMainlineBranches.isEmpty ? "未配置" : profile.configuredMainlineBranches.joined(separator: ", ")) · 保护: \(profile.effectiveProtectedBranches.isEmpty ? "无" : profile.effectiveProtectedBranches.joined(separator: ", "))")
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("看板基线: \(profile.effectiveDashboardBaselines.joined(separator: ", "))")
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(isCurrent ? Color.accentColor.opacity(0.06) : Color(NSColor.controlBackgroundColor).opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrent ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.16), lineWidth: isCurrent ? 1.1 : 0.7)
        )
    }

    // MARK: - Tab 2: Active Workspace Configuration

    @ViewBuilder
    private var currentWorkspaceSection: some View {
        @Bindable var appModel = appModel
        let targetID = appModel.activeWorkspace?.id ?? appModel.settingsDraft.activeWorkspaceID
        if let index = appModel.settingsDraft.workspaces.firstIndex(where: { $0.id == targetID }) {
            let binding = $appModel.settingsDraft.workspaces[index]
            workspaceInlineEditor(draft: binding)
        } else {
            workspacesManagerSection
        }
    }

    private func workspaceInlineEditor(draft: Binding<WorkspaceProfileDraft>) -> some View {
        @Bindable var appModel = appModel
        let current = draft.wrappedValue

        return VStack(alignment: .leading, spacing: 16) {
            SectionCard(title: "标签基础信息 · \(current.name)") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("标签显示名称")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("标签名称", text: draft.name)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("托管平台类型")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Picker("托管平台", selection: draft.platform) {
                                Text("GitHub").tag(RepositoryPlatform.github)
                                Text("GitLab").tag(RepositoryPlatform.gitlab)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("绑定的代码仓库目录（仅该标签扫描）")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("添加目录") {
                                if let path = chooseDirectory() {
                                    let expanded = ProcessRunner.expandPath(path)
                                    if !draft.wrappedValue.projectsRootDirs.contains(where: { $0.path == expanded }) {
                                        draft.wrappedValue.projectsRootDirs.append(PathEntryDraft(path: expanded))
                                    }
                                }
                            }
                            .controlSize(.small)
                        }

                        ForEach(draft.projectsRootDirs) { $entry in
                            HStack(spacing: 8) {
                                TextField("项目根目录路径", text: $entry.path)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11.5, design: .monospaced))
                                Button(role: .destructive) {
                                    let entryID = entry.id
                                    draft.wrappedValue.projectsRootDirs.removeAll { $0.id == entryID }
                                } label: {
                                    Image(systemName: "trash").font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.red)
                            }
                        }
                    }
                }
            }

            if current.platform == .github {
                SectionCard(title: "GitHub 实例与认证凭据") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "globe.americas")
                                .foregroundStyle(Color.purple)
                            Text("GitHub 连接")
                                .font(.system(size: 12.5, weight: .semibold))
                            Spacer()
                            StatusPill(
                                title: (!current.token.isEmpty ? "已配置 PAT" : (ghCLIDetected ? "已继承 gh CLI" : "未检测到凭据")),
                                tint: (!current.token.isEmpty || ghCLIDetected) ? .green : .orange
                            )
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("GitHub Host 地址（支持 Enterprise）")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("https://github.com", text: draft.host)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Personal Access Token（留空继承 gh CLI）")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                if appModel.settingsTokenVisible {
                                    TextField("可选填入 ghp_... / github_pat_...", text: draft.token)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11.5, design: .monospaced))
                                } else {
                                    SecureField("可选填入 ghp_... / github_pat_...", text: draft.token)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11.5, design: .monospaced))
                                }
                                Button {
                                    appModel.settingsTokenVisible.toggle()
                                } label: {
                                    Image(systemName: appModel.settingsTokenVisible ? "eye.slash" : "eye")
                                        .font(.system(size: 11))
                                }
                                .controlSize(.small)
                            }
                        }

                        Text("说明：填写企业版域名（如 https://github.company.com）时将自动请求 /api/v3 与 gh auth token --hostname。")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)

                        Button("测试 GitHub API 连通性") {
                            Task {
                                await appModel.testGitHubConnection(host: current.host, token: current.token)
                            }
                        }
                        .disabled(appModel.settingsOperation.isRunning)
                    }
                }
            } else {
                SectionCard(title: "GitLab 实例与认证") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "network")
                                .foregroundStyle(Color.orange)
                            Text("GitLab 实例连接")
                                .font(.system(size: 12.5, weight: .semibold))
                            Spacer()
                            StatusPill(title: "私有 / SaaS 通用", tint: .orange)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("GitLab Host 地址（支持内网 IP 或域名）")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("https://gitlab.example.com", text: draft.host)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Access Token")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                if appModel.settingsTokenVisible {
                                    TextField("glpat-...", text: draft.token)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11.5, design: .monospaced))
                                } else {
                                    SecureField("glpat-...", text: draft.token)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11.5, design: .monospaced))
                                }
                                Button {
                                    appModel.settingsTokenVisible.toggle()
                                } label: {
                                    Image(systemName: appModel.settingsTokenVisible ? "eye.slash" : "eye")
                                        .font(.system(size: 11))
                                }
                                .controlSize(.small)
                            }
                        }

                        Button("测试 GitLab API 连通性") {
                            Task {
                                await appModel.testGitLabConnection(host: current.host, token: current.token)
                            }
                        }
                        .disabled(appModel.settingsOperation.isRunning)
                    }
                }
            }

            SectionCard(title: "分支架构与流转规则") {
                BranchArchitectureEditorView(draft: draft)
            }

            SectionCard(title: "工作树目录覆盖（可选）") {
                HStack(spacing: 8) {
                    TextField("留空继承全局默认 Worktrees 根目录", text: draft.worktreesRootDir)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11.5, design: .monospaced))
                    Button("选择目录") {
                        if let path = chooseDirectory() {
                            draft.wrappedValue.worktreesRootDir = path
                        }
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Tab 2: Directories & Worktree Path Template

    private var generalSection: some View {
        @Bindable var appModel = appModel

        return VStack(alignment: .leading, spacing: 16) {
            SectionCard(title: "代码仓库根目录说明") {
                HStack(spacing: 12) {
                    Text("代码仓库扫描目录已按「工作区标签」独立绑定，不再混在一起扫描。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("前往工作区标签管理") {
                        selectedTab = .workspaces
                    }
                    .controlSize(.small)
                }
            }

            SectionCard(title: "工作树存储路径与命名模板") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("工作树默认存储根目录 (Worktrees Root Dir)")
                            .font(.system(size: 11.5, weight: .medium))
                        HStack(spacing: 8) {
                            TextField("工作树默认存储目录", text: $appModel.settingsDraft.worktreesRootDir)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))

                            Button("选择目录") {
                                if let path = chooseDirectory() {
                                    appModel.settingsDraft.worktreesRootDir = path
                                }
                            }
                            .controlSize(.small)
                        }
                    }

                    Divider().opacity(0.4)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("路径生成模式与通配符模板")
                                .font(.system(size: 11.5, weight: .medium))
                            Spacer()
                            Text("支持变量: ${rootDir}, ${project}, ${branch}, ${date}")
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Text("路径预设")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 68, alignment: .leading)
                                Picker("路径预设", selection: pathPresetBinding) {
                                    Text("分层目录: ${project}/${branch}").tag("${rootDir}/${project}/${branch}")
                                    Text("前缀扁平: ${project}_${branch}").tag("${rootDir}/${project}_${branch}")
                                    Text("纯分支扁平: ${branch}").tag("${rootDir}/${branch}")
                                    Text("自定义格式...").tag("custom")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: 280, alignment: .leading)
                                Spacer(minLength: 0)
                            }

                            HStack(spacing: 10) {
                                Text("格式模板")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 68, alignment: .leading)
                                TextField("通配符格式表达式", text: $appModel.settingsDraft.worktreePathTemplate)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11.5, design: .monospaced))
                            }
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.accentColor)
                            Text("落盘预览:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(currentPathTemplatePreview)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    // MARK: - Tab 3: IDE & Terminal Preferences

    private var ideAndTerminalSection: some View {
        @Bindable var appModel = appModel

        return VStack(alignment: .leading, spacing: 16) {
            SectionCard(title: "IDE 编辑器外部集成（支持多选）") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("可同时配置多个常用 IDE / 编辑器；设为「默认」的主编辑器用于快捷点击，右键菜单与详情页打开菜单均可随时切换全部已配置编辑器。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 10)
                        Button("重新扫描") { appModel.refreshScannedIDEs() }.controlSize(.small)
                        Button("添加自定义") { appModel.addCustomIDEProfile() }.controlSize(.small)
                    }

                    let installedIDEs = appModel.scannedIDEs.filter(\.isInstalled)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("本机已检测编辑器（点击勾选/取消多选）")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("· \(installedIDEs.count) 个可用")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.tertiary)
                        }

                        if installedIDEs.isEmpty {
                            Text("暂未自动检测到主流 IDE，可点击右上角「添加自定义」手动填入 App 名称或 CLI 命令。")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            BranchFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                                ForEach(installedIDEs) { ide in
                                    let isConfigured = appModel.isInstalledIDEConfigured(ide)
                                    Button {
                                        appModel.toggleInstalledIDEInDraft(ide)
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: isConfigured ? "checkmark.circle.fill" : "plus.circle")
                                                .font(.system(size: 11))
                                            Text(ide.displayName)
                                                .font(.system(size: 11.5, weight: isConfigured ? .semibold : .regular))
                                        }
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .foregroundStyle(isConfigured ? Color.accentColor : Color.secondary)
                                        .background(isConfigured ? Color.accentColor.opacity(0.14) : Color(NSColor.controlBackgroundColor).opacity(0.65))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(isConfigured ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.18), lineWidth: 0.7)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .help(ide.locationDescription)
                                }
                            }
                        }
                    }

                    Divider().opacity(0.4)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("已配置的编辑器菜单列表（共 \(appModel.settingsDraft.ideProfiles.count) 个）")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("测试默认 IDE") { appModel.testOpenIDE() }.controlSize(.small)
                        }

                        ForEach($appModel.settingsDraft.ideProfiles) { $profile in
                            let isDefault = profile.id == appModel.settingsDraft.defaultIDEProfileID
                                || (appModel.settingsDraft.defaultIDEProfileID.isEmpty && profile.id == appModel.settingsDraft.ideProfiles.first?.id)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Button {
                                        appModel.setDefaultIDEProfile(id: profile.id)
                                    } label: {
                                        HStack(spacing: 3) {
                                            Image(systemName: isDefault ? "star.fill" : "star")
                                                .font(.system(size: 10.5))
                                            Text(isDefault ? "默认" : "设默认")
                                                .font(.system(size: 10.5, weight: isDefault ? .semibold : .regular))
                                                .lineLimit(1)
                                        }
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 4)
                                        .foregroundStyle(isDefault ? Color.orange : Color.secondary)
                                        .background(isDefault ? Color.orange.opacity(0.14) : Color(NSColor.controlBackgroundColor).opacity(0.55))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(isDefault ? Color.orange.opacity(0.45) : Color.secondary.opacity(0.18), lineWidth: 0.6)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .help("设为主默认编辑器（用于直接点击与双击打开）")

                                    TextField("显示名称", text: $profile.label)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(minWidth: 120)

                                    Picker("模式", selection: $profile.mode) {
                                        Text("app").tag("app")
                                        Text("custom").tag("custom")
                                        Text("system").tag("system")
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                    .frame(width: 88)

                                    Button("测试") {
                                        appModel.testOpenIDE(profile)
                                    }
                                    .controlSize(.small)
                                    .fixedSize()

                                    Button(role: .destructive) {
                                        appModel.removeIDEProfile(id: profile.id)
                                    } label: {
                                        Image(systemName: "trash").font(.system(size: 11))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Color.red)
                                }

                                HStack(spacing: 8) {
                                    Text(profile.mode == "custom" ? "CLI 命令" : (profile.mode == "system" ? "系统默认" : "应用名称"))
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 56, alignment: .leading)
                                    TextField(
                                        profile.mode == "custom" ? "CLI 命令或模板，如 cursor / code / zed {path}" : "macOS App 名称，如 Cursor / IntelliJ IDEA",
                                        text: $profile.command
                                    )
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11.5, design: .monospaced))
                                }
                            }
                            .padding(10)
                            .background(Color(NSColor.windowBackgroundColor).opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(isDefault ? Color.orange.opacity(0.32) : Color.secondary.opacity(0.14), lineWidth: 0.6)
                            )
                            .onChange(of: profile) {
                                if isDefault {
                                    appModel.setDefaultIDEProfile(id: profile.id)
                                }
                            }
                        }
                    }

                    Divider().opacity(0.4)

                    HStack {
                        Toggle(isOn: $appModel.settingsDraft.syncIDEConfigs) {
                            Text("新建工作树时自动同步 .vscode / .idea / .env.local 白名单配置")
                                .font(.system(size: 11.5))
                        }
                        Spacer()
                        if appModel.settingsDraft.syncIDEConfigs {
                            Button("恢复默认") {
                                appModel.settingsDraft.ideConfigSyncItemsText = ConfigService.defaultIDEConfigSyncItems.joined(separator: ", ")
                            }
                            .controlSize(.small)
                        }
                    }

                    if appModel.settingsDraft.syncIDEConfigs {
                        TextField(".vscode/settings.json, .env.local, ...", text: $appModel.settingsDraft.ideConfigSyncItemsText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
            }

            SectionCard(title: "默认终端与启动动作钩子") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("配置「终端打开」唤起的终端模拟器及初始化命令。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("重新扫描") { appModel.refreshScannedTerminals() }.controlSize(.small)
                        Button("测试打开终端") { appModel.testOpenTerminal() }.controlSize(.small)
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("预设终端")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Picker("预设终端", selection: terminalSelectionBinding) {
                                Section("已安装终端 (\(appModel.scannedTerminals.filter(\.isInstalled).count))") {
                                    ForEach(appModel.scannedTerminals.filter(\.isInstalled)) { term in
                                        Text("● \(term.displayName)").tag(term.name)
                                    }
                                }
                                let uninstalled = appModel.scannedTerminals.filter { !$0.isInstalled }
                                if !uninstalled.isEmpty {
                                    Section("其他常见终端") {
                                        ForEach(uninstalled) { term in
                                            Text("○ \(term.displayName) (未安装)").tag(term.name)
                                        }
                                    }
                                }
                                Section("自定义") { Text("自定义终端...").tag("Custom") }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("终端名称 / 命令")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("终端名称 / 命令", text: $appModel.settingsDraft.terminalApp)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Bundle ID (可选)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("com.apple.Terminal", text: $appModel.settingsDraft.terminalBundleID)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("启动动作")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Picker("启动动作", selection: $appModel.settingsDraft.terminalLaunchHookMode) {
                                Text("仅进入目录 (cd)").tag("none")
                                Text("进入目录后执行命令").tag("command")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if appModel.settingsDraft.terminalLaunchHookMode == "command" {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("启动后执行命令")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("启动命令，例如: git status", text: $appModel.settingsDraft.terminalLaunchCommand)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tab 4: AI Branch Naming

    private var aiSection: some View {
        @Bindable var appModel = appModel

        return SectionCard(title: "AI 智能分支命名端点") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusPill(title: appModel.settingsDraft.aiProvider.uppercased(), tint: .blue)
                    StatusPill(
                        title: appModel.settingsDraft.aiAPIKey.isEmpty ? "未配置 Key" : "已配置 Key",
                        tint: appModel.settingsDraft.aiAPIKey.isEmpty ? .orange : .green
                    )
                    Spacer()
                    Button {
                        Task { await appModel.testAIConnection() }
                    } label: {
                        Label("测试 AI 握手", systemImage: "bolt.fill")
                    }
                    .controlSize(.small)
                    .disabled(appModel.settingsDraft.aiBaseURL.isEmpty)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("服务商预设")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("服务商预设", selection: aiProviderSelectionBinding) {
                            ForEach(AIProviderPreset.allPresets) { preset in
                                Text(preset.displayName).tag(preset.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("模型名称 (Model)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("模型名称", text: $appModel.settingsDraft.aiModel)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11.5, design: .monospaced))
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("API Base URL")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("https://api.deepseek.com", text: $appModel.settingsDraft.aiBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11.5, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("API Key")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        if appModel.settingsTokenVisible {
                            TextField("输入 API Key (如 sk-...)", text: $appModel.settingsDraft.aiAPIKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))
                        } else {
                            SecureField("输入 API Key (如 sk-...)", text: $appModel.settingsDraft.aiAPIKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))
                        }

                        Button {
                            appModel.settingsTokenVisible.toggle()
                        } label: {
                            Image(systemName: appModel.settingsTokenVisible ? "eye.slash" : "eye")
                                .font(.system(size: 11))
                        }
                        .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("自定义提示词规则 (可选)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !appModel.settingsDraft.aiCustomPrompt.isEmpty {
                            Button("恢复通用默认") {
                                appModel.settingsDraft.aiCustomPrompt = ""
                            }
                            .controlSize(.small)
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                        }
                    }

                    TextField("留空使用通用规范 (feat/..., fix/...)...", text: $appModel.settingsDraft.aiCustomPrompt, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3, reservesSpace: true)
                        .font(.system(size: 11.5, design: .monospaced))
                }
            }
        }
    }

    // MARK: - Tab 5: Merge Policy & Security

    private var policySection: some View {
        @Bindable var appModel = appModel

        return VStack(alignment: .leading, spacing: 16) {
            SectionCard(title: "保护分支与合并重试策略") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("全局额外保护目标分支（逗号分隔）")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("main, master", text: $appModel.settingsDraft.protectedTargetsText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11.5, design: .monospaced))
                        Text("注：各工作区配置中的「生产主干分支」会自动纳入高危合并保护（禁止一键批量自动合入），「非生产保护分支」用于集成同步与批量流转，此处可追加跨工作区通用保护分支。")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("自动合并等待延迟 (秒)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("2", text: $appModel.settingsDraft.autoMergeDelaySecondsText)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("自动合并重试次数")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("3", text: $appModel.settingsDraft.autoMergeRetryCountText)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

            let activeWSIndex = appModel.activeWorkspaceDraftIndex
            let activeWS = activeWSIndex.map { appModel.settingsDraft.workspaces[$0] }
            let shouldShowBranchMappings = activeWS?.platform == .gitlab
                || !(activeWS?.protectedEnvBranchList.isEmpty ?? true)
                || !(activeWS?.branchMappings.isEmpty ?? true)
                || (activeWS == nil && (appModel.activePlatform == .gitlab || !appModel.settingsDraft.gitlabHost.isEmpty))

            if shouldShowBranchMappings {
                let mappingsBinding: Binding<[BranchMappingDraft]> = activeWSIndex.map {
                    $appModel.settingsDraft.workspaces[$0].branchMappings
                } ?? $appModel.settingsDraft.branchMappings

                SectionCard(title: activeWS.map { "环境分支合并映射表 · 当前标签「\($0.name)」" } ?? "环境分支合并映射表 (Branch Mappings)") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("批量创建 MR 与多环境分支同步以此映射为准。")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("基于环境一键生成") {
                                appModel.regenerateBranchMappingsFromEnvironment()
                            }
                            .controlSize(.small)
                            Button("新增映射") {
                                appModel.addBranchMapping()
                            }
                            .controlSize(.small)
                        }

                        if let ws = activeWS {
                            let envsText = ws.protectedEnvBranchList.isEmpty ? "未配置" : ws.protectedEnvBranchList.joined(separator: ", ")
                            let middleText = ws.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "sync" : ws.mergeBranchMiddle
                            let mainText = ws.mainlineBranchList.first ?? "未配置"
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Color.teal)
                                Text("读取「\(ws.name)」分支架构与流转规则：保护分支 [\(envsText)] · 后缀 [\(middleText)] · 主干 [\(mainText)]")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.teal.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        if mappingsBinding.wrappedValue.isEmpty {
                            Text("当前尚未配置任何分支映射，可点击右上角「基于环境一键生成」从分支架构与流转规则自动生成。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(mappingsBinding) { $mapping in
                                HStack(spacing: 8) {
                                    TextField("来源分支", text: $mapping.source)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11.5, design: .monospaced))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    TextField("目标分支", text: $mapping.target)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11.5, design: .monospaced))
                                    Button(role: .destructive) {
                                        appModel.removeBranchMapping(id: mapping.id)
                                    } label: {
                                        Image(systemName: "trash").font(.system(size: 11))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Color.red)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers & Bindings

    private var aiProviderSelectionBinding: Binding<String> {
        Binding(
            get: { appModel.settingsDraft.aiProvider },
            set: { newValue in
                if let preset = AIProviderPreset.allPresets.first(where: { $0.id == newValue }) {
                    appModel.selectAIProviderPreset(preset)
                } else {
                    appModel.settingsDraft.aiProvider = newValue
                }
            }
        )
    }

    private var currentPathTemplatePreview: String {
        appModel.resolveWorktreePathTemplate(
            template: appModel.settingsDraft.worktreePathTemplate,
            rootDir: appModel.settingsDraft.worktreesRootDir.isEmpty ? "/Users/dev/worktrees" : appModel.settingsDraft.worktreesRootDir,
            projectName: "my-repo",
            branchName: "feat-pay-retry"
        )
    }

    private var pathPresetBinding: Binding<String> {
        Binding(
            get: {
                let current = appModel.settingsDraft.worktreePathTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
                if current == "${rootDir}/${project}/${branch}" || current == "${rootDir}/${project}_${branch}" || current == "${rootDir}/${branch}" {
                    return current
                }
                return "custom"
            },
            set: { newValue in
                if newValue != "custom" {
                    appModel.settingsDraft.worktreePathTemplate = newValue
                }
            }
        )
    }

    private var terminalSelectionBinding: Binding<String> {
        Binding(
            get: {
                let current = appModel.settingsDraft.terminalApp
                if let matched = appModel.scannedTerminals.first(where: {
                    $0.name.caseInsensitiveCompare(current) == .orderedSame ||
                    $0.displayName.caseInsensitiveCompare(current) == .orderedSame
                }) {
                    return matched.name
                }
                return "Custom"
            },
            set: { newValue in
                if let matched = appModel.scannedTerminals.first(where: { $0.name.caseInsensitiveCompare(newValue) == .orderedSame }) {
                    appModel.selectTerminal(matched)
                } else if newValue != "Custom" {
                    appModel.settingsDraft.terminalApp = newValue
                }
            }
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
