import Foundation
import SwiftUI

enum RepositoryPlatform: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all = "全部"
    case gitlab = "GitLab"
    case github = "GitHub"
    case local = "本地"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "全部平台"
        case .gitlab: return "私有 GitLab"
        case .github: return "GitHub"
        case .local: return "本地/其它"
        }
    }

    var shortName: String {
        switch self {
        case .all: return "全部"
        case .gitlab: return "GitLab"
        case .github: return "GitHub"
        case .local: return "本地"
        }
    }

    var badgeText: String {
        switch self {
        case .all: return "全部"
        case .gitlab: return "🦊 GitLab"
        case .github: return "🐙 GitHub"
        case .local: return "💻 本地"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.stack.3d.up"
        case .gitlab: return "network"
        case .github: return "globe.americas"
        case .local: return "internaldrive"
        }
    }

    var tintColor: Color {
        switch self {
        case .all: return .primary
        case .gitlab: return .orange
        case .github: return .purple
        case .local: return .gray
        }
    }

    /// 探测计划：区分「确定无远端」与「读取失败」两种结果
    enum RemoteURLProbe {
        case url(String)
        case noRemoteConfigured
        case probeFailed
    }

    static func detect(remoteURL: String?, gitlabHost: String? = nil) -> RepositoryPlatform {
        guard let url = remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty else {
            return .local
        }
        let lower = url.lowercased()
        if lower.contains("github.com") {
            return .github
        }
        if let host = gitlabHost?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty {
            let hostDomain = host
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "https://", with: "")
                .split(separator: ":").first.map(String.init) ?? host
            if !hostDomain.isEmpty && lower.contains(hostDomain.lowercased()) {
                return .gitlab
            }
        }
        if lower.contains("gitlab") {
            return .gitlab
        }
        return .local
    }

    /// 远端读取失败时的兜底判定：
    /// 若仓库存在 origin/* 远端跟踪分支，说明它一定托管在某个平台，
    /// 优先根据已知的 GitLab 主机推断，否则归为 GitHub（除非明确匹配 GitLab）。
    static func fallbackPlatform(existingBranchRefs: [String], gitlabHost: String?) -> RepositoryPlatform? {
        let hasOriginRefs = existingBranchRefs.contains { $0.hasPrefix("origin/") && $0.count > "origin/".count }
        guard hasOriginRefs else { return nil }

        if let host = gitlabHost?.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty {
            let hostDomain = host
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "https://", with: "")
                .split(separator: ":").first.map(String.init) ?? host
            if !hostDomain.isEmpty {
                return .gitlab
            }
        }
        return .github
    }
}

struct LocalProject: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let displayName: String
    let path: String
    let sourceRoot: String
    let currentBranch: String
    let baseBranches: [String]
    let localBranches: [String]
    let remoteURL: String?
    let platform: RepositoryPlatform

    init(
        id: String,
        name: String,
        displayName: String,
        path: String,
        sourceRoot: String,
        currentBranch: String,
        baseBranches: [String],
        localBranches: [String],
        remoteURL: String? = nil,
        platform: RepositoryPlatform = .local
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.path = path
        self.sourceRoot = sourceRoot
        self.currentBranch = currentBranch
        self.baseBranches = baseBranches
        self.localBranches = localBranches
        self.remoteURL = remoteURL
        self.platform = platform
    }
}

struct BranchMapping: Identifiable, Hashable, Sendable {
    let source: String
    let target: String
    let protectedTarget: Bool

    var id: String { "\(source)->\(target)" }
}

struct WorkspaceProfile: Identifiable, Hashable, Sendable, Codable {
    var id: String
    var name: String
    var platform: RepositoryPlatform
    var projectsRootDirs: [String]
    var worktreesRootDir: String
    var host: String
    var token: String
    var defaultTargetBranch: String
    var mainlineBranches: [String]
    var dashboardBaselines: [String]
    var envBranches: [String]
    var mergeBranchMiddle: String
    var branchMap: [String: String]

