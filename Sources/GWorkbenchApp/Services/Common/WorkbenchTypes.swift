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
        if lower.contains("gitlab") || lower.contains("172.16.") {
            return .gitlab
        }
        return .local
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

struct WorktreeConfig: Sendable, Hashable {
    let configPath: String
    let metadataPath: String
    let projectsRootDirs: [String]
    let worktreesRootDir: String
    let ideMode: String
    let ideCommand: String
    let ideLabel: String
}

struct MergeWorkflowConfig: Sendable, Hashable {
    let configPath: String
    let host: String
    let token: String
    let rootDirs: [String]
    let mergeBranchMiddle: String
    let envBranches: [String]
    let branchMap: [String: String]
    let protectedTargets: [String]
    let autoMergeDelaySeconds: Int
    let autoMergeRetryCount: Int
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

/// 固定的 4 个环境/基线合入热点
enum SweeperMergeTarget: String, CaseIterable, Identifiable, Sendable {
    case master = "master"
    case stage = "stage"
    case test = "test"
    case uat = "uat"

    var id: String { rawValue }

    /// 主管线顺序：从高到低
    static var ordered: [SweeperMergeTarget] { [.master, .stage, .test, .uat] }
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

    /// 命中 master / stage / test / uat 的合入结果（顺序与 SweeperMergeTarget.ordered 一致）
    let mergeTargets: [SweeperMergeTarget]
    let mergeStatus: [SweeperMergeTarget: Bool]

    var mergedCount: Int {
        mergeTargets.filter { mergeStatus[$0] == true }.count
    }

    var totalMergeTargets: Int { mergeTargets.count }

    var isFullyMerged: Bool {
        !mergeTargets.isEmpty && mergedCount == mergeTargets.count
    }
}
