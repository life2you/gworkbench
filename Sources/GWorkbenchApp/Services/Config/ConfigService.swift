import Foundation
import TOMLKit

struct MetadataEntry: Sendable {
    let projectPath: String
    let branch: String
    let description: String
}

private struct WorktreeMetadataStore: Decodable {
    let descriptions: [WorktreeDescription]

    enum CodingKeys: String, CodingKey {
        case descriptions
    }

    init(descriptions: [WorktreeDescription] = []) {
        self.descriptions = descriptions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.descriptions = try container.decodeIfPresent([WorktreeDescription].self, forKey: .descriptions) ?? []
    }
}

private struct WorktreeDescription: Decodable {
    let project_path: String
    let branch: String
    let description: String
}

private struct GWorkbenchTomlConfig: Decodable {
    struct AppSection: Decodable {
        let active_workspace_id: String?
    }

    struct Worktree: Decodable {
        let projects_root_dirs: [String]?
        let worktrees_root_dir: String?
        let metadata_path: String?
        let path_template: String?
        let ide_mode: String?
        let ide_command: String?
        let ide_label: String?
        let default_ide_id: String?
        let terminal_app: String?
        let terminal_bundle_id: String?
        let terminal_launch_hook_mode: String?
        let terminal_launch_command: String?
        let sync_ide_configs: Bool?
        let ide_config_sync_items: [String]?
    }

    struct GitLab: Decodable {
        let host: String?
        let token: String?
    }

    struct GitHub: Decodable {
        let host: String?
        let token: String?
    }

    struct WorkspaceToml: Decodable {
        let id: String?
        let name: String
        let platform: String
        let projects_root_dirs: [String]?
        let worktrees_root_dir: String?
        let host: String?
        let token: String?
        let default_target_branch: String?
        let mainline_branches: [String]?
        let dashboard_baselines: [String]?
        let env_branches: [String]?
        let merge_branch_middle: String?
        let branch_map: [String: String]?
    }

    struct AI: Decodable {
        let provider: String?
        let base_url: String?
        let api_key: String?
        let model: String?
        let custom_prompt: String?
    }

    struct Merge: Decodable {
        let root_dirs: [String]?
        let merge_branch_middle: String?
        let env_branches: [String]?
        let active_preset: String?
        let active_platform: String?
        let active_workspace_id: String?
        let github_default_target_branch: String?
        let github_dashboard_baselines: [String]?
        let gitlab_dashboard_baselines: [String]?
    }

    struct MergePolicy: Decodable {
        let protected_targets: [String]?
        let auto_merge_delay_seconds: Int?
        let auto_merge_retry_count: Int?
    }

    struct IDEProfileToml: Decodable {
        let id: String?
        let label: String?
        let mode: String?
        let command: String?
    }

    let app: AppSection?
    let worktree: Worktree?
    let gitlab: GitLab?
    let github: GitHub?
    let ai: AI?
    let merge: Merge?
    let branch_map: [String: String]?
    let merge_policy: MergePolicy?
    let workspaces: [WorkspaceToml]?
    let ide_profiles: [IDEProfileToml]?
}

final class ConfigService: Sendable {
    /// IDE 目录配置同步默认白名单。仅包含可以安全跨 worktree 复用的文件，
    /// 排除 workspace.xml（个人会话状态）、shelf/（本地暂存改动）、
    /// .cache/（插件二进制缓存）以及带凭据的插件配置文件。
    static let defaultIDEConfigSyncItems: [String] = [
        ".vscode/settings.json",
        ".vscode/extensions.json",
        ".env.local",
        ".gitignore",
        "misc.xml",
        "compiler.xml",
        "encodings.xml",
        "jarRepositories.xml",
        "vcs.xml"
    ]

    init() {}

    func resolveConfigPath(appName: String, fileName: String) -> String {
        let environment = ProcessInfo.processInfo.environment
        if let xdgConfigHome = environment["XDG_CONFIG_HOME"], !xdgConfigHome.isEmpty {
            return URL(fileURLWithPath: xdgConfigHome)
                .appendingPathComponent(appName)
                .appendingPathComponent(fileName)
                .path
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".config")
            .appendingPathComponent(appName)
            .appendingPathComponent(fileName)
            .path
    }

    func loadTomlFile<T: Decodable>(path: String) throws -> T {
        guard FileManager.default.fileExists(atPath: path) else {
            throw WorkbenchError.message("配置文件不存在: \(path)")
        }
        let content = try String(contentsOfFile: path, encoding: .utf8)
        do {
            return try TOMLDecoder().decode(T.self, from: content)
        } catch {
            throw WorkbenchError.message("TOML 解析失败 (\(path)): \(error.localizedDescription)")
        }
    }