    init(
        id: String = UUID().uuidString,
        name: String,
        platform: RepositoryPlatform,
        projectsRootDirs: [String] = [],
        worktreesRootDir: String = "",
        host: String = "",
        token: String = "",
        defaultTargetBranch: String = "",
        mainlineBranches: [String] = [],
        dashboardBaselines: [String] = [],
        envBranches: [String] = [],
        mergeBranchMiddle: String = "",
        branchMap: [String: String] = [:]
    ) {
        let cleanedMainlines = mainlineBranches.filterNonEmpty()
        let fallbackMainline = defaultTargetBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedMainlines = !cleanedMainlines.isEmpty
            ? cleanedMainlines
            : (fallbackMainline.isEmpty ? [] : [fallbackMainline])

        self.id = id
        self.name = name
        self.platform = platform == .gitlab ? .gitlab : .github
        self.projectsRootDirs = projectsRootDirs
        self.worktreesRootDir = worktreesRootDir
        self.host = host
        self.token = token
        self.defaultTargetBranch = fallbackMainline.isEmpty ? (resolvedMainlines.first ?? "") : fallbackMainline
        self.mainlineBranches = resolvedMainlines
        self.dashboardBaselines = dashboardBaselines
        self.envBranches = envBranches
        self.mergeBranchMiddle = mergeBranchMiddle
        self.branchMap = branchMap
    }

    enum CodingKeys: String, CodingKey {
        case id, name, platform, projectsRootDirs, worktreesRootDir, host, token
        case defaultTargetBranch, mainlineBranches, dashboardBaselines, envBranches, mergeBranchMiddle, branchMap
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "工作区"
        let rawPlatform = (try c.decodeIfPresent(String.self, forKey: .platform) ?? "github").lowercased()
        platform = rawPlatform == "gitlab" ? .gitlab : .github
        projectsRootDirs = try c.decodeIfPresent([String].self, forKey: .projectsRootDirs) ?? []
        worktreesRootDir = try c.decodeIfPresent(String.self, forKey: .worktreesRootDir) ?? ""
        host = try c.decodeIfPresent(String.self, forKey: .host) ?? ""
        token = try c.decodeIfPresent(String.self, forKey: .token) ?? ""
        defaultTargetBranch = try c.decodeIfPresent(String.self, forKey: .defaultTargetBranch) ?? ""
        if let decodedMainlines = try c.decodeIfPresent([String].self, forKey: .mainlineBranches) {
            mainlineBranches = decodedMainlines.filterNonEmpty()
        } else {
            let fallback = defaultTargetBranch.trimmingCharacters(in: .whitespacesAndNewlines)
            mainlineBranches = fallback.isEmpty ? [platform == .github ? "main" : "master"] : [fallback]
        }
        dashboardBaselines = try c.decodeIfPresent([String].self, forKey: .dashboardBaselines) ?? []
        envBranches = try c.decodeIfPresent([String].self, forKey: .envBranches) ?? []
        mergeBranchMiddle = try c.decodeIfPresent(String.self, forKey: .mergeBranchMiddle) ?? "sync"
        branchMap = try c.decodeIfPresent([String: String].self, forKey: .branchMap) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(platform == .gitlab ? "gitlab" : "github", forKey: .platform)
        try c.encode(projectsRootDirs, forKey: .projectsRootDirs)
        try c.encode(worktreesRootDir, forKey: .worktreesRootDir)
        try c.encode(host, forKey: .host)
        try c.encode(token, forKey: .token)
        try c.encode(defaultTargetBranch, forKey: .defaultTargetBranch)
        try c.encode(mainlineBranches, forKey: .mainlineBranches)
        try c.encode(dashboardBaselines, forKey: .dashboardBaselines)
        try c.encode(envBranches, forKey: .envBranches)
        try c.encode(mergeBranchMiddle, forKey: .mergeBranchMiddle)
        try c.encode(branchMap, forKey: .branchMap)
    }

    /// 已显式配置的生产主干分支列表（可为空，表示未配置主干分支）
    var configuredMainlineBranches: [String] {
        mainlineBranches.filterNonEmpty()
    }

    var primaryMainlineBranch: String? {
        configuredMainlineBranches.first
    }

    /// 生产环境主干分支列表（至少保证返回主干默认值，用于需要兜底默认目标的场景）
    var effectiveMainlineBranches: [String] {
        let cleaned = mainlineBranches.filterNonEmpty()
        if !cleaned.isEmpty { return cleaned }
        let single = defaultTargetBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        if !single.isEmpty { return [single] }
        return [platform == .github ? "main" : "master"]
    }

    /// 非生产环境的保护分支列表（用于联调、测试、预发等）
    var effectiveProtectedBranches: [String] {
        envBranches.filterNonEmpty()
    }

