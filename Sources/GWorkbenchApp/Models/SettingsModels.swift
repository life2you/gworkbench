import Foundation

struct PathEntryDraft: Identifiable, Hashable, Sendable {
    let id: UUID
    var path: String

    init(id: UUID = UUID(), path: String = "") {
        self.id = id
        self.path = path
    }
}

struct BranchMappingDraft: Identifiable, Hashable, Sendable {
    let id: UUID
    var source: String
    var target: String

    init(id: UUID = UUID(), source: String = "", target: String = "") {
        self.id = id
        self.source = source
        self.target = target
    }
}

struct IDEProfileDraft: Identifiable, Hashable, Sendable {
    var id: String
    var label: String
    var mode: String
    var command: String

    init(
        id: String = UUID().uuidString,
        label: String = "",
        mode: String = "app",
        command: String = ""
    ) {
        self.id = id
        self.label = label
        self.mode = mode
        self.command = command
    }

    init(profile: IDEProfile) {
        self.id = profile.id
        self.label = profile.label
        self.mode = profile.mode
        self.command = profile.command
    }

    func toIDEProfile() -> IDEProfile {
        let trimmedCmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedMode = mode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "app" : mode.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLabel = trimmedLabel.isEmpty ? (trimmedCmd.isEmpty || trimmedCmd == "open" ? "默认应用" : trimmedCmd) : trimmedLabel
        let resolvedCmd = trimmedCmd.isEmpty && resolvedMode != "custom" ? "open" : trimmedCmd
        return IDEProfile(
            id: id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UUID().uuidString : id,
            label: resolvedLabel,
            mode: resolvedMode,
            command: resolvedCmd
        )
    }
}

