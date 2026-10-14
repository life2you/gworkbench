import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case worktrees = "本地与工作树"
    case accounts = "平台凭据连接池"
    case presets = "发布策略模板"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .worktrees: return "folder.fill"
        case .accounts: return "globe.americas.fill"
        case .presets: return "arrow.triangle.branch"
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedTab: SettingsTab = .worktrees
    @State private var selectedPresetTab: String = "env_flow"

    var body: some View {
        @Bindable var appModel = appModel

        VStack(spacing: 0) {
            toolbarHeader
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if appModel.settingsOperation.isRunning || appModel.settingsOperation.errorMessage != nil || appModel.settingsOperation.successMessage != nil {
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
                    case .worktrees:
                        worktreesSection
                    case .accounts:
                        accountsSection
                    case .presets:
                        presetsSection
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Toolbar Header

    private var toolbarHeader: some View {
        HStack(spacing: 12) {
            Picker("设置分组", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.systemImage).tag(tab)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 380)

            Spacer()

            Button {
                Task { await appModel.reloadSettingsOnly() }
            } label: {
                Label("重新加载", systemImage: "arrow.clockwise")
            }
            .help("丢弃未保存的草稿，重新从本地 config.toml 读取")

            Button {
                Task { await appModel.saveSettings() }
            } label: {
                Label("保存设置", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .disabled(appModel.settingsOperation.isRunning)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Tab 1: 本地与工作树 (涵盖 点 4 终端钩子、点 5 路径模板)

    private var worktreesSection: some View {
        @Bindable var appModel = appModel

        return VStack(alignment: .leading, spacing: 18) {
            // 卡片 1: 本地代码扫描根目录
            SectionCard(title: "代码仓库扫描根目录 (Projects Root Dirs)") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("决定「工作树」和「分支同步」页面能扫描到哪些本地 Git 仓库（支持多个目录，如公司目录与 GitHub 目录）。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("添加目录") {
                            if let path = chooseDirectory() {
                                appModel.addWorktreeProjectsRoot(path)
                            }
                        }
                        .controlSize(.small)
                    }

                    ForEach($appModel.settingsDraft.worktreeProjectsRootDirs) { $entry in
                        HStack(spacing: 8) {
                            TextField("项目根目录路径", text: $entry.path)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))

                            Button(role: .destructive) {
                                appModel.removeWorktreeProjectsRoot(id: entry.id)
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

            // 卡片 2: 工作树存储路径与通配符命名模板 (解决局限性 5)
            SectionCard(title: "工作树存储路径与命名模板 (Worktrees Storage & Template)") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("工作树默认存储根目录 (Worktrees Root Dir)")
                            .font(.system(size: 12, weight: .medium))
                        Text("新建 worktree 时在磁盘上统一落盘的基础目录。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

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

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("路径生成模式与通配符模板")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("支持变量: ${rootDir}, ${project}, ${branch}, ${date}")
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 12) {
                            Picker("路径预设", selection: pathPresetBinding) {
                                Text("分层目录: ${project}/${branch}").tag("${rootDir}/${project}/${branch}")
                                Text("前缀扁平: ${project}_${branch}").tag("${rootDir}/${project}_${branch}")
                                Text("纯分支扁平: ${branch}").tag("${rootDir}/${branch}")
                                Text("自定义格式...").tag("custom")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 220)

                            TextField("通配符格式表达式", text: $appModel.settingsDraft.worktreePathTemplate)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))
                        }

                        // 实时效果预览气泡
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.accentColor)
                            Text("落盘预览示例:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(currentPathTemplatePreview)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor.opacity(0.25), lineWidth: 0.5)
                        )
                    }
                }
            }

            // 卡片 3: 默认终端集成与启动动作钩子 (解决局限性 4)
            SectionCard(title: "默认终端与启动动作钩子 (Terminal & Launch Actions)") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("决定所有「在终端打开」与「在终端执行脚本」功能唤起的终端模拟器。自动扫描本地已安装终端。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            appModel.refreshScannedTerminals()
                        } label: {
                            Label("重新扫描", systemImage: "arrow.clockwise")
                        }
                        .controlSize(.small)

                        Button {
                            appModel.testOpenTerminal()
                        } label: {
                            Label("测试打开终端", systemImage: "terminal")
                        }
                        .controlSize(.small)
                    }

                    HStack(spacing: 12) {
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

                            Section("自定义") {
                                Text("自定义终端...").tag("Custom")
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)

                        TextField("终端 App 名称 / 命令", text: $appModel.settingsDraft.terminalApp)
                            .textFieldStyle(.roundedBorder)

                        TextField("Bundle Identifier (可选)", text: $appModel.settingsDraft.terminalBundleID)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11.5, design: .monospaced))
                    }

                    // 快速点选已安装胶囊
                    let installed = appModel.scannedTerminals.filter(\.isInstalled)
                    if !installed.isEmpty {
                        HStack(spacing: 8) {
                            Text("已检测到可用终端:")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)

                            ForEach(installed) { term in
                                let isSelected = appModel.settingsDraft.terminalApp.caseInsensitiveCompare(term.name) == .orderedSame

                                Button {
                                    appModel.selectTerminal(term)
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                        Text(term.displayName)
                                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(isSelected ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor))
                                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1 : 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider().opacity(0.4)

                    // 终端启动动作与自动化钩子命令 (点 4)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("唤起终端时的初始动作 (Startup Hook)")
                            .font(.system(size: 12, weight: .medium))
                        Text("点击“在终端打开”时，可以在新窗口进入目录后自动执行特定命令。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Picker("动作模式", selection: $appModel.settingsDraft.terminalLaunchHookMode) {
                                Text("仅进入目录 (cd)").tag("none")
                                Text("进入目录后执行命令").tag("command")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 170)

                            if appModel.settingsDraft.terminalLaunchHookMode == "command" {
                                TextField("启动执行命令，例如: git status 或 pnpm dev", text: $appModel.settingsDraft.terminalLaunchCommand)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11.5, design: .monospaced))
                            }
                        }
                    }
                }
            }

            // 卡片 4: IDE 编辑器外部集成
            SectionCard(title: "IDE 编辑器外部集成 (IDE Integration)") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("配置点击在 IDE 中打开时的外部编辑器联动模式。自动检测本地安装的 Zed、IntelliJ IDEA、VS Code、Xcode 等。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            appModel.refreshScannedIDEs()
                        } label: {
                            Label("重新扫描", systemImage: "arrow.clockwise")
                        }
                        .controlSize(.small)

                        Button {
                            appModel.testOpenIDE()
                        } label: {
                            Label("测试打开 IDE", systemImage: "arrow.up.forward.app")
                        }
                        .controlSize(.small)
                    }

                    HStack(spacing: 12) {
                        Picker("预设编辑器", selection: ideSelectionBinding) {
                            Section("已安装编辑器 (\(appModel.scannedIDEs.filter(\.isInstalled).count))") {
                                ForEach(appModel.scannedIDEs.filter(\.isInstalled)) { ide in
                                    Text("● \(ide.displayName)").tag(ide.name)
                                }
                            }

                            let uninstalled = appModel.scannedIDEs.filter { !$0.isInstalled }
                            if !uninstalled.isEmpty {
                                Section("其他常见编辑器") {
                                    ForEach(uninstalled) { ide in
                                        Text("○ \(ide.displayName) (未安装)").tag(ide.name)
                                    }
                                }
                            }

                            Section("自定义") {
                                Text("自定义编辑器...").tag("Custom")
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)

                        Picker("IDE 模式", selection: $appModel.settingsDraft.ideMode) {
                            Text("app (应用)").tag("app")
                            Text("system (系统默认)").tag("system")
                            Text("custom (自定义命令)").tag("custom")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)

                        TextField("App 名称 / 命令", text: $appModel.settingsDraft.ideCommand)
                            .textFieldStyle(.roundedBorder)

                        TextField("显示标签", text: $appModel.settingsDraft.ideLabel)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 快速点选已安装 IDE 胶囊
                    let installed = appModel.scannedIDEs.filter(\.isInstalled)
                    if !installed.isEmpty {
                        HStack(spacing: 8) {
                            Text("已检测到可用编辑器:")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)

                            ForEach(installed) { ide in
                                let isSelected = appModel.settingsDraft.ideCommand.caseInsensitiveCompare(ide.name) == .orderedSame

                                Button {
                                    appModel.selectIDE(ide)
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                        Text(ide.displayName)
                                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(isSelected ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor))
                                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1 : 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let matched = appModel.scannedIDEs.first(where: { $0.name.caseInsensitiveCompare(appModel.settingsDraft.ideCommand) == .orderedSame }), matched.isInstalled {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("安装路径:")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                            Text(matched.locationDescription)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 1)
                    }
                }
            }
        }
    }

    // MARK: - Tab 2: 平台凭据连接池 (解决局限性 1)

    private var accountsSection: some View {
        @Bindable var appModel = appModel

        return VStack(alignment: .leading, spacing: 18) {
            SectionCard(title: "托管平台凭据连接池 (Accounts & Connections Pool)") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("统一管理公司的私有 GitLab 与 GitHub 凭据，根据仓库 Remote URL 自动路由，无需为每个项目繁琐指定。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    // 实例 1: 私有 GitLab
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "shippingbox.fill")
                                    .foregroundStyle(Color.orange)
                                Text("公司私有 GitLab 实例")
                                    .font(.system(size: 12.5, weight: .semibold))
                                StatusPill(title: "私有 GitLab", tint: .orange)
                                StatusPill(title: appModel.settingsDraft.gitlabHost.isEmpty ? "未配置" : "已配置", tint: .green)
                            }
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("GitLab 服务器地址 (Host)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("例如: http://172.16.12.246:8099", text: $appModel.settingsDraft.gitlabHost)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("GitLab 个人访问令牌 (Personal Access Token)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                if appModel.settingsTokenVisible {
                                    TextField("GitLab Access Token", text: $appModel.settingsDraft.gitlabToken)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11.5, design: .monospaced))
                                } else {
                                    SecureField("GitLab Access Token", text: $appModel.settingsDraft.gitlabToken)
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
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
                    )

                    // 实例 2: GitHub 官方
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "globe.americas.fill")
                                    .foregroundStyle(Color.purple)
                                Text("GitHub 个人与开源工作区")
                                    .font(.system(size: 12.5, weight: .semibold))
                                StatusPill(title: "GitHub", tint: .purple)
                                StatusPill(title: "自动匹配 github.com", tint: .green)
                            }
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("GitHub 个人访问令牌 (Personal Access Token - 可选)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("可选填入 GitHub PAT，默认优先继承系统 gh 认证凭据", text: $appModel.settingsDraft.githubToken)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
                    )

                    // 实例 3: AI 智能助手凭据与模型端点 (基于 OpenAI 规范)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Color.blue)
                                Text("AI 智能助手模型端点 (AI Branch Assistant)")
                                    .font(.system(size: 12.5, weight: .semibold))
                                StatusPill(title: appModel.settingsDraft.aiProvider.uppercased(), tint: .blue)
                                StatusPill(title: appModel.settingsDraft.aiAPIKey.isEmpty ? "未配置 Key" : "已配置 Key", tint: appModel.settingsDraft.aiAPIKey.isEmpty ? .orange : .green)
                            }
                            Spacer()

                            Button {
                                Task {
                                    await appModel.testAIConnection()
                                }
                            } label: {
                                Label("测试 AI 握手", systemImage: "bolt.fill")
                            }
                            .controlSize(.small)
                            .disabled(appModel.settingsDraft.aiBaseURL.isEmpty)
                        }

                        Text("为新建工作树提供根据功能描述自动生成 Git 英文规范分支名（支持 DeepSeek、OpenAI、Kimi、通义千问或本地私有 Ollama）。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Picker("服务商预设", selection: aiProviderSelectionBinding) {
                                ForEach(AIProviderPreset.allPresets) { preset in
                                    Text(preset.displayName).tag(preset.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 220)

                            TextField("API Base URL (如: https://api.deepseek.com)", text: $appModel.settingsDraft.aiBaseURL)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))

                            TextField("模型名称 (如: deepseek-chat)", text: $appModel.settingsDraft.aiModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))
                                .frame(width: 170)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("API 密钥 (API Key / Bearer Token)")
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

                        Divider().opacity(0.4)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("自定义提示词规则 / 偏好约定 (Custom System Prompt)")
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

                            TextField(
                                "留空使用通用标准软件开发规范。可在此处填入您团队的特殊偏好（如：词汇映射、缩写口令、JIRA/TAPD 编号格式或特定技术栈约定）...",
                                text: $appModel.settingsDraft.aiCustomPrompt,
                                axis: .vertical
                            )
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3, reservesSpace: true)
                            .font(.system(size: 11.5, design: .monospaced))

                            Text("留空时使用通用软件工程标准（核心动词 + 业务主体，全小写 kebab-case，不包含任何特定业务硬编码）。若填入内容则完全优先按您的自定义规则驱动。")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
                    )

                    // 智能路由机制提示卡片
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.accentColor)
                        Text("智能自动路由：当您操作仓库时，系统自动提取其 remote origin URL 的域名。若匹配 github.com 自动调度 GitHub 凭据；若匹配 172.16.12.246 自动调度私有 GitLab 凭据，完全零手动切换负担。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                    .padding(10)
                    .background(Color.accentColor.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Tab 3: 发布策略模板 (解决局限性 2，且内聚分支合并映射)

    private var presetsSection: some View {
        @Bindable var appModel = appModel

        return VStack(alignment: .leading, spacing: 18) {
            SectionCard(title: "发布与合流策略模板 (Workflow & Merge Presets)") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("按托管平台或业务类型定制分支合流策略，私有 GitLab 采用公司环境流，GitHub 采用标准主干流。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    // 模板切换分段控件
                    Picker("策略模板", selection: $selectedPresetTab) {
                        Text("🦊 模板 A：公司环境合流流 (企业模式)").tag("env_flow")
                        Text("🐙 模板 B：GitHub 标准主干/PR 流").tag("github")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 440)

                    if selectedPresetTab == "env_flow" {
                        // 模板 A 表单
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top, spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("中间段 (merge_middle)")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("默认合并分支中间段，如 uat 生成 uat_henry_meger")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                    TextField("merge_branch_middle", text: $appModel.settingsDraft.mergeBranchMiddle)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11.5, design: .monospaced))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("环境分支列表")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("发布链路中的环境名列表，逗号分隔")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                    TextField("如: uat, test, stage, pre_prod", text: $appModel.settingsDraft.envBranchesText)
                                        .textFieldStyle(.roundedBorder)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("保护目标分支")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("命中时自动合并策略将更谨慎")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                    TextField("如: master", text: $appModel.settingsDraft.protectedTargetsText)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            Divider().opacity(0.4)

                            HStack(alignment: .top, spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("自动合并等待延迟 (秒)")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("调用 merge 前等待秒数，为 pipeline 留时间")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                    TextField("等待秒数", text: $appModel.settingsDraft.autoMergeDelaySecondsText)
                                        .textFieldStyle(.roundedBorder)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("自动合并重试次数")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("merge 遭遇临时错误时重试次数")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                    TextField("重试次数", text: $appModel.settingsDraft.autoMergeRetryCountText)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            Divider().opacity(0.4)

                            // 内聚在公司环境流下的分支合并映射表！
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("环境分支合并映射表 (Branch Mappings)")
                                            .font(.system(size: 12, weight: .medium))
                                        Text("基于上述中间段与环境分支生成，批量创建 MR 和分支同步直接以此表为准。")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()

                                    Button {
                                        appModel.regenerateBranchMappingsFromEnvironment()
                                    } label: {
                                        Label("基于上方环境一键生成", systemImage: "arrow.triangle.2.circlepath")
                                    }
                                    .controlSize(.small)
                                    .help("根据上方填写的中间段和环境分支自动重建整套映射")

                                    Button {
                                        appModel.addBranchMapping()
                                    } label: {
                                        Label("新增映射", systemImage: "plus")
                                    }
                                    .controlSize(.small)
                                }

                                // 快捷复用环境分支胶囊栏
                                HStack(spacing: 6) {
                                    Text("快速添加环境目标:")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)

                                    ForEach(appModel.currentDraftTargetBranchOptions, id: \.self) { env in
                                        Button {
                                            appModel.addBranchMapping(target: env)
                                        } label: {
                                            HStack(spacing: 3) {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 8))
                                                Text(env)
                                                    .font(.system(size: 10.5, design: .monospaced))
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }
                                        .buttonStyle(.plain)
                                        .help("点击快速为 \(env) 创建映射")
                                    }
                                }
                                .padding(.vertical, 2)

                                if appModel.settingsDraft.branchMappings.isEmpty {
                                    Text("当前尚未配置任何分支映射，可点击上方「基于环境一键生成」。")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach($appModel.settingsDraft.branchMappings) { $mapping in
                                            HStack(spacing: 10) {
                                                TextField("来源分支 (Source)", text: $mapping.source)
                                                    .textFieldStyle(.roundedBorder)
                                                    .font(.system(size: 11.5, design: .monospaced))

                                                Image(systemName: "arrow.right")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.secondary)

                                                HStack(spacing: 4) {
                                                    TextField("目标分支 (Target)", text: $mapping.target)
                                                        .textFieldStyle(.roundedBorder)
                                                        .font(.system(size: 11.5, design: .monospaced))

                                                    Menu {
                                                        ForEach(appModel.currentDraftTargetBranchOptions, id: \.self) { option in
                                                            Button(option) {
                                                                mapping.target = option
                                                                let middle = appModel.settingsDraft.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines)
                                                                let actualMid = middle.isEmpty ? "henry" : middle
                                                                if mapping.source.isEmpty || mapping.source.hasSuffix("_meger") {
                                                                    mapping.source = "\(option)_\(actualMid)_meger"
                                                                }
                                                            }
                                                        }
                                                    } label: {
                                                        Image(systemName: "chevron.up.chevron.down")
                                                            .font(.system(size: 9))
                                                            .foregroundStyle(.secondary)
                                                    }
                                                    .menuStyle(.borderlessButton)
                                                    .frame(width: 18)
                                                    .help("从上方环境分支列表中快速挑选")
                                                }

                                                Button(role: .destructive) {
                                                    appModel.removeBranchMapping(id: mapping.id)
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
                        }
                    } else {
                        // 模板 B: GitHub 标准主干流
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("默认集成目标分支 (Target Branch)")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("日常 PR 或合流的目标主干分支，通常为 main 或 master")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                    TextField("默认目标分支", text: $appModel.settingsDraft.githubDefaultTargetBranch)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11.5, design: .monospaced))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("保护分支列表")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("禁止直接强制 push 的主干保护分支")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                    TextField("如: main, release/*", text: $appModel.settingsDraft.protectedTargetsText)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.purple)
                                Text("所有识别为 GitHub 的开源与日常仓库默认应用此标准流程，无需任何多级环境中间段，保持纯粹简洁的 feature ➔ main 合流。")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(Color.purple.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
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
            projectName: "bizark_fin",
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

    private var ideSelectionBinding: Binding<String> {
        Binding(
            get: {
                let current = appModel.settingsDraft.ideCommand
                if let matched = appModel.scannedIDEs.first(where: {
                    $0.name.caseInsensitiveCompare(current) == .orderedSame ||
                    $0.displayName.caseInsensitiveCompare(current) == .orderedSame
                }) {
                    return matched.name
                }
                return "Custom"
            },
            set: { newValue in
                if let matched = appModel.scannedIDEs.first(where: { $0.name.caseInsensitiveCompare(newValue) == .orderedSame }) {
                    appModel.selectIDE(matched)
                } else if newValue == "Custom" {
                    // 保留当前值
                } else {
                    appModel.settingsDraft.ideCommand = newValue
                    appModel.settingsDraft.ideLabel = newValue
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
                } else if newValue == "Custom" {
                    // 保留当前值
                } else {
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