    /// 需要受保护合并检查的所有目标分支（生产主干 + 非生产保护分支）
    var allProtectedMergeTargets: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for branch in effectiveMainlineBranches + effectiveProtectedBranches {
            if seen.insert(branch).inserted {
                result.append(branch)
            }
        }
        return result
    }

    var effectiveDashboardBaselines: [String] {
        let cleaned = dashboardBaselines.filterNonEmpty()
        if !cleaned.isEmpty { return cleaned }
        return platform == .gitlab ? DefaultDashboardBaselines.gitlab : DefaultDashboardBaselines.github
    }

    var effectiveHostDisplay: String {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return platform == .github ? "https://github.com" : "未配置 Host"
    }
}

struct IDEProfile: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var label: String
    var mode: String
    var command: String

    init(
        id: String = UUID().uuidString,
        label: String,
        mode: String = "app",
        command: String
    ) {
        self.id = id
        self.label = label
        self.mode = mode
        self.command = command
    }

    var effectiveLabel: String {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLabel.isEmpty {
            return trimmedLabel
        }
        let trimmedCmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCmd.isEmpty && trimmedCmd != "open" {
            return trimmedCmd
        }
        return mode == "system" ? "系统默认" : "默认应用"
    }
}

struct WorktreeConfig: Sendable, Hashable {
    let configPath: String
    let metadataPath: String
    let projectsRootDirs: [String]
    let worktreesRootDir: String
    let ideMode: String
    let ideCommand: String
    let ideLabel: String
    let ideProfiles: [IDEProfile]
    let defaultIDEProfileID: String
    let syncIDEConfigs: Bool
    let ideConfigSyncItems: [String]
    let forcedPlatform: RepositoryPlatform?

    init(
        configPath: String,
        metadataPath: String,
        projectsRootDirs: [String],
        worktreesRootDir: String,
        ideMode: String,
        ideCommand: String,
        ideLabel: String,
        ideProfiles: [IDEProfile] = [],
        defaultIDEProfileID: String = "",
        syncIDEConfigs: Bool,
        ideConfigSyncItems: [String],
        forcedPlatform: RepositoryPlatform? = nil
    ) {
        self.configPath = configPath
        self.metadataPath = metadataPath
        self.projectsRootDirs = projectsRootDirs
        self.worktreesRootDir = worktreesRootDir
        self.ideMode = ideMode
        self.ideCommand = ideCommand
        self.ideLabel = ideLabel
        self.ideProfiles = ideProfiles
        self.defaultIDEProfileID = defaultIDEProfileID
        self.syncIDEConfigs = syncIDEConfigs
        self.ideConfigSyncItems = ideConfigSyncItems
        self.forcedPlatform = forcedPlatform
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
}

struct MergeWorkflowConfig: Sendable, Hashable {
    let configPath: String
    let host: String
    let token: String
    let githubHost: String
    let githubToken: String
    let githubDefaultTargetBranch: String
    let rootDirs: [String]
    let mergeBranchMiddle: String
    let envBranches: [String]
    let branchMap: [String: String]
    let protectedTargets: [String]
    let mainlineBranches: [String]
    let autoMergeDelaySeconds: Int
    let autoMergeRetryCount: Int
    let forcedPlatform: RepositoryPlatform?

    init(
        configPath: String,
        host: String,
        token: String,
        githubHost: String = "",
        githubToken: String = "",
        githubDefaultTargetBranch: String = "main",
        rootDirs: [String],
        mergeBranchMiddle: String,
        envBranches: [String],
        branchMap: [String: String],
        protectedTargets: [String],
        mainlineBranches: [String] = [],
        autoMergeDelaySeconds: Int,
        autoMergeRetryCount: Int,
        forcedPlatform: RepositoryPlatform? = nil
    ) {
        self.configPath = configPath
        self.host = host
        self.token = token
        self.githubHost = githubHost
        self.githubToken = githubToken
        self.githubDefaultTargetBranch = githubDefaultTargetBranch
        self.rootDirs = rootDirs
        self.mergeBranchMiddle = mergeBranchMiddle
        self.envBranches = envBranches
        self.branchMap = branchMap
        self.protectedTargets = protectedTargets
        self.mainlineBranches = mainlineBranches.filterNonEmpty()
        self.autoMergeDelaySeconds = autoMergeDelaySeconds
        self.autoMergeRetryCount = autoMergeRetryCount
        self.forcedPlatform = forcedPlatform
    }
}

struct WorktreeSnapshot: Sendable {
    let config: WorktreeConfig
    let projects: [LocalProject]
    let worktrees: [WorktreeItem]
}

struct MergeRequestContext: Sendable {
    let config: MergeWorkflowConfig
    let currentUsername: String
    let projects: [MergeProject]
}

struct LocalMergeContext: Sendable {
    let config: MergeWorkflowConfig
    let projects: [MergeProject]
}

struct MergeProject: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let displayName: String
    let path: String
    let sourceRoot: String
    let currentBranch: String
    let gitLabProjectID: Int?
    let githubRepoSlug: String?
    let branchMappings: [BranchMapping]
    let remoteBranches: [String]
    let localBranches: [String]
    let remoteURL: String?
    let platform: RepositoryPlatform