struct WorkspaceProfileDraft: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var platform: RepositoryPlatform
    var projectsRootDirs: [PathEntryDraft]
    var worktreesRootDir: String
    var host: String
    var token: String
    var defaultTargetBranch: String
    var mainlineBranchesText: String
    var dashboardBaselinesText: String
    var envBranchesText: String
    var mergeBranchMiddle: String
    var branchMappings: [BranchMappingDraft]

    init(
        id: String = UUID().uuidString,
        name: String = "私有 GitLab",
        platform: RepositoryPlatform = .gitlab,
        projectsRootDirs: [PathEntryDraft] = [],
        worktreesRootDir: String = "",
        host: String = "",
        token: String = "",
        defaultTargetBranch: String = "main",
        mainlineBranchesText: String = "",
        dashboardBaselinesText: String = "master, stage, test, uat",
        envBranchesText: String = "dev, test, stage, uat",
        mergeBranchMiddle: String = "sync",
        branchMappings: [BranchMappingDraft] = []
    ) {
        self.id = id
        self.name = name
        self.platform = platform == .gitlab ? .gitlab : .github
        self.projectsRootDirs = projectsRootDirs
        self.worktreesRootDir = worktreesRootDir
        self.host = host
        self.token = token
        self.defaultTargetBranch = defaultTargetBranch
        let resolvedMainline = mainlineBranchesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultTargetBranch
            : mainlineBranchesText
        self.mainlineBranchesText = resolvedMainline
        self.dashboardBaselinesText = dashboardBaselinesText
        self.envBranchesText = envBranchesText
        self.mergeBranchMiddle = mergeBranchMiddle
        self.branchMappings = branchMappings
    }

    init(profile: WorkspaceProfile) {
        self.id = profile.id
        self.name = profile.name
        self.platform = profile.platform == .gitlab ? .gitlab : .github
        self.projectsRootDirs = profile.projectsRootDirs.map { PathEntryDraft(path: $0) }
        self.worktreesRootDir = profile.worktreesRootDir
        self.host = profile.host
        self.token = profile.token
        let configuredMainlines = profile.configuredMainlineBranches
        self.defaultTargetBranch = configuredMainlines.first ?? ""
        self.mainlineBranchesText = configuredMainlines.joined(separator: ", ")
        self.dashboardBaselinesText = profile.effectiveDashboardBaselines.joined(separator: ", ")
        self.envBranchesText = profile.envBranches.joined(separator: ", ")
        self.mergeBranchMiddle = profile.mergeBranchMiddle
        self.branchMappings = profile.branchMap
            .sorted { $0.key < $1.key }
            .map { BranchMappingDraft(source: $0.key, target: $0.value) }
    }

    static func parseBranchList(_ text: String) -> [String] {
        var seen = Set<String>()
        return text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    var mainlineBranchList: [String] {
        get { Self.parseBranchList(mainlineBranchesText) }
        set {
            mainlineBranchesText = newValue.joined(separator: ", ")
            defaultTargetBranch = newValue.first ?? ""
        }
    }

    var protectedEnvBranchList: [String] {
        get { Self.parseBranchList(envBranchesText) }
        set { envBranchesText = newValue.joined(separator: ", ") }
    }

    var dashboardBaselineList: [String] {
        get { Self.parseBranchList(dashboardBaselinesText) }
        set { dashboardBaselinesText = newValue.joined(separator: ", ") }
    }

    static func buildBranchMappings(
        envs: [String],
        mainlines: [String],
        middle: String
    ) -> [BranchMappingDraft] {
        let resolvedMiddle = middle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "sync"
            : middle.trimmingCharacters(in: .whitespacesAndNewlines)

        var newMappings: [BranchMappingDraft] = []
        if let lastEnv = envs.last, let target = mainlines.first, lastEnv != target {
            newMappings.append(BranchMappingDraft(source: lastEnv, target: target))
        }
        for env in envs.reversed() {
            newMappings.append(BranchMappingDraft(
                source: "\(env)_\(resolvedMiddle)",
                target: env
            ))
        }
        return newMappings
    }

    func buildRecommendedBranchMappings(extraProtectedTargets: [String] = []) -> [BranchMappingDraft] {
        let envs = protectedEnvBranchList
        let mainlines = mainlineBranchList.isEmpty ? extraProtectedTargets : mainlineBranchList
        return Self.buildBranchMappings(envs: envs, mainlines: mainlines, middle: mergeBranchMiddle)
    }

    func toWorkspaceProfile() -> WorkspaceProfile {
        let parsedMainlines = Self.parseBranchList(mainlineBranchesText)
        let parsedBaselines = Self.parseBranchList(dashboardBaselinesText)
        let parsedEnvs = Self.parseBranchList(envBranchesText)
        var map: [String: String] = [:]
        for item in branchMappings {
            let s = item.source.trimmingCharacters(in: .whitespacesAndNewlines)
            let t = item.target.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty && !t.isEmpty {
                map[s] = t
            }
        }
        return WorkspaceProfile(
            id: id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UUID().uuidString : id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? (platform == .github ? "GitHub" : "GitLab")
                : name.trimmingCharacters(in: .whitespacesAndNewlines),
            platform: platform == .gitlab ? .gitlab : .github,
            projectsRootDirs: projectsRootDirs.map { $0.path.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            worktreesRootDir: worktreesRootDir.trimmingCharacters(in: .whitespacesAndNewlines),
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            token: token.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultTargetBranch: parsedMainlines.first ?? "",
            mainlineBranches: parsedMainlines,
            dashboardBaselines: parsedBaselines.isEmpty
                ? (platform == .gitlab ? DefaultDashboardBaselines.gitlab : DefaultDashboardBaselines.github)
                : parsedBaselines,
            envBranches: parsedEnvs,
            mergeBranchMiddle: mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "sync" : mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines),
            branchMap: map
        )
    }
}

struct GWorkbenchConfig: Sendable, Hashable {
    let configPath: String
    let metadataPath: String
    let worktreeProjectsRootDirs: [String]
    let worktreesRootDir: String
    let worktreePathTemplate: String
    let ideMode: String
    let ideCommand: String
    let ideLabel: String
    let ideProfiles: [IDEProfile]
    let defaultIDEProfileID: String
    let terminalApp: String
    let terminalBundleID: String
    let terminalLaunchHookMode: String
    let terminalLaunchCommand: String
    let terminalSetTabTitle: Bool
    let gitlabHost: String
    let gitlabToken: String
    let githubHost: String
    let githubToken: String
    let aiProvider: String
    let aiBaseURL: String
    let aiAPIKey: String
    let aiModel: String
    let aiCustomPrompt: String
    let activeWorkflowPreset: String
    let activePlatform: String
    let activeWorkspaceID: String
    let workspaces: [WorkspaceProfile]
    let githubDefaultTargetBranch: String
    let githubDashboardBaselines: [String]
    let gitlabDashboardBaselines: [String]
    let mergeRootDirs: [String]
    let mergeBranchMiddle: String
    let envBranches: [String]
    let branchMap: [String: String]
    let protectedTargets: [String]
    let autoMergeDelaySeconds: Int
    let autoMergeRetryCount: Int
    let syncIDEConfigs: Bool
    let ideConfigSyncItems: [String]

