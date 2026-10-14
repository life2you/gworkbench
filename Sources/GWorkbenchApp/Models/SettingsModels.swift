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

struct GWorkbenchConfig: Sendable, Hashable {
    let configPath: String
    let metadataPath: String
    let worktreeProjectsRootDirs: [String]
    let worktreesRootDir: String
    let worktreePathTemplate: String
    let ideMode: String
    let ideCommand: String
    let ideLabel: String
    let terminalApp: String
    let terminalBundleID: String
    let terminalLaunchHookMode: String
    let terminalLaunchCommand: String
    let gitlabHost: String
    let gitlabToken: String
    let githubToken: String
    let aiProvider: String
    let aiBaseURL: String
    let aiAPIKey: String
    let aiModel: String
    let aiCustomPrompt: String
    let activeWorkflowPreset: String
    let githubDefaultTargetBranch: String
    let mergeRootDirs: [String]
    let mergeBranchMiddle: String
    let envBranches: [String]
    let branchMap: [String: String]
    let protectedTargets: [String]
    let autoMergeDelaySeconds: Int
    let autoMergeRetryCount: Int

    func asWorktreeConfig() -> WorktreeConfig {
        WorktreeConfig(
            configPath: configPath,
            metadataPath: metadataPath,
            projectsRootDirs: worktreeProjectsRootDirs,
            worktreesRootDir: worktreesRootDir,
            ideMode: ideMode,
            ideCommand: ideCommand,
            ideLabel: ideLabel
        )
    }

    func asMergeWorkflowConfig() -> MergeWorkflowConfig {
        MergeWorkflowConfig(
            configPath: configPath,
            host: gitlabHost,
            token: gitlabToken,
            rootDirs: mergeRootDirs,
            mergeBranchMiddle: mergeBranchMiddle,
            envBranches: envBranches,
            branchMap: branchMap,
            protectedTargets: protectedTargets,
            autoMergeDelaySeconds: autoMergeDelaySeconds,
            autoMergeRetryCount: autoMergeRetryCount
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
    var terminalApp: String = "Terminal"
    var terminalBundleID: String = "com.apple.Terminal"
    var terminalLaunchHookMode: String = "none"
    var terminalLaunchCommand: String = "git status"
    var gitlabHost: String = ""
    var gitlabToken: String = ""
    var githubToken: String = ""
    var aiProvider: String = "deepseek"
    var aiBaseURL: String = "https://api.deepseek.com"
    var aiAPIKey: String = ""
    var aiModel: String = "deepseek-chat"
    var aiCustomPrompt: String = ""
    var activeWorkflowPreset: String = "env_flow"
    var githubDefaultTargetBranch: String = "main"
    var mergeRootDirs: [PathEntryDraft] = []
    var mergeBranchMiddle: String = ""
    var envBranchesText: String = ""
    var protectedTargetsText: String = ""
    var autoMergeDelaySecondsText: String = "10"
    var autoMergeRetryCountText: String = "3"
    var branchMappings: [BranchMappingDraft] = []

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
        terminalApp = config.terminalApp
        terminalBundleID = config.terminalBundleID
        terminalLaunchHookMode = config.terminalLaunchHookMode.isEmpty ? "none" : config.terminalLaunchHookMode
        terminalLaunchCommand = config.terminalLaunchCommand.isEmpty ? "git status" : config.terminalLaunchCommand
        gitlabHost = config.gitlabHost
        gitlabToken = config.gitlabToken
        githubToken = config.githubToken
        aiProvider = config.aiProvider.isEmpty ? "deepseek" : config.aiProvider
        aiBaseURL = config.aiBaseURL.isEmpty ? "https://api.deepseek.com" : config.aiBaseURL
        aiAPIKey = config.aiAPIKey
        aiModel = config.aiModel.isEmpty ? "deepseek-chat" : config.aiModel
        aiCustomPrompt = config.aiCustomPrompt
        activeWorkflowPreset = config.activeWorkflowPreset.isEmpty ? "env_flow" : config.activeWorkflowPreset
        githubDefaultTargetBranch = config.githubDefaultTargetBranch.isEmpty ? "main" : config.githubDefaultTargetBranch
        mergeRootDirs = config.mergeRootDirs.map { PathEntryDraft(path: $0) }
        mergeBranchMiddle = config.mergeBranchMiddle
        envBranchesText = config.envBranches.joined(separator: ", ")
        protectedTargetsText = config.protectedTargets.joined(separator: ", ")
        autoMergeDelaySecondsText = String(config.autoMergeDelaySeconds)
        autoMergeRetryCountText = String(config.autoMergeRetryCount)
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