    init(
        id: String,
        name: String,
        displayName: String,
        path: String,
        sourceRoot: String,
        currentBranch: String,
        gitLabProjectID: Int?,
        githubRepoSlug: String? = nil,
        branchMappings: [BranchMapping],
        remoteBranches: [String],
        localBranches: [String],
        remoteURL: String? = nil,
        platform: RepositoryPlatform = .local
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.path = path
        self.sourceRoot = sourceRoot
        self.currentBranch = currentBranch
        self.gitLabProjectID = gitLabProjectID
        self.githubRepoSlug = githubRepoSlug
        self.branchMappings = branchMappings
        self.remoteBranches = remoteBranches
        self.localBranches = localBranches
        self.remoteURL = remoteURL
        self.platform = platform
    }
}

struct OperationProgress: Sendable {
    let title: String
    let detail: String
    let current: Int?
    let total: Int?

    var fractionCompleted: Double? {
        guard let current, let total, total > 0 else {
            return nil
        }
        return min(max(Double(current) / Double(total), 0), 1)
    }
}

enum WorkbenchError: LocalizedError, Sendable {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        }
    }
}

struct CreateWorktreeResult: Sendable {
    let path: String
    let logs: [String]
    let successMessage: String
}

enum DateFormatterUtils {
    static func relativeDateString(fromUnixTimestamp timestamp: String) -> String {
        guard let seconds = Double(timestamp) else {
            return "未知"
        }
        return relativeDateString(from: Date(timeIntervalSince1970: seconds))
    }

    static func relativeDateString(fromISO8601 value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "未知"
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return relativeDateString(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return relativeDateString(from: date)
        }
        return value
    }

    static func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Array where Element == String {
    func filterNonEmpty() -> [String] {
        compactMap { $0.trimmedNonEmpty }
    }
}

/// 合入看板数据模型：每个 worktree 分支对可配置基线分支的合入状态
struct MergeDashboardItem: Identifiable, Sendable {
    let id: String
    let branch: String
    let kind: WorktreeKind
    let isDirty: Bool
    let updatedAt: String
    let mergeTargets: [String]
    let mergeStatus: [String: Bool]
    let matchedBranches: [String: String]

    init(
        id: String,
        branch: String,
        kind: WorktreeKind,
        isDirty: Bool,
        updatedAt: String,
        mergeTargets: [String],
        mergeStatus: [String: Bool],
        matchedBranches: [String: String] = [:]
    ) {
        self.id = id
        self.branch = branch
        self.kind = kind
        self.isDirty = isDirty
        self.updatedAt = updatedAt
        self.mergeTargets = mergeTargets
        self.mergeStatus = mergeStatus
        self.matchedBranches = matchedBranches
    }

    var mergedCount: Int {
        mergeTargets.filter { mergeStatus[$0] == true }.count
    }

    var totalMergeTargets: Int { mergeTargets.count }

    var isFullyMerged: Bool {
        !mergeTargets.isEmpty && mergedCount == mergeTargets.count
    }

    var isNotMerged: Bool {
        mergedCount == 0
    }

    var summaryText: String {
        if kind == .mainRepo { return "基准仓库" }
        if isDirty { return "未提交改动" }
        if isFullyMerged { return "全部合入" }
        if isNotMerged { return "未合入" }
        return "合入 \(mergedCount)/\(totalMergeTargets)"
    }
}

func normalizedGitLabHost(_ host: String) -> String {
    var value = host.trimmingCharacters(in: .whitespacesAndNewlines)
    while value.hasSuffix("/") {
        value.removeLast()
    }
    return value
}

enum SweeperCategoryFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case fullyMerged = "全部合入"
    case partialMerged = "部分合入"
    case stale = "休眠 >30天"
    case protected = "受保护"

    var id: String { rawValue }
}