    init(
        configPath: String,
        metadataPath: String,
        worktreeProjectsRootDirs: [String],
        worktreesRootDir: String,
        worktreePathTemplate: String,
        ideMode: String,
        ideCommand: String,
        ideLabel: String,
        ideProfiles: [IDEProfile] = [],
        defaultIDEProfileID: String = "",
        terminalApp: String,
        terminalBundleID: String,
        terminalLaunchHookMode: String,
        terminalLaunchCommand: String,
        terminalSetTabTitle: Bool = true,
        gitlabHost: String,
        gitlabToken: String,
        githubHost: String = "https://github.com",
        githubToken: String,
        aiProvider: String,
        aiBaseURL: String,
        aiAPIKey: String,
        aiModel: String,
        aiCustomPrompt: String,
        activeWorkflowPreset: String,
        activePlatform: String,
        activeWorkspaceID: String = "",
        workspaces: [WorkspaceProfile] = [],
        githubDefaultTargetBranch: String,
        githubDashboardBaselines: [String],
        gitlabDashboardBaselines: [String],
        mergeRootDirs: [String],
        mergeBranchMiddle: String,
        envBranches: [String],
        branchMap: [String: String],
        protectedTargets: [String],
        autoMergeDelaySeconds: Int,
        autoMergeRetryCount: Int,
        syncIDEConfigs: Bool,
        ideConfigSyncItems: [String]
    ) {
        self.configPath = configPath
        self.metadataPath = metadataPath
        self.worktreeProjectsRootDirs = worktreeProjectsRootDirs
        self.worktreesRootDir = worktreesRootDir
        self.worktreePathTemplate = worktreePathTemplate
        self.ideMode = ideMode
        self.ideCommand = ideCommand
        self.ideLabel = ideLabel
        self.ideProfiles = ideProfiles
        self.defaultIDEProfileID = defaultIDEProfileID
        self.terminalApp = terminalApp
        self.terminalBundleID = terminalBundleID
        self.terminalLaunchHookMode = terminalLaunchHookMode
        self.terminalLaunchCommand = terminalLaunchCommand
        self.terminalSetTabTitle = terminalSetTabTitle
        self.gitlabHost = gitlabHost
        self.gitlabToken = gitlabToken
        self.githubHost = githubHost
        self.githubToken = githubToken
        self.aiProvider = aiProvider
        self.aiBaseURL = aiBaseURL
        self.aiAPIKey = aiAPIKey
        self.aiModel = aiModel
        self.aiCustomPrompt = aiCustomPrompt
        self.activeWorkflowPreset = activeWorkflowPreset
        self.activePlatform = activePlatform
        self.activeWorkspaceID = activeWorkspaceID
        self.workspaces = workspaces
        self.githubDefaultTargetBranch = githubDefaultTargetBranch
        self.githubDashboardBaselines = githubDashboardBaselines
        self.gitlabDashboardBaselines = gitlabDashboardBaselines
        self.mergeRootDirs = mergeRootDirs
        self.mergeBranchMiddle = mergeBranchMiddle
        self.envBranches = envBranches
        self.branchMap = branchMap
        self.protectedTargets = protectedTargets
        self.autoMergeDelaySeconds = autoMergeDelaySeconds
        self.autoMergeRetryCount = autoMergeRetryCount
        self.syncIDEConfigs = syncIDEConfigs
        self.ideConfigSyncItems = ideConfigSyncItems
    }

    var currentWorkspace: WorkspaceProfile? {
        if let matched = workspaces.first(where: { $0.id == activeWorkspaceID }) {
            return matched
        }
        return workspaces.first
    }

    var effectiveIDEProfiles: [IDEProfile] {
        if !ideProfiles.isEmpty {
            return ideProfiles
        }
        let fallbackLabel = ideLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackCmd = ideCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackMode = ideMode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "app" : ideMode
        return [
            IDEProfile(
                id: defaultIDEProfileID.isEmpty ? "default-ide" : defaultIDEProfileID,
                label: fallbackLabel.isEmpty ? (fallbackCmd.isEmpty ? "默认应用" : fallbackCmd) : fallbackLabel,
                mode: fallbackMode,
                command: fallbackCmd.isEmpty ? "open" : fallbackCmd
            )
        ]
    }

    var defaultIDEProfile: IDEProfile {
        let profiles = effectiveIDEProfiles
        if !defaultIDEProfileID.isEmpty,
           let matched = profiles.first(where: { $0.id == defaultIDEProfileID }) {
            return matched
        }
        return profiles[0]
    }