    func defaultWorkbenchConfig(configPath: String) -> GWorkbenchConfig {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let configDirectory = URL(fileURLWithPath: configPath).deletingLastPathComponent().path
        let metadataDefaultPath = (configDirectory as NSString).appendingPathComponent("worktree-metadata.toml")
        return GWorkbenchConfig(
            configPath: configPath,
            metadataPath: metadataDefaultPath,
            worktreeProjectsRootDirs: [],
            worktreesRootDir: (home as NSString).appendingPathComponent("worktrees"),
            worktreePathTemplate: "${rootDir}/${project}/${branch}",
            ideMode: "app",
            ideCommand: "open",
            ideLabel: "默认应用",
            ideProfiles: [
                IDEProfile(id: "default-ide", label: "默认应用", mode: "app", command: "open")
            ],
            defaultIDEProfileID: "default-ide",
            terminalApp: "Terminal",
            terminalBundleID: "com.apple.Terminal",
            terminalLaunchHookMode: "none",
            terminalLaunchCommand: "git status",
            gitlabHost: "",
            gitlabToken: "",
            githubHost: "https://github.com",
            githubToken: "",
            aiProvider: "deepseek",
            aiBaseURL: "https://api.deepseek.com",
            aiAPIKey: "",
            aiModel: "deepseek-chat",
            aiCustomPrompt: "",
            activeWorkflowPreset: "env_flow",
            activePlatform: "",
            activeWorkspaceID: "",
            workspaces: [],
            githubDefaultTargetBranch: "main",
            githubDashboardBaselines: DefaultDashboardBaselines.github,
            gitlabDashboardBaselines: DefaultDashboardBaselines.gitlab,
            mergeRootDirs: [],
            mergeBranchMiddle: "feature",
            envBranches: ["dev", "test", "staging", "prod"],
            branchMap: [:],
            protectedTargets: ["main", "master"],
            autoMergeDelaySeconds: 5,
            autoMergeRetryCount: 3,
            syncIDEConfigs: false,
            ideConfigSyncItems: ConfigService.defaultIDEConfigSyncItems
        )
    }

    func loadOrCreateWorkbenchConfig() throws -> GWorkbenchConfig {
        let configPath = resolveConfigPath(appName: "gworkbench", fileName: "config.toml")
        if FileManager.default.fileExists(atPath: configPath) {
            return try loadWorkbenchConfig()
        }
        let defaultConfig = defaultWorkbenchConfig(configPath: configPath)
        try saveWorkbenchConfig(defaultConfig)
        return defaultConfig
    }

    func loadWorkbenchConfig() throws -> GWorkbenchConfig {
        let configPath = resolveConfigPath(appName: "gworkbench", fileName: "config.toml")
        return try loadWorkbenchConfig(at: configPath)
    }