/// 平台默认合入检查基线常量
enum DefaultDashboardBaselines {
    static let github: [String] = ["main"]
    static let gitlab: [String] = ["master", "stage", "test", "uat"]
    static let local: [String] = ["main", "master"]
}

enum WorktreeSweeperStatusType: Sendable, Hashable {
    case mainRepo
    case dirty
    case fullyMerged
    case partiallyMerged(mergedCount: Int)
    case remoteDeleted
    case stale(days: Int)
    case active
}

struct WorktreeSweeperItem: Identifiable, Hashable, Sendable {
    let id: String
    let worktree: WorktreeItem
    let statusType: WorktreeSweeperStatusType
    let statusTitle: String
    let statusDescription: String
    let isProtected: Bool
    let isRecommended: Bool
    let diskUsageFormatted: String
    let approxSizeMB: Double

    /// 命中的各条基线合入结果（按配置顺序排列）
    let mergeTargets: [String]
    let mergeStatus: [String: Bool]

    var mergedCount: Int {
        mergeTargets.filter { mergeStatus[$0] == true }.count
    }

    var totalMergeTargets: Int { mergeTargets.count }

    var isFullyMerged: Bool {
        !mergeTargets.isEmpty && mergedCount == mergeTargets.count
    }
}

// MARK: - 交互式分支同步流水线状态模型

enum SyncTargetStatus: Sendable, Hashable {
    case pending
    case inProgress
    case success(message: String)
    case skippedDueToConflict(files: [String])
    case failed(error: String)

    var isFinished: Bool {
        switch self {
        case .pending, .inProgress:
            return false
        case .success, .skippedDueToConflict, .failed:
            return true
        }
    }

    var displayLabel: String {
        switch self {
        case .pending: return "等待中"
        case .inProgress: return "同步中"
        case .success: return "成功"
        case .skippedDueToConflict: return "因冲突跳过"
        case .failed: return "失败"
        }
    }

    var tintColor: Color {
        switch self {
        case .pending: return .secondary
        case .inProgress: return .blue
        case .success: return .green
        case .skippedDueToConflict: return .orange
        case .failed: return .red
        }
    }
}

struct SyncSessionTargetItem: Identifiable, Sendable, Hashable {
    var id: String { targetBranch }
    let sourceBranch: String
    let targetBranch: String
    var status: SyncTargetStatus
}

enum SyncConflictResolutionPhase: Sendable, Equatable {
    case none
    case awaitingResolution(markerFreeFiles: [String])
    case readyToCommit
    case committedExternally
    case abortedExternally
}

struct ActiveSyncSession: Identifiable, Sendable {
    var id: String { projectID }
    let projectID: String
    let projectPath: String
    let projectName: String
    let initialBranch: String
    var targets: [SyncSessionTargetItem]
    var currentTargetIndex: Int
    var activeConflictFiles: [String] = []
    var conflictPhase: SyncConflictResolutionPhase = .none
    var conflictMergeHeadSHA: String? = nil
    var autoCommitWhenResolved: Bool = true
    var isAutoCommittingConflict: Bool = false

    var currentTarget: SyncSessionTargetItem? {
        guard currentTargetIndex >= 0 && currentTargetIndex < targets.count else { return nil }
        return targets[currentTargetIndex]
    }

    var isPausedForConflict: Bool {
        conflictPhase != .none
    }

    var hasActiveConflict: Bool {
        isPausedForConflict
    }

    var markerFreeConflictFiles: [String] {
        if case .awaitingResolution(let markerFree) = conflictPhase {
            return markerFree
        }
        return []
    }

    var allConflictFilesMarkerFree: Bool {
        guard !activeConflictFiles.isEmpty else { return false }
        let markerFree = Set(markerFreeConflictFiles)
        return Set(activeConflictFiles).isSubset(of: markerFree)
    }

    var canCommitAndContinue: Bool {
        switch conflictPhase {
        case .readyToCommit, .committedExternally:
            return true
        case .awaitingResolution:
            return allConflictFilesMarkerFree
        case .none, .abortedExternally:
            return false
        }
    }

    var isCompleted: Bool {
        currentTargetIndex >= targets.count
    }

    var successfulCount: Int {
        targets.filter {
            if case .success = $0.status { return true }
            return false
        }.count
    }

    var skippedCount: Int {
        targets.filter {
            if case .skippedDueToConflict = $0.status { return true }
            return false
        }.count
    }

    var failedCount: Int {
        targets.filter {
            if case .failed = $0.status { return true }
            return false
        }.count
    }
}