    func asWorktreeConfig(for workspace: WorkspaceProfile? = nil) -> WorktreeConfig {
        let ws = workspace ?? currentWorkspace
        let roots = ws?.projectsRootDirs.isEmpty == false ? ws!.projectsRootDirs : worktreeProjectsRootDirs
        let wtDir = ws?.worktreesRootDir.trimmedNonEmpty ?? worktreesRootDir
        let primaryIDE = defaultIDEProfile
        return WorktreeConfig(
            configPath: configPath,
            metadataPath: metadataPath,
            projectsRootDirs: roots,
            worktreesRootDir: wtDir,
            ideMode: primaryIDE.mode,
            ideCommand: primaryIDE.command,
            ideLabel: primaryIDE.effectiveLabel,
            ideProfiles: effectiveIDEProfiles,
            defaultIDEProfileID: primaryIDE.id,
            syncIDEConfigs: syncIDEConfigs,
            ideConfigSyncItems: ideConfigSyncItems,
            forcedPlatform: ws?.platform
        )
    }

    func asMergeWorkflowConfig(for workspace: WorkspaceProfile? = nil) -> MergeWorkflowConfig {
        let ws = workspace ?? currentWorkspace
        if let ws {
            let wsEnvs = ws.envBranches.isEmpty ? envBranches : ws.envBranches
            let wsMiddle = ws.mergeBranchMiddle.isEmpty ? mergeBranchMiddle : ws.mergeBranchMiddle
            let wsMap: [String: String] = !ws.branchMap.isEmpty
                ? ws.branchMap
                : (!branchMap.isEmpty
                    ? branchMap
                    : Dictionary(uniqueKeysWithValues: wsEnvs.map { ("\($0)_\(wsMiddle)", $0) }))
            let configuredMainlines = ws.configuredMainlineBranches
            var seenProtected = Set<String>()
            // 仅将全局配置与各工作区的「生产主干分支」纳入高危保护拦截列表；
            // 「非生产保护分支」用于集成同步与批量流转，不阻塞批量创建 MR。
            let combinedProtected = (protectedTargets + configuredMainlines).filter {
                !$0.isEmpty && seenProtected.insert($0).inserted
            }
            return MergeWorkflowConfig(
                configPath: configPath,
                host: ws.platform == .gitlab ? ws.host : gitlabHost,
                token: ws.platform == .gitlab ? ws.token : gitlabToken,
                githubHost: ws.platform == .github ? ws.host : githubHost,
                githubToken: ws.platform == .github ? ws.token : githubToken,
                githubDefaultTargetBranch: ws.platform == .github
                    ? (configuredMainlines.first ?? "main")
                    : (githubDefaultTargetBranch.isEmpty ? "main" : githubDefaultTargetBranch),
                rootDirs: ws.projectsRootDirs.isEmpty ? mergeRootDirs : ws.projectsRootDirs,
                mergeBranchMiddle: wsMiddle,
                envBranches: wsEnvs,
                branchMap: wsMap,
                protectedTargets: combinedProtected,
                mainlineBranches: configuredMainlines,
                autoMergeDelaySeconds: autoMergeDelaySeconds,
                autoMergeRetryCount: autoMergeRetryCount,
                forcedPlatform: ws.platform
            )
        }

        return MergeWorkflowConfig(
            configPath: configPath,
            host: gitlabHost,
            token: gitlabToken,
            githubHost: githubHost,
            githubToken: githubToken,
            githubDefaultTargetBranch: githubDefaultTargetBranch.isEmpty ? "main" : githubDefaultTargetBranch,
            rootDirs: mergeRootDirs,
            mergeBranchMiddle: mergeBranchMiddle,
            envBranches: envBranches,
            branchMap: branchMap,
            protectedTargets: protectedTargets,
            autoMergeDelaySeconds: autoMergeDelaySeconds,
            autoMergeRetryCount: autoMergeRetryCount,
            forcedPlatform: nil
        )
    }
}