    func loadWorkbenchConfig(at configPath: String) throws -> GWorkbenchConfig {
        guard FileManager.default.fileExists(atPath: configPath) else {
            return try loadOrCreateWorkbenchConfig()
        }

        let config: GWorkbenchTomlConfig = try loadTomlFile(path: configPath)
        let configDirectory = URL(fileURLWithPath: configPath).deletingLastPathComponent()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let metadataPath = ProcessRunner.expandPath(
            config.worktree?.metadata_path
                ?? configDirectory.appendingPathComponent("worktree-metadata.toml").path
        )
        let envBranches = config.merge?.env_branches ?? ["dev", "test", "staging"]
        let mergeBranchMiddle = config.merge?.merge_branch_middle?.trimmedNonEmpty ?? "sync"
        let branchMap = config.branch_map ?? Dictionary(
            uniqueKeysWithValues: envBranches.map { ("\($0)_\(mergeBranchMiddle)", $0) }
        )

        let expandedProjectRoots = (config.worktree?.projects_root_dirs ?? []).map(ProcessRunner.expandPath)
        let expandedMergeRoots = (config.merge?.root_dirs ?? []).map(ProcessRunner.expandPath)
        let githubBaselines = (config.merge?.github_dashboard_baselines?.filterNonEmpty()).flatMap { $0.isEmpty ? nil : $0 } ?? DefaultDashboardBaselines.github
        let gitlabBaselines = (config.merge?.gitlab_dashboard_baselines?.filterNonEmpty()).flatMap { $0.isEmpty ? nil : $0 } ?? DefaultDashboardBaselines.gitlab
        let gitlabHost = config.gitlab?.host ?? ""
        let gitlabToken = config.gitlab?.token ?? ""
        let githubHost = config.github?.host?.trimmedNonEmpty ?? "https://github.com"
        let githubToken = config.github?.token ?? ""
        let githubDefaultBranch = config.merge?.github_default_target_branch ?? "main"

        var parsedWorkspaces: [WorkspaceProfile] = (config.workspaces ?? []).map { ws in
            let platform: RepositoryPlatform = ws.platform.lowercased() == "gitlab" ? .gitlab : .github
            let wsBaselines = (ws.dashboard_baselines?.filterNonEmpty()).flatMap { $0.isEmpty ? nil : $0 }
                ?? (platform == .gitlab ? gitlabBaselines : githubBaselines)
            let mainlines: [String]
            if let explicitMainlines = ws.mainline_branches {
                mainlines = explicitMainlines.filterNonEmpty()
            } else if let defaultTarget = ws.default_target_branch?.trimmedNonEmpty {
                mainlines = [defaultTarget]
            } else {
                mainlines = [platform == .github ? githubDefaultBranch : "master"]
            }
            return WorkspaceProfile(
                id: ws.id?.trimmedNonEmpty ?? UUID().uuidString,
                name: ws.name,
                platform: platform,
                projectsRootDirs: (ws.projects_root_dirs ?? []).map(ProcessRunner.expandPath),
                worktreesRootDir: ws.worktrees_root_dir.map(ProcessRunner.expandPath) ?? "",
                host: ws.host ?? (platform == .github ? "https://github.com" : ""),
                token: ws.token ?? "",
                defaultTargetBranch: mainlines.first ?? "",
                mainlineBranches: mainlines,
                dashboardBaselines: wsBaselines,
                envBranches: ws.env_branches ?? (platform == .gitlab ? envBranches : []),
                mergeBranchMiddle: ws.merge_branch_middle ?? mergeBranchMiddle,
                branchMap: ws.branch_map ?? [:]
            )
        }

        if parsedWorkspaces.isEmpty {
            parsedWorkspaces = migrateLegacyWorkspaces(
                projectRoots: expandedProjectRoots.isEmpty ? expandedMergeRoots : expandedProjectRoots,
                gitlabHost: gitlabHost,
                gitlabToken: gitlabToken,
                githubHost: githubHost,
                githubToken: githubToken,
                githubDefaultTargetBranch: githubDefaultBranch,
                githubBaselines: githubBaselines,
                gitlabBaselines: gitlabBaselines,
                envBranches: envBranches,
                mergeBranchMiddle: mergeBranchMiddle,
                branchMap: branchMap
            )
        }

        let resolvedActiveWorkspaceID: String
        if let configuredID = (config.app?.active_workspace_id?.trimmedNonEmpty ?? config.merge?.active_workspace_id?.trimmedNonEmpty),
           parsedWorkspaces.contains(where: { $0.id == configuredID }) {
            resolvedActiveWorkspaceID = configuredID
        } else if let rawPlatform = config.merge?.active_platform?.trimmedNonEmpty,
                  let matchedByPlatform = parsedWorkspaces.first(where: {
                      ($0.platform == .gitlab && rawPlatform.lowercased() == "gitlab")
                          || ($0.platform == .github && rawPlatform.lowercased() == "github")
                          || $0.platform.rawValue == rawPlatform
                  }) {
            resolvedActiveWorkspaceID = matchedByPlatform.id
        } else {
            resolvedActiveWorkspaceID = parsedWorkspaces.first?.id ?? ""
        }

        let legacyIDEMode = config.worktree?.ide_mode ?? "app"
        let legacyIDECommand = config.worktree?.ide_command ?? "open"
        let legacyIDELabel = config.worktree?.ide_label ?? (config.worktree?.ide_command ?? "默认应用")
        let parsedIDEProfiles: [IDEProfile] = (config.ide_profiles ?? []).enumerated().compactMap { index, item in
            let cmd = (item.command ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let mode = (item.mode ?? "app").trimmingCharacters(in: .whitespacesAndNewlines)
            let label = (item.label ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cmd.isEmpty || !label.isEmpty || mode == "system" else { return nil }
            let resolvedID = (item.id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return IDEProfile(
                id: resolvedID.isEmpty ? "ide-\(index + 1)" : resolvedID,
                label: label.isEmpty ? (cmd.isEmpty ? "默认应用" : cmd) : label,
                mode: mode.isEmpty ? "app" : mode,
                command: cmd.isEmpty ? "open" : cmd
            )
        }
        let effectiveIDEProfiles = parsedIDEProfiles.isEmpty
            ? [IDEProfile(id: "default-ide", label: legacyIDELabel, mode: legacyIDEMode, command: legacyIDECommand)]
            : parsedIDEProfiles
        let resolvedDefaultIDEID = (config.worktree?.default_ide_id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultIDE = effectiveIDEProfiles.first(where: { $0.id == resolvedDefaultIDEID }) ?? effectiveIDEProfiles[0]

        let firstGitLabWS = parsedWorkspaces.first(where: { $0.platform == .gitlab })
        let firstGitHubWS = parsedWorkspaces.first(where: { $0.platform == .github })
        let activeWS = parsedWorkspaces.first(where: { $0.id == resolvedActiveWorkspaceID }) ?? parsedWorkspaces.first
        let combinedWorkspaceRoots = dedupe(parsedWorkspaces.flatMap(\.projectsRootDirs))
        let resolvedProjectRoots = combinedWorkspaceRoots.isEmpty ? expandedProjectRoots : combinedWorkspaceRoots
        let resolvedMergeRoots = combinedWorkspaceRoots.isEmpty ? expandedMergeRoots : combinedWorkspaceRoots

        return GWorkbenchConfig(
            configPath: configPath,
            metadataPath: metadataPath,
            worktreeProjectsRootDirs: resolvedProjectRoots,
            worktreesRootDir: ProcessRunner.expandPath(config.worktree?.worktrees_root_dir ?? (home as NSString).appendingPathComponent("worktrees")),
            worktreePathTemplate: config.worktree?.path_template ?? "${rootDir}/${project}/${branch}",
            ideMode: defaultIDE.mode,
            ideCommand: defaultIDE.command,
            ideLabel: defaultIDE.effectiveLabel,
            ideProfiles: effectiveIDEProfiles,
            defaultIDEProfileID: defaultIDE.id,
            terminalApp: config.worktree?.terminal_app ?? "Terminal",
            terminalBundleID: config.worktree?.terminal_bundle_id ?? "com.apple.Terminal",
            terminalLaunchHookMode: config.worktree?.terminal_launch_hook_mode ?? "none",
            terminalLaunchCommand: config.worktree?.terminal_launch_command ?? "git status",
            gitlabHost: firstGitLabWS?.host ?? gitlabHost,
            gitlabToken: firstGitLabWS?.token ?? gitlabToken,
            githubHost: firstGitHubWS?.host ?? githubHost,
            githubToken: firstGitHubWS?.token ?? githubToken,
            aiProvider: config.ai?.provider ?? "deepseek",
            aiBaseURL: config.ai?.base_url ?? "https://api.deepseek.com",
            aiAPIKey: config.ai?.api_key ?? "",
            aiModel: config.ai?.model ?? "deepseek-chat",
            aiCustomPrompt: config.ai?.custom_prompt ?? "",
            activeWorkflowPreset: config.merge?.active_preset ?? "env_flow",
            activePlatform: activeWS?.platform.rawValue ?? (config.merge?.active_platform ?? ""),
            activeWorkspaceID: resolvedActiveWorkspaceID,
            workspaces: parsedWorkspaces,
            githubDefaultTargetBranch: firstGitHubWS?.effectiveMainlineBranches.first ?? githubDefaultBranch,
            githubDashboardBaselines: firstGitHubWS?.effectiveDashboardBaselines ?? githubBaselines,
            gitlabDashboardBaselines: firstGitLabWS?.effectiveDashboardBaselines ?? gitlabBaselines,
            mergeRootDirs: resolvedMergeRoots,
            mergeBranchMiddle: firstGitLabWS?.mergeBranchMiddle ?? mergeBranchMiddle,
            envBranches: firstGitLabWS?.envBranches ?? envBranches,
            branchMap: firstGitLabWS?.branchMap ?? branchMap,
            protectedTargets: config.merge_policy?.protected_targets ?? ["master", "main"],
            autoMergeDelaySeconds: config.merge_policy?.auto_merge_delay_seconds ?? 10,
            autoMergeRetryCount: config.merge_policy?.auto_merge_retry_count ?? 3,
            syncIDEConfigs: config.worktree?.sync_ide_configs ?? false,
            ideConfigSyncItems: config.worktree?.ide_config_sync_items ?? ConfigService.defaultIDEConfigSyncItems
        )
    }

    func saveWorkbenchConfig(_ config: GWorkbenchConfig) throws {
        let configPath = resolveConfigPath(appName: "gworkbench", fileName: "config.toml")
        let normalized = normalizeWorkbenchConfig(config, configPath: configPath)
        let configURL = URL(fileURLWithPath: configPath)
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try serializeWorkbenchConfig(normalized).write(to: configURL, atomically: true, encoding: .utf8)
    }

    func normalizeWorkbenchConfig(_ config: GWorkbenchConfig, configPath: String) -> GWorkbenchConfig {
        let configDirectory = URL(fileURLWithPath: configPath).deletingLastPathComponent()
        let metadataDefaultPath = configDirectory.appendingPathComponent("worktree-metadata.toml").path
        let normalizedWorkspaces = config.workspaces.map { ws in
            let normalizedHost = ws.platform == .gitlab
                ? normalizedGitLabHost(ws.host)
                : (normalizedGitLabHost(ws.host).isEmpty ? "https://github.com" : normalizedGitLabHost(ws.host))
            let normalizedMainlines = dedupe(ws.mainlineBranches.filterNonEmpty())
            return WorkspaceProfile(
                id: ws.id.trimmedNonEmpty ?? UUID().uuidString,
                name: ws.name.trimmedNonEmpty ?? (ws.platform == .github ? "GitHub" : "GitLab"),
                platform: ws.platform == .gitlab ? .gitlab : .github,
                projectsRootDirs: dedupe(ws.projectsRootDirs.map(ProcessRunner.expandPath).filterNonEmpty()),
                worktreesRootDir: ws.worktreesRootDir.trimmedNonEmpty.map(ProcessRunner.expandPath) ?? "",
                host: normalizedHost,
                token: ws.token.trimmingCharacters(in: .whitespacesAndNewlines),
                defaultTargetBranch: normalizedMainlines.first ?? "",
                mainlineBranches: normalizedMainlines,
                dashboardBaselines: dedupe(ws.dashboardBaselines.filterNonEmpty()),
                envBranches: dedupe(ws.envBranches.filterNonEmpty()),
                mergeBranchMiddle: ws.mergeBranchMiddle.trimmedNonEmpty ?? "sync",
                branchMap: ws.branchMap.filter { !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            )
        }
        let allWorkspaceRoots = dedupe(normalizedWorkspaces.flatMap(\.projectsRootDirs))
        let fallbackWorktreeRoots = dedupe(config.worktreeProjectsRootDirs.map(ProcessRunner.expandPath).filterNonEmpty())
        let syncedRoots = allWorkspaceRoots.isEmpty ? fallbackWorktreeRoots : allWorkspaceRoots
        let syncedMergeRoots = allWorkspaceRoots.isEmpty ? dedupe(config.mergeRootDirs.map(ProcessRunner.expandPath).filterNonEmpty()) : allWorkspaceRoots
        let activeWS = normalizedWorkspaces.first(where: { $0.id == config.activeWorkspaceID }) ?? normalizedWorkspaces.first
        let firstGitLabWS = normalizedWorkspaces.first(where: { $0.platform == .gitlab })
        let firstGitHubWS = normalizedWorkspaces.first(where: { $0.platform == .github })

        var seenIDEIDs = Set<String>()
        var normalizedIDEProfiles: [IDEProfile] = []
        for (idx, item) in config.effectiveIDEProfiles.enumerated() {
            let trimmedCmd = item.command.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLabel = item.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let mode = item.mode.trimmedNonEmpty ?? "app"
            guard !trimmedCmd.isEmpty || !trimmedLabel.isEmpty || mode == "system" else { continue }
            var id = item.id.trimmedNonEmpty ?? "ide-\(idx + 1)"
            if !seenIDEIDs.insert(id).inserted {
                id = "\(id)-\(idx + 1)"
                seenIDEIDs.insert(id)
            }
            normalizedIDEProfiles.append(IDEProfile(
                id: id,
                label: trimmedLabel.isEmpty ? (trimmedCmd.isEmpty || trimmedCmd == "open" ? "默认应用" : trimmedCmd) : trimmedLabel,
                mode: mode,
                command: trimmedCmd.isEmpty && mode != "custom" ? "open" : trimmedCmd
            ))
        }
        if normalizedIDEProfiles.isEmpty {
            normalizedIDEProfiles = [
                IDEProfile(
                    id: "default-ide",
                    label: config.ideLabel.trimmedNonEmpty ?? (config.ideCommand.trimmedNonEmpty ?? "默认应用"),
                    mode: config.ideMode.trimmedNonEmpty ?? "app",
                    command: config.ideCommand.trimmedNonEmpty ?? "open"
                )
            ]
        }
        let primaryIDE = normalizedIDEProfiles.first(where: { $0.id == config.defaultIDEProfileID }) ?? normalizedIDEProfiles[0]

        return GWorkbenchConfig(
            configPath: configPath,
            metadataPath: ProcessRunner.expandPath(config.metadataPath.trimmedNonEmpty ?? metadataDefaultPath),
            worktreeProjectsRootDirs: syncedRoots,
            worktreesRootDir: ProcessRunner.expandPath(config.worktreesRootDir),
            worktreePathTemplate: config.worktreePathTemplate.trimmedNonEmpty ?? "${rootDir}/${project}/${branch}",
            ideMode: primaryIDE.mode,
            ideCommand: primaryIDE.command,
            ideLabel: primaryIDE.effectiveLabel,
            ideProfiles: normalizedIDEProfiles,
            defaultIDEProfileID: primaryIDE.id,
            terminalApp: config.terminalApp.trimmedNonEmpty ?? "Terminal",
            terminalBundleID: config.terminalBundleID.trimmedNonEmpty ?? "com.apple.Terminal",
            terminalLaunchHookMode: config.terminalLaunchHookMode.trimmedNonEmpty ?? "none",
            terminalLaunchCommand: config.terminalLaunchCommand.trimmedNonEmpty ?? "git status",
            gitlabHost: normalizedGitLabHost(firstGitLabWS?.host ?? config.gitlabHost),
            gitlabToken: (firstGitLabWS?.token ?? config.gitlabToken).trimmingCharacters(in: .whitespacesAndNewlines),
            githubHost: normalizedGitLabHost(firstGitHubWS?.host ?? config.githubHost).isEmpty ? "https://github.com" : normalizedGitLabHost(firstGitHubWS?.host ?? config.githubHost),
            githubToken: (firstGitHubWS?.token ?? config.githubToken).trimmingCharacters(in: .whitespacesAndNewlines),
            aiProvider: config.aiProvider.trimmedNonEmpty ?? "deepseek",
            aiBaseURL: config.aiBaseURL.trimmedNonEmpty ?? "https://api.deepseek.com",
            aiAPIKey: config.aiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
            aiModel: config.aiModel.trimmedNonEmpty ?? "deepseek-chat",
            aiCustomPrompt: config.aiCustomPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            activeWorkflowPreset: config.activeWorkflowPreset.trimmedNonEmpty ?? "env_flow",
            activePlatform: activeWS?.platform.rawValue ?? config.activePlatform.trimmingCharacters(in: .whitespacesAndNewlines),
            activeWorkspaceID: activeWS?.id ?? config.activeWorkspaceID.trimmingCharacters(in: .whitespacesAndNewlines),
            workspaces: normalizedWorkspaces,
            githubDefaultTargetBranch: firstGitHubWS?.defaultTargetBranch.trimmedNonEmpty ?? config.githubDefaultTargetBranch.trimmedNonEmpty ?? "main",
            githubDashboardBaselines: firstGitHubWS?.effectiveDashboardBaselines ?? dedupe(config.githubDashboardBaselines.filterNonEmpty()),
            gitlabDashboardBaselines: firstGitLabWS?.effectiveDashboardBaselines ?? dedupe(config.gitlabDashboardBaselines.filterNonEmpty()),
            mergeRootDirs: syncedMergeRoots,
            mergeBranchMiddle: config.mergeBranchMiddle.trimmedNonEmpty ?? "sync",
            envBranches: dedupe(config.envBranches.filterNonEmpty()),
            branchMap: config.branchMap
                .filter { !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            protectedTargets: dedupe(config.protectedTargets.filterNonEmpty()),
            autoMergeDelaySeconds: max(config.autoMergeDelaySeconds, 0),
            autoMergeRetryCount: max(config.autoMergeRetryCount, 0),
            syncIDEConfigs: config.syncIDEConfigs,
            ideConfigSyncItems: dedupe(
                config.ideConfigSyncItems
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filterNonEmpty()
            )
        )
    }

    private func migrateLegacyWorkspaces(
        projectRoots: [String],
        gitlabHost: String,
        gitlabToken: String,
        githubHost: String,
        githubToken: String,
        githubDefaultTargetBranch: String,
        githubBaselines: [String],
        gitlabBaselines: [String],
        envBranches: [String],
        mergeBranchMiddle: String,
        branchMap: [String: String]
    ) -> [WorkspaceProfile] {
        var githubRoots: [String] = []
        var gitlabRoots: [String] = []
        let fm = FileManager.default

        for root in dedupe(projectRoots.filterNonEmpty()) {
            let expanded = ProcessRunner.expandPath(root)
            var isGitHubRoot = expanded.lowercased().contains("github")
            var isGitLabRoot = expanded.lowercased().contains("gitlab")

            if !isGitHubRoot && !isGitLabRoot,
               let children = try? fm.contentsOfDirectory(atPath: expanded) {
                var ghHits = 0
                var glHits = 0
                for child in children.prefix(20) {
                    let repoPath = (expanded as NSString).appendingPathComponent(child)
                    if let url = GitCliService.readOriginURLFromGitConfig(projectPath: repoPath) {
                        let detected = RepositoryPlatform.detect(remoteURL: url, gitlabHost: gitlabHost)
                        if detected == .github { ghHits += 1 }
                        else if detected == .gitlab { glHits += 1 }
                    }
                }
                if ghHits > 0 && glHits == 0 {
                    isGitHubRoot = true
                } else if glHits > 0 && ghHits == 0 {
                    isGitLabRoot = true
                }
            }

            if isGitHubRoot {
                githubRoots.append(expanded)
            } else {
                gitlabRoots.append(expanded)
            }
        }

        var result: [WorkspaceProfile] = []
        if !githubRoots.isEmpty || !githubToken.isEmpty {
            result.append(
                WorkspaceProfile(
                    id: "ws-github",
                    name: "GitHub",
                    platform: .github,
                    projectsRootDirs: githubRoots,
                    worktreesRootDir: "",
                    host: githubHost.isEmpty ? "https://github.com" : githubHost,
                    token: githubToken,
                    defaultTargetBranch: githubDefaultTargetBranch,
                    dashboardBaselines: githubBaselines,
                    envBranches: [],
                    mergeBranchMiddle: "",
                    branchMap: [:]
                )
            )
        }
        if !gitlabRoots.isEmpty || !gitlabHost.isEmpty || !gitlabToken.isEmpty {
            result.append(
                WorkspaceProfile(
                    id: "ws-gitlab",
                    name: "GitLab",
                    platform: .gitlab,
                    projectsRootDirs: gitlabRoots,
                    worktreesRootDir: "",
                    host: gitlabHost,
                    token: gitlabToken,
                    defaultTargetBranch: "master",
                    dashboardBaselines: gitlabBaselines,
                    envBranches: envBranches,
                    mergeBranchMiddle: mergeBranchMiddle,
                    branchMap: branchMap
                )
            )
        }
        return result
    }

    func serializeWorkbenchConfig(_ config: GWorkbenchConfig) -> String {
        var lines: [String] = [
            "[app]",
            "active_workspace_id = \"\(escapeTomlString(config.activeWorkspaceID))\"",
            "",
            "[worktree]"
        ]

        // 仅在尚未配置任何工作区标签时保留全局回退目录，避免与 [[workspaces]].projects_root_dirs 重复
        if config.workspaces.isEmpty && !config.worktreeProjectsRootDirs.isEmpty {
            lines.append("projects_root_dirs = \(tomlArray(config.worktreeProjectsRootDirs))")
        }

        lines.append(contentsOf: [
            "worktrees_root_dir = \"\(escapeTomlString(config.worktreesRootDir))\"",
            "path_template = \"\(escapeTomlString(config.worktreePathTemplate))\"",
            "metadata_path = \"\(escapeTomlString(config.metadataPath))\"",
            "default_ide_id = \"\(escapeTomlString(config.defaultIDEProfileID))\"",
            "terminal_app = \"\(escapeTomlString(config.terminalApp))\"",
            "terminal_bundle_id = \"\(escapeTomlString(config.terminalBundleID))\"",
            "terminal_launch_hook_mode = \"\(escapeTomlString(config.terminalLaunchHookMode))\"",
            "terminal_launch_command = \"\(escapeTomlString(config.terminalLaunchCommand))\"",
            "sync_ide_configs = \(config.syncIDEConfigs)",
            "ide_config_sync_items = \(tomlArray(config.ideConfigSyncItems))",
            "",
            "[ai]",
            "provider = \"\(escapeTomlString(config.aiProvider))\"",
            "base_url = \"\(escapeTomlString(config.aiBaseURL))\"",
            "api_key = \"\(escapeTomlString(config.aiAPIKey))\"",
            "model = \"\(escapeTomlString(config.aiModel))\"",
            "custom_prompt = \"\(escapeTomlString(config.aiCustomPrompt))\"",
            "",
            "[merge_policy]",
            "protected_targets = \(tomlArray(config.protectedTargets))",
            "auto_merge_delay_seconds = \(config.autoMergeDelaySeconds)",
            "auto_merge_retry_count = \(config.autoMergeRetryCount)",
            ""
        ])

        let ideProfileBlocks = config.effectiveIDEProfiles.flatMap { ide -> [String] in
            [
                "[[ide_profiles]]",
                "id = \"\(escapeTomlString(ide.id))\"",
                "label = \"\(escapeTomlString(ide.effectiveLabel))\"",
                "mode = \"\(escapeTomlString(ide.mode))\"",
                "command = \"\(escapeTomlString(ide.command))\"",
                ""
            ]
        }

        let workspaceBlocks = config.workspaces.flatMap { ws -> [String] in
            var block = [
                "[[workspaces]]",
                "id = \"\(escapeTomlString(ws.id))\"",
                "name = \"\(escapeTomlString(ws.name))\"",
                "platform = \"\(ws.platform == .gitlab ? "gitlab" : "github")\"",
                "projects_root_dirs = \(tomlArray(ws.projectsRootDirs))",
                "worktrees_root_dir = \"\(escapeTomlString(ws.worktreesRootDir))\"",
                "host = \"\(escapeTomlString(ws.host))\"",
                "token = \"\(escapeTomlString(ws.token))\"",
                "mainline_branches = \(tomlArray(ws.configuredMainlineBranches))",
                "dashboard_baselines = \(tomlArray(ws.effectiveDashboardBaselines))",
                "env_branches = \(tomlArray(ws.envBranches))",
                "merge_branch_middle = \"\(escapeTomlString(ws.mergeBranchMiddle))\""
            ]
            if !ws.branchMap.isEmpty {
                let pairs = ws.branchMap
                    .sorted { $0.key < $1.key }
                    .map { "\"\(escapeTomlString($0.key))\" = \"\(escapeTomlString($0.value))\"" }
                    .joined(separator: ", ")
                block.append("branch_map = { \(pairs) }")
            }
            block.append("")
            return block
        }

        return (lines + ideProfileBlocks + workspaceBlocks).joined(separator: "\n")
    }

    func loadWorktreeMetadataMap(metadataPath: String) throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: metadataPath) else {
            return [:]
        }
        let metadata: WorktreeMetadataStore = try loadTomlFile(path: metadataPath)
        return Dictionary(
            uniqueKeysWithValues: metadata.descriptions.map {
                ("\(ProcessRunner.normalizePath($0.project_path))#\($0.branch)", $0.description)
            }
        )
    }

    func saveWorktreeDescription(
        metadataPath: String,
        projectPath: String,
        branch: String,
        description: String
    ) throws {
        let normalizedProjectPath = ProcessRunner.normalizePath(projectPath)
        var entries = try loadMetadataEntries(metadataPath: metadataPath)
        entries.removeAll { $0.projectPath == normalizedProjectPath && $0.branch == branch }
        entries.append(.init(projectPath: normalizedProjectPath, branch: branch, description: description))
        try writeMetadataEntries(entries, metadataPath: metadataPath)
    }

    func clearWorktreeDescription(
        metadataPath: String,
        projectPath: String,
        branch: String
    ) throws {
        let normalizedProjectPath = ProcessRunner.normalizePath(projectPath)
        var entries = try loadMetadataEntries(metadataPath: metadataPath)
        entries.removeAll { $0.projectPath == normalizedProjectPath && $0.branch == branch }
        try writeMetadataEntries(entries, metadataPath: metadataPath)
    }

    func loadMetadataEntries(metadataPath: String) throws -> [MetadataEntry] {
        guard FileManager.default.fileExists(atPath: metadataPath) else {
            return []
        }
        let metadata: WorktreeMetadataStore = try loadTomlFile(path: metadataPath)
        return metadata.descriptions.map {
            MetadataEntry(
                projectPath: ProcessRunner.normalizePath($0.project_path),
                branch: $0.branch,
                description: $0.description
            )
        }
    }

    func writeMetadataEntries(_ entries: [MetadataEntry], metadataPath: String) throws {
        let sortedEntries = entries.sorted {
            if $0.projectPath != $1.projectPath {
                return $0.projectPath < $1.projectPath
            }
            return $0.branch < $1.branch
        }

        let lines = sortedEntries.flatMap { entry in
            [
                "[[descriptions]]",
                "project_path = \"\(escapeTomlString(entry.projectPath))\"",
                "branch = \"\(escapeTomlString(entry.branch))\"",
                "description = \"\(escapeTomlString(entry.description))\"",
                ""
            ]
        }

        let metadataURL = URL(fileURLWithPath: metadataPath)
        try FileManager.default.createDirectory(at: metadataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try lines.joined(separator: "\n").write(to: metadataURL, atomically: true, encoding: .utf8)
    }

    func escapeTomlString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    func tomlArray(_ values: [String]) -> String {
        let items = values.map { "\"\(escapeTomlString($0))\"" }.joined(separator: ", ")
        return "[\(items)]"
    }

    func dedupe(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
