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
    let ideMode: String
    let ideCommand: String
    let ideLabel: String
    let gitlabHost: String
    let gitlabToken: String
    let mergeRootDirs: [String]
    let mergeBranchMiddle: String
    let envBranches: [String]
    let branchMap: [String: String]
    let protectedTargets: [String]
    let autoMergeDelaySeconds: Int
    let autoMergeRetryCount: Int

    func asGwtmConfig() -> GwtmConfig {
        GwtmConfig(
            configPath: configPath,
            metadataPath: metadataPath,
            projectsRootDirs: worktreeProjectsRootDirs,
            worktreesRootDir: worktreesRootDir,
            ideMode: ideMode,
            ideCommand: ideCommand,
            ideLabel: ideLabel
        )
    }

    func asGmuxConfig() -> GmuxConfig {
        GmuxConfig(
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
    var ideMode: String = "app"
    var ideCommand: String = ""
    var ideLabel: String = ""
    var gitlabHost: String = ""
    var gitlabToken: String = ""
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
        ideMode = config.ideMode
        ideCommand = config.ideCommand
        ideLabel = config.ideLabel
        gitlabHost = config.gitlabHost
        gitlabToken = config.gitlabToken
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