struct SettingsDraft: Sendable {
    var configPath: String = ""
    var metadataPath: String = ""
    var worktreeProjectsRootDirs: [PathEntryDraft] = []
    var worktreesRootDir: String = ""
    var worktreePathTemplate: String = "${rootDir}/${project}/${branch}"
    var ideMode: String = "app"
    var ideCommand: String = ""
    var ideLabel: String = ""
    var ideProfiles: [IDEProfileDraft] = []
    var defaultIDEProfileID: String = ""
    var terminalApp: String = "Terminal"
    var terminalBundleID: String = "com.apple.Terminal"
    var terminalLaunchHookMode: String = "none"
    var terminalLaunchCommand: String = "git status"
    var terminalSetTabTitle: Bool = true
    var gitlabHost: String = ""
    var gitlabToken: String = ""
    var githubHost: String = "https://github.com"
    var githubToken: String = ""
    var aiProvider: String = "deepseek"
    var aiBaseURL: String = "https://api.deepseek.com"
    var aiAPIKey: String = ""
    var aiModel: String = "deepseek-chat"
    var aiCustomPrompt: String = ""
    var activeWorkflowPreset: String = "env_flow"
    var activePlatform: String = ""
    var activeWorkspaceID: String = ""
    var workspaces: [WorkspaceProfileDraft] = []
    var githubDefaultTargetBranch: String = "main"
    var githubDashboardBaselinesText: String = "main"
    var gitlabDashboardBaselinesText: String = "master, stage, test, uat"
    var mergeRootDirs: [PathEntryDraft] = []
    var mergeBranchMiddle: String = ""
    var envBranchesText: String = ""
    var protectedTargetsText: String = ""
    var autoMergeDelaySecondsText: String = "10"
    var autoMergeRetryCountText: String = "3"
    var branchMappings: [BranchMappingDraft] = []
    var syncIDEConfigs: Bool = false
    var ideConfigSyncItemsText: String = ""

    init() {}

    init(config: GWorkbenchConfig) {
        configPath = config.configPath
        metadataPath = config.metadataPath
        worktreeProjectsRootDirs = config.worktreeProjectsRootDirs.map { PathEntryDraft(path: $0) }
        worktreesRootDir = config.worktreesRootDir
        worktreePathTemplate = config.worktreePathTemplate.isEmpty ? "${rootDir}/${project}/${branch}" : config.worktreePathTemplate
        ideMode = config.ideMode
        ideCommand = config.ideCommand
        ideLabel = config.ideLabel
        let resolvedProfiles = config.effectiveIDEProfiles
        ideProfiles = resolvedProfiles.map { IDEProfileDraft(profile: $0) }
        defaultIDEProfileID = config.defaultIDEProfile.id
        terminalApp = config.terminalApp
        terminalBundleID = config.terminalBundleID
        terminalLaunchHookMode = config.terminalLaunchHookMode.isEmpty ? "none" : config.terminalLaunchHookMode
        terminalLaunchCommand = config.terminalLaunchCommand.isEmpty ? "git status" : config.terminalLaunchCommand
        terminalSetTabTitle = config.terminalSetTabTitle
        gitlabHost = config.gitlabHost
        gitlabToken = config.gitlabToken
        githubHost = config.githubHost.isEmpty ? "https://github.com" : config.githubHost
        githubToken = config.githubToken
        aiProvider = config.aiProvider.isEmpty ? "deepseek" : config.aiProvider
        aiBaseURL = config.aiBaseURL.isEmpty ? "https://api.deepseek.com" : config.aiBaseURL
        aiAPIKey = config.aiAPIKey
        aiModel = config.aiModel.isEmpty ? "deepseek-chat" : config.aiModel
        aiCustomPrompt = config.aiCustomPrompt
        activeWorkflowPreset = config.activeWorkflowPreset.isEmpty ? "env_flow" : config.activeWorkflowPreset
        activePlatform = config.activePlatform
        activeWorkspaceID = config.activeWorkspaceID
        workspaces = config.workspaces.map { WorkspaceProfileDraft(profile: $0) }
        githubDefaultTargetBranch = config.githubDefaultTargetBranch.isEmpty ? "main" : config.githubDefaultTargetBranch
        githubDashboardBaselinesText = config.githubDashboardBaselines.isEmpty
            ? DefaultDashboardBaselines.github.joined(separator: ", ")
            : config.githubDashboardBaselines.joined(separator: ", ")
        gitlabDashboardBaselinesText = config.gitlabDashboardBaselines.isEmpty
            ? DefaultDashboardBaselines.gitlab.joined(separator: ", ")
            : config.gitlabDashboardBaselines.joined(separator: ", ")
        mergeRootDirs = config.mergeRootDirs.map { PathEntryDraft(path: $0) }
        mergeBranchMiddle = config.mergeBranchMiddle
        envBranchesText = config.envBranches.joined(separator: ", ")
        protectedTargetsText = config.protectedTargets.joined(separator: ", ")
        autoMergeDelaySecondsText = String(config.autoMergeDelaySeconds)
        autoMergeRetryCountText = String(config.autoMergeRetryCount)
        syncIDEConfigs = config.syncIDEConfigs
        ideConfigSyncItemsText = config.ideConfigSyncItems.joined(separator: ", ")
        branchMappings = config.branchMap
            .sorted { lhs, rhs in
                if lhs.key != rhs.key {
                    return lhs.key < rhs.key
                }
                return lhs.value < rhs.value
            }
            .map { BranchMappingDraft(source: $0.key, target: $0.value) }
    }
}
