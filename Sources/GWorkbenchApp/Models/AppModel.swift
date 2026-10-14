import Foundation
import AppKit

enum AppSection: String, CaseIterable, Identifiable {
    case worktrees
    case branchSync
    case mergeRequests
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .worktrees:
            "工作树"
        case .branchSync:
            "分支同步"
        case .mergeRequests:
            "合并请求"
        case .settings:
            "设置"
        }
    }

    var icon: String {
        switch self {
        case .worktrees:
            "point.3.connected.trianglepath.dotted"
        case .branchSync:
            "arrow.triangle.branch"
        case .mergeRequests:
            "arrow.triangle.merge"
        case .settings:
            "gearshape"
        }
    }
}

enum WorktreeKind: String, Hashable, Comparable, Sendable {
    case mainRepo = "主仓库"
    case worktree = "工作树"

    public static func < (lhs: WorktreeKind, rhs: WorktreeKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum WorktreeCategoryFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "全部"
    case active = "活跃"
    case modified = "有修改"
    case mainRepo = "主仓库"

    var id: String { rawValue }
}

enum WorkbenchConsoleTab: String, CaseIterable, Identifiable, Sendable {
    case changes = "改动文件"
    case syncRadar = "分支同步雷达"
    case logs = "执行日志"
    case quickScripts = "快捷脚本"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .changes: return "doc.badge.ellipsis"
        case .syncRadar: return "dot.radiowaves.left.and.right"
        case .logs: return "terminal"
        case .quickScripts: return "applescript"
        }
    }
}

enum MergeRequestFilter: String, CaseIterable, Identifiable {
    case open
    case mine
    case awaitingMine
    case merged
    case closed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open:
            "待处理"
        case .mine:
            "我创建的"
        case .awaitingMine:
            "待我审批"
        case .merged:
            "已合并"
        case .closed:
            "已关闭"
        }
    }
}

enum MergeRequestStatus: String, Hashable {
    case open = "进行中"
    case ready = "可合并"
    case blocked = "阻塞"
    case draft = "草稿"
    case merged = "已合并"
    case closed = "已关闭"
}

enum PipelineState: String, Hashable {
    case passed = "已通过"
    case pending = "执行中"
    case failed = "失败"
    case none = "未运行"
}

enum CreateWorktreeMode: String, CaseIterable, Hashable, Sendable {
    case newBranch = "新建分支"
    case existingBranch = "已有分支"
}

enum LocalBranchOperationMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case syncEnvironments = "同步环境分支"
    case mergeAll = "合并到全部目标"
    case mergeCustom = "自定义目标"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .syncEnvironments:
            return "依次更新环境分支，再同步到对应合并分支并推送。"
        case .mergeAll:
            return "选择一个源分支，批量合并到全部目标合并分支。"
        case .mergeCustom:
            return "按需勾选这次要处理的目标分支，灵活支持单个或多个目标。"
        }
    }

    var requiresSourceBranch: Bool {
        self != .syncEnvironments
    }

    var systemImage: String {
        switch self {
        case .syncEnvironments:
            return "arrow.triangle.2.circlepath"
        case .mergeAll:
            return "arrow.triangle.merge"
        case .mergeCustom:
            return "checklist"
        }
    }

    var detailedDescription: String {
        switch self {
        case .syncEnvironments:
            return "依次检查并更新本地对应环境分支（如 dev / test / staging），拉取最新远端代码，并合并到对应的集成目标分支后自动推送。"
        case .mergeAll:
            return "选择指定的本地源分支，自动依次检出所有集成目标分支，合并当前源分支并全部自动推送到远端仓库。"
        case .mergeCustom:
            return "灵活勾选本次要参与合并的目标分支（支持单个特定目标或多个目标组合），精准完成特定环境代码合流。"
        }
    }
}

struct LocalBranchTargetOption: Identifiable, Hashable, Sendable {
    let envBranch: String
    let targetBranch: String

    var id: String { targetBranch }
    var label: String { "\(envBranch) -> \(targetBranch)" }
}

enum ExistingWorktreeBranchSource: Hashable, Sendable {
    case local
    case remoteOnly
    case localAndRemote
}

struct ExistingWorktreeBranchOption: Identifiable, Hashable, Sendable {
    let name: String
    let source: ExistingWorktreeBranchSource

    var id: String { name }

    var label: String {
        switch source {
        case .local:
            return "\(name) · 本地"
        case .remoteOnly:
            return "\(name) · 远端"
        case .localAndRemote:
            return "\(name) · 本地/远端"
        }
    }
}

struct CommitEntry: Identifiable, Hashable, Sendable {
    let id = UUID()
    let sha: String
    let message: String
    let author: String
    let relativeTime: String
}

struct ActivityEntry: Identifiable, Hashable, Sendable {
    let id = UUID()
    let actor: String
    let summary: String
    let relativeTime: String
}

struct ApprovalEntry: Identifiable, Hashable, Sendable {
    let id = UUID()
    let reviewer: String
    let detail: String
    let approved: Bool
}

struct WorktreeItem: Identifiable, Hashable, Sendable {
    let id: String
    let project: String
    let projectName: String
    let projectPath: String
    let branch: String
    let summary: String
    let updatedAt: String
    let kind: WorktreeKind
    let path: String
    let upstream: String
    let head: String
    let createdDetail: String
    let diskUsage: String
    let canRemoveRemoteBranch: Bool
    let commits: [CommitEntry]
    var isDirty: Bool = false
    var dirtySummary: String = "干净"
    var platform: RepositoryPlatform = .local
}

struct MergeRequestItem: Identifiable, Hashable, Sendable {
    let id: String
    let project: String
    let projectName: String
    let projectPath: String
    let projectId: Int
    let iid: Int
    let title: String
    let subtitle: String
    let sourceBranch: String
    let targetBranch: String
    let author: String
    let authorUsername: String
    let updatedAt: String
    let approvalProgress: String
    let approvedByMe: Bool
    let status: MergeRequestStatus
    let pipeline: PipelineState
    let labels: [String]
    let protectedTarget: Bool
    let approvals: [ApprovalEntry]
    let activity: [ActivityEntry]
    let commits: [CommitEntry]
    let webURL: String

    var iidLabel: String { "!\(iid)" }
}

struct CreateWorktreeDraft: Sendable {
    var mode: CreateWorktreeMode = .newBranch
    var baseBranch: String = ""
    var branchName: String = ""
    var description: String = ""
    var path: String = ""
    var openInIDE: Bool = true
    var installDependencies: Bool = false
}

struct CreateMRDraft: Sendable {
    var sourceBranch: String = ""
    var targetBranch: String = ""
}

struct OperationState: Sendable {
    var isRunning = false
    var title = "空闲"
    var detail = "等待操作"
    var fractionCompleted: Double?
    var logs: [String] = []
    var errorMessage: String?
    var successMessage: String?

    static func idle(title: String) -> OperationState {
        OperationState(title: title, detail: "等待操作")
    }
}

@MainActor
@Observable
final class AppModel {
    private let service = WorkbenchService()

    var selectedSection: AppSection? = .worktrees

    var worktreeProjects: [LocalProject] = []
    var localMergeProjects: [MergeProject] = []
    var mergeProjects: [MergeProject] = []
    var worktrees: [WorktreeItem] = []
    var mergeRequests: [MergeRequestItem] = []

    var selectedProjectID: String?
    var selectedLocalProjectID: String?
    var selectedMergeProjectID: String?
    var selectedWorktreeID: String? {
        didSet {
            if selectedWorktreeID != oldValue {
                syncSelectedWorktreeDescriptionDraft()
                syncSelectedWorktreeDetails()
            }
        }
    }
    var activeConsoleTab: WorkbenchConsoleTab = .changes
    var consolePanelHeight: CGFloat = 220
    var isConsoleCollapsed: Bool = false
    var selectedWorktreeFileChanges: [WorktreeFileChange] = []
    var selectedWorktreeAheadBehind: AheadBehindCount? = nil
    var isLoadingConsoleDetails: Bool = false

    private var consoleDetailsTask: Task<Void, Never>?
    private var consoleDetailsGeneration: Int = 0
    var selectedMergeRequestID: String?
    var selectedMergeFilter: MergeRequestFilter = .open
    var selectedWorktreeCategory: WorktreeCategoryFilter = .all
    var selectedPlatformFilter: RepositoryPlatform = .all {
        didSet {
            if selectedPlatformFilter != oldValue {
                if selectedPlatformFilter != .all {
                    if let cur = currentWorktreeProject, cur.platform != selectedPlatformFilter {
                        selectedProjectID = filteredWorktreeProjects.first?.id
                    }
                    if let cur = currentLocalMergeProject, cur.platform != selectedPlatformFilter {
                        selectedLocalProjectID = filteredLocalMergeProjects.first?.id
                    }
                }
            }
        }
    }
    var sortOrder: [KeyPathComparator<WorktreeItem>] = [
        KeyPathComparator(\.branch, order: .forward)
    ]
    var gitVersion: String = "Git"

    var worktreeSearchText = ""
    var localBranchSearchText = ""
    var mergeRequestSearchText = ""

    var showingCreateWorktreeSheet = false
    var showingCreateMRSheet = false
    var showingBatchCreateMRSheet = false
    var createWorktreeDraft = CreateWorktreeDraft()
    var createMRDraft = CreateMRDraft()
    var selectedBatchMRMappingIDs = Set<String>()
    var selectedBatchApproveMRIDs = Set<String>()
    var worktreeDescriptionDraft = ""
    var worktreeDescriptionLoadedForID: String?
    var localOperationMode: LocalBranchOperationMode = .syncEnvironments
    var localOperationSourceBranch = ""
    var localOperationSingleTarget = ""
    var localOperationCustomTargets = Set<String>()

    var scannedTerminals: [InstalledTerminalApp] = []
    var scannedIDEs: [InstalledIDEApp] = []
    var deleteLocalBranchOnRemove = false

    // MARK: - Worktree Sweeper State
    var showingWorktreeSweeperSheet = false
    var sweeperItems: [WorktreeSweeperItem] = []
    var selectedSweeperIDs: Set<String> = []
    var selectedSweeperCategory: SweeperCategoryFilter = .all
    var sweeperDeleteLocalBranch: Bool = true
    var sweeperDeleteRemoteBranch: Bool = false
    var isSweeperAnalyzing: Bool = false
    var sweeperOperation = OperationState.idle(title: "空间清理")

    // MARK: - AI Branch Generator State
    var isAIGeneratingBranch: Bool = false
    var aiSuggestedAlternatives: [String] = []
    var aiGenerationError: String? = nil

    init() {
        scannedTerminals = TerminalService.shared.scanInstalledTerminals()
        scannedIDEs = IDEService.shared.scanInstalledIDEs()
    }
    var deleteRemoteBranchOnRemove = false

    var worktreeOperation = OperationState.idle(title: "工作树状态")
    var localOperation = OperationState.idle(title: "分支同步状态")
    var mrOperation = OperationState.idle(title: "MR 状态")
    var settingsOperation = OperationState.idle(title: "设置状态")

    var appConfig: GWorkbenchConfig?
    var worktreeConfig: WorktreeConfig?
    var localMergeContext: LocalMergeContext?
    var mergeRequestContext: MergeRequestContext?
    var settingsDraft = SettingsDraft()
    var settingsTokenVisible = false
    var globalErrorMessage: String?

    private var didBootstrap = false

    var effectiveWorktreeConfig: WorktreeConfig? {
        if let app = appConfig {
            return app.asWorktreeConfig()
        }
        return worktreeConfig
    }

    var currentIDELabel: String {
        if let label = effectiveWorktreeConfig?.ideLabel, !label.isEmpty {
            return label
        }
        if !settingsDraft.ideLabel.isEmpty {
            return settingsDraft.ideLabel
        }
        return "IDE"
    }

    var selectedWorktree: WorktreeItem? {
        filteredWorktrees.first(where: { $0.id == selectedWorktreeID })
            ?? worktrees.first(where: { $0.id == selectedWorktreeID })
    }

    var selectedMergeRequest: MergeRequestItem? {
        filteredMergeRequests.first(where: { $0.id == selectedMergeRequestID })
            ?? mergeRequests.first(where: { $0.id == selectedMergeRequestID })
    }

    var currentWorktreeProject: LocalProject? {
        if let id = selectedProjectID {
            return filteredWorktreeProjects.first(where: { $0.id == id })
                ?? worktreeProjects.first(where: { $0.id == id })
        }
        return filteredWorktreeProjects.first ?? worktreeProjects.first
    }

    var currentLocalMergeProject: MergeProject? {
        if let id = selectedLocalProjectID {
            return filteredLocalMergeProjects.first(where: { $0.id == id })
                ?? localMergeProjects.first(where: { $0.id == id })
        }
        return filteredLocalMergeProjects.first ?? localMergeProjects.first
    }

    var filteredWorktreeProjects: [LocalProject] {
        worktreeProjects.filter { project in
            selectedPlatformFilter == .all || project.platform == selectedPlatformFilter
        }
    }

    var filteredLocalMergeProjects: [MergeProject] {
        localMergeProjects.filter { project in
            selectedPlatformFilter == .all || project.platform == selectedPlatformFilter
        }
    }

    func projectCount(for platform: RepositoryPlatform) -> Int {
        if platform == .all {
            return worktreeProjects.count
        }
        return worktreeProjects.filter { $0.platform == platform }.count
    }

    func localMergeProjectCount(for platform: RepositoryPlatform) -> Int {
        if platform == .all {
            return localMergeProjects.count
        }
        return localMergeProjects.filter { $0.platform == platform }.count
    }

    var availablePlatforms: [RepositoryPlatform] {
        let platforms = Set(worktreeProjects.map(\.platform))
        var list: [RepositoryPlatform] = [.all]
        for p in [RepositoryPlatform.gitlab, RepositoryPlatform.github, RepositoryPlatform.local] {
            if platforms.contains(p) {
                list.append(p)
            }
        }
        return list
    }

    var currentMergeProject: MergeProject? {
        mergeProjects.first(where: { $0.id == selectedMergeProjectID }) ?? mergeProjects.first
    }

    var worktreeCountByProject: [String: Int] {
        Dictionary(grouping: worktrees.filter { $0.kind == .worktree }, by: \.project).mapValues(\.count)
    }

    var realWorktreesCount: Int {
        worktrees.filter { $0.kind == .worktree }.count
    }

    var mergeCountByFilter: [MergeRequestFilter: Int] {
        Dictionary(uniqueKeysWithValues: MergeRequestFilter.allCases.map { filter in
            (filter, mergeRequests(for: filter).count)
        })
    }

    var filteredWorktrees: [WorktreeItem] {
        guard let currentProject = currentWorktreeProject else {
            return []
        }
        return worktrees.filter { item in
            guard item.projectPath == currentProject.path else { return false }

            switch selectedWorktreeCategory {
            case .all:
                break
            case .active:
                if item.kind != .worktree { return false }
            case .modified:
                if !item.isDirty { return false }
            case .mainRepo:
                if item.kind != .mainRepo { return false }
            }

            if !worktreeSearchText.isEmpty {
                let match = item.branch.localizedCaseInsensitiveContains(worktreeSearchText) ||
                    item.summary.localizedCaseInsensitiveContains(worktreeSearchText) ||
                    item.path.localizedCaseInsensitiveContains(worktreeSearchText) ||
                    item.head.localizedCaseInsensitiveContains(worktreeSearchText)
                if !match { return false }
            }
            return true
        }
    }

    var sortedWorktrees: [WorktreeItem] {
        filteredWorktrees.sorted(using: sortOrder)
    }

    var currentProjectWorktreeCount: Int {
        guard let project = currentWorktreeProject else { return 0 }
        return worktrees.filter { $0.projectPath == project.path }.count
    }

    var currentProjectTotalDiskUsage: String {
        guard let project = currentWorktreeProject else { return "0 MB" }
        let projectWorktrees = worktrees.filter { $0.projectPath == project.path }
        guard !projectWorktrees.isEmpty else { return "0 MB" }

        var totalBytes: Int64 = 0
        var hasValid = false

        for item in projectWorktrees {
            let str = item.diskUsage.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if str.hasSuffix("G") || str.hasSuffix("GB") {
                let numStr = str.replacingOccurrences(of: "GB", with: "").replacingOccurrences(of: "G", with: "")
                if let num = Double(numStr) {
                    totalBytes += Int64(num * 1024 * 1024 * 1024)
                    hasValid = true
                }
            } else if str.hasSuffix("M") || str.hasSuffix("MB") {
                let numStr = str.replacingOccurrences(of: "MB", with: "").replacingOccurrences(of: "M", with: "")
                if let num = Double(numStr) {
                    totalBytes += Int64(num * 1024 * 1024)
                    hasValid = true
                }
            } else if str.hasSuffix("K") || str.hasSuffix("KB") {
                let numStr = str.replacingOccurrences(of: "KB", with: "").replacingOccurrences(of: "K", with: "")
                if let num = Double(numStr) {
                    totalBytes += Int64(num * 1024)
                    hasValid = true
                }
            } else if str.hasSuffix("B") {
                let numStr = str.replacingOccurrences(of: "B", with: "")
                if let num = Double(numStr) {
                    totalBytes += Int64(num)
                    hasValid = true
                }
            }
        }

        if !hasValid {
            return "未知"
        }

        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useAll]
        byteCountFormatter.countStyle = .file
        byteCountFormatter.zeroPadsFractionDigits = false
        byteCountFormatter.includesActualByteCount = false
        return byteCountFormatter.string(fromByteCount: totalBytes)
    }

    // MARK: - Sweeper Computeds & Methods

    var filteredSweeperItems: [WorktreeSweeperItem] {
        sweeperItems.filter { item in
            switch selectedSweeperCategory {
            case .all:
                return true
            case .merged:
                if case .merged = item.statusType { return true }
                if case .remoteDeleted = item.statusType { return true }
                return false
            case .stale:
                if case .stale = item.statusType { return true }
                return false
            case .protected:
                return item.isProtected
            }
        }
    }

    var sweeperRecommendedCount: Int {
        sweeperItems.filter(\.isRecommended).count
    }

    var sweeperRecommendedSpaceFormatted: String {
        let totalMB = sweeperItems.filter(\.isRecommended).reduce(0.0) { $0 + $1.approxSizeMB }
        return Self.formatSizeMB(totalMB)
    }

    var sweeperSelectedCount: Int {
        sweeperItems.filter { selectedSweeperIDs.contains($0.id) }.count
    }

    var sweeperSelectedSpaceFormatted: String {
        let totalMB = sweeperItems
            .filter { selectedSweeperIDs.contains($0.id) }
            .reduce(0.0) { $0 + $1.approxSizeMB }
        return Self.formatSizeMB(totalMB)
    }

    func openWorktreeSweeper() {
        showingWorktreeSweeperSheet = true
        Task {
            await analyzeCurrentProjectWorktrees()
        }
    }

    func selectSmartSweeper() {
        selectedSweeperIDs = Set(sweeperItems.filter(\.isRecommended).map(\.id))
    }

    func clearSweeperSelection() {
        selectedSweeperIDs.removeAll()
    }

    func toggleSweeperSelection(id: String) {
        guard let item = sweeperItems.first(where: { $0.id == id }), !item.isProtected else {
            return
        }
        if selectedSweeperIDs.contains(id) {
            selectedSweeperIDs.remove(id)
        } else {
            selectedSweeperIDs.insert(id)
        }
    }

    func analyzeCurrentProjectWorktrees() async {
        guard let project = currentWorktreeProject else { return }
        isSweeperAnalyzing = true
        sweeperOperation = OperationState(isRunning: true, title: "正在分析", detail: "正在比对分支合并状态与活跃度...")

        let projectWorktrees = worktrees.filter { $0.projectPath == project.path }
        let gitCli = service.gitCliService
        let projectPath = project.path
        let baseBranches = project.baseBranches.isEmpty ? ["master", "main", "uat", "pre_prod"] : project.baseBranches

        var results: [WorktreeSweeperItem] = []

        for item in projectWorktrees {
            let isMain = item.kind == .mainRepo
            let isDirty = item.isDirty
            let sizeMB = Self.parseDiskUsageToMB(item.diskUsage)

            if isMain {
                results.append(
                    WorktreeSweeperItem(
                        id: item.id,
                        worktree: item,
                        statusType: .mainRepo,
                        statusTitle: "主仓库 (基准)",
                        statusDescription: "生产代码基准目录，受系统强制保护",
                        isProtected: true,
                        isRecommended: false,
                        diskUsageFormatted: item.diskUsage,
                        approxSizeMB: sizeMB
                    )
                )
                continue
            }

            if isDirty {
                results.append(
                    WorktreeSweeperItem(
                        id: item.id,
                        worktree: item,
                        statusType: .dirty,
                        statusTitle: "有未提交改动",
                        statusDescription: item.dirtySummary,
                        isProtected: true,
                        isRecommended: false,
                        diskUsageFormatted: item.diskUsage,
                        approxSizeMB: sizeMB
                    )
                )
                continue
            }

            // 检查是否已被 merge
            let mergeCheck = gitCli.checkBranchMerged(projectPath: projectPath, branch: item.branch, candidateBases: baseBranches)
            if mergeCheck.isMerged, let target = mergeCheck.mergedTarget {
                results.append(
                    WorktreeSweeperItem(
                        id: item.id,
                        worktree: item,
                        statusType: .merged(target: target),
                        statusTitle: "✓ 已合入 \(target)",
                        statusDescription: "该分支代码已完整并入上游基准分支",
                        isProtected: false,
                        isRecommended: true,
                        diskUsageFormatted: item.diskUsage,
                        approxSizeMB: sizeMB
                    )
                )
                continue
            }

            // 检查远端分支是否存在
            let hasRemote = (try? gitCli.remoteBranchExists(projectPath: projectPath, branch: item.branch)) ?? true
            if !hasRemote {
                results.append(
                    WorktreeSweeperItem(
                        id: item.id,
                        worktree: item,
                        statusType: .remoteDeleted,
                        statusTitle: "✓ 远端分支已删除",
                        statusDescription: "远端 tracking 分支已移除，本地为残留工作树",
                        isProtected: false,
                        isRecommended: true,
                        diskUsageFormatted: item.diskUsage,
                        approxSizeMB: sizeMB
                    )
                )
                continue
            }

            // 检查最后更新时间是否超过 30 天
            let isOlderThan30Days = item.updatedAt.contains("月") || item.updatedAt.contains("年") || (item.updatedAt.contains("天") && (Int(item.updatedAt.prefix(2)) ?? 0) >= 30)
            if isOlderThan30Days {
                results.append(
                    WorktreeSweeperItem(
                        id: item.id,
                        worktree: item,
                        statusType: .stale(days: 30),
                        statusTitle: "⏳ 长期休眠分支",
                        statusDescription: "超过 30 天未更新，且工作区完全整洁",
                        isProtected: false,
                        isRecommended: true,
                        diskUsageFormatted: item.diskUsage,
                        approxSizeMB: sizeMB
                    )
                )
                continue
            }

            // 活跃开发中的干净分支
            results.append(
                WorktreeSweeperItem(
                    id: item.id,
                    worktree: item,
                    statusType: .active,
                    statusTitle: "活跃开发中",
                    statusDescription: "工作区整洁，尚未合入目标分支",
                    isProtected: false,
                    isRecommended: false,
                    diskUsageFormatted: item.diskUsage,
                    approxSizeMB: sizeMB
                )
            )
        }

        sweeperItems = results
        selectedSweeperIDs = Set(results.filter(\.isRecommended).map(\.id))
        isSweeperAnalyzing = false
        sweeperOperation = OperationState(
            isRunning: false,
            title: "分析就绪",
            detail: "发现 \(sweeperRecommendedCount) 个建议清理项，预计释放 \(sweeperRecommendedSpaceFormatted)"
        )
    }

    func executeSweeperPurge() async {
        guard let config = effectiveWorktreeConfig, let project = currentWorktreeProject else { return }
        let toPurge = sweeperItems.filter { selectedSweeperIDs.contains($0.id) && !$0.isProtected }
        guard !toPurge.isEmpty else { return }

        sweeperOperation = OperationState(
            isRunning: true,
            title: "正在安全回收",
            detail: "准备回收 \(toPurge.count) 个工作树..."
        )

        var purgedCount = 0
        for (index, item) in toPurge.enumerated() {
            sweeperOperation = OperationState(
                isRunning: true,
                title: "正在安全回收 (\(index + 1)/\(toPurge.count))",
                detail: "正在删除: \(item.worktree.branch)",
                fractionCompleted: Double(index + 1) / Double(toPurge.count)
            )

            do {
                try await service.removeWorktree(
                    config: config,
                    item: item.worktree,
                    deleteLocalBranch: sweeperDeleteLocalBranch,
                    deleteRemoteBranch: sweeperDeleteRemoteBranch
                ) { _ in }
                purgedCount += 1
            } catch {
                appendWorktreeLog("回收工作树失败: \(item.worktree.branch) - \(error.localizedDescription)")
            }
        }

        // 全局 prune
        service.gitCliService.pruneWorktrees(projectPath: project.path)

        await refreshWorktrees()
        await analyzeCurrentProjectWorktrees()

        sweeperOperation = OperationState(
            isRunning: false,
            title: "回收完成",
            detail: "已成功释放 \(purgedCount) 个工作树目录与空间",
            fractionCompleted: 1,
            successMessage: "成功回收 \(purgedCount) 个工作树！"
        )
    }

    static func parseDiskUsageToMB(_ usage: String) -> Double {
        let trimmed = usage.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasSuffix("G") || trimmed.hasSuffix("GB") {
            let numStr = trimmed.replacingOccurrences(of: "GB", with: "").replacingOccurrences(of: "G", with: "").trimmingCharacters(in: .whitespaces)
            return (Double(numStr) ?? 0) * 1024
        } else if trimmed.hasSuffix("M") || trimmed.hasSuffix("MB") {
            let numStr = trimmed.replacingOccurrences(of: "MB", with: "").replacingOccurrences(of: "M", with: "").trimmingCharacters(in: .whitespaces)
            return Double(numStr) ?? 0
        } else if trimmed.hasSuffix("K") || trimmed.hasSuffix("KB") {
            let numStr = trimmed.replacingOccurrences(of: "KB", with: "").replacingOccurrences(of: "K", with: "").trimmingCharacters(in: .whitespaces)
            return (Double(numStr) ?? 0) / 1024
        }
        return 0
    }

    static func formatSizeMB(_ totalMB: Double) -> String {
        if totalMB >= 1024 {
            return String(format: "%.2f GB", totalMB / 1024)
        } else {
            return String(format: "%.0f MB", totalMB)
        }
    }

    var mrSortOrder = [KeyPathComparator(\MergeRequestItem.iid, order: .reverse)]

    var filteredMergeRequests: [MergeRequestItem] {
        mergeRequests(for: selectedMergeFilter).filter { item in
            mergeRequestSearchText.isEmpty ||
            item.iidLabel.localizedCaseInsensitiveContains(mergeRequestSearchText) ||
            item.title.localizedCaseInsensitiveContains(mergeRequestSearchText) ||
            item.sourceBranch.localizedCaseInsensitiveContains(mergeRequestSearchText) ||
            item.targetBranch.localizedCaseInsensitiveContains(mergeRequestSearchText) ||
            item.author.localizedCaseInsensitiveContains(mergeRequestSearchText)
        }
    }

    var sortedMergeRequests: [MergeRequestItem] {
        filteredMergeRequests.sorted(using: mrSortOrder)
    }

    var availableBaseBranches: [String] {
        currentWorktreeProject?.baseBranches.nonEmptyArray ?? ["main", "master"]
    }

    var availableExistingWorktreeBranches: [String] {
        availableExistingWorktreeBranchOptions.map(\.name)
    }

    var availableExistingWorktreeBranchOptions: [ExistingWorktreeBranchOption] {
        guard let project = currentWorktreeProject else { return [] }

        let local = Set(project.localBranches)
        let remote = Set(project.baseBranches)
        let names = Array(local.union(remote)).sorted()

        return names.map { name in
            let source: ExistingWorktreeBranchSource
            switch (local.contains(name), remote.contains(name)) {
            case (true, true):
                source = .localAndRemote
            case (true, false):
                source = .local
            case (false, true):
                source = .remoteOnly
            default:
                source = .local
            }
            return ExistingWorktreeBranchOption(name: name, source: source)
        }
    }

    var availableMRMappings: [BranchMapping] {
        currentMergeProject?.branchMappings ?? []
    }

    var availableMRSourceBranches: [String] {
        currentMergeProject?.remoteBranches.nonEmptyArray ?? []
    }

    var availableMRTargetBranches: [String] {
        let targets = availableMRMappings.map(\.target)
        return Array(NSOrderedSet(array: targets)) as? [String] ?? targets
    }

    var availableBatchMRMappings: [BranchMapping] {
        availableMRMappings.filter { !$0.protectedTarget }
    }

    var selectedBatchMRMappings: [BranchMapping] {
        availableBatchMRMappings.filter { selectedBatchMRMappingIDs.contains($0.id) }
    }

    var canCreateSelectedBatchMRs: Bool {
        !mrOperation.isRunning && !selectedBatchMRMappings.isEmpty
    }

    var canBatchApproveSelectedMRs: Bool {
        !mrOperation.isRunning && !selectedBatchApproveMRs.isEmpty
    }

    var filteredLocalBranches: [String] {
        guard let project = currentLocalMergeProject else { return [] }
        let filtered = project.localBranches.filter {
            localBranchSearchText.isEmpty || $0.localizedCaseInsensitiveContains(localBranchSearchText)
        }
        if filtered.isEmpty, !localBranchSearchText.isEmpty, project.localBranches.contains(localOperationSourceBranch) {
            return [localOperationSourceBranch]
        }
        return filtered
    }

    var localTargetOptions: [LocalBranchTargetOption] {
        guard let context = localMergeContext, let project = currentLocalMergeProject else { return [] }
        return context.config.envBranches.map { envBranch in
            LocalBranchTargetOption(
                envBranch: envBranch,
                targetBranch: mergeBranchName(envBranch: envBranch, projectName: project.name, middle: context.config.mergeBranchMiddle)
            )
        }
    }

    var resolvedLocalOperationTargets: [String] {
        switch localOperationMode {
        case .syncEnvironments, .mergeAll:
            return localTargetOptions.map(\.targetBranch)
        case .mergeCustom:
            return localTargetOptions
                .map(\.targetBranch)
                .filter { localOperationCustomTargets.contains($0) }
        }
    }

    var localOperationPreviewLines: [String] {
        guard let project = currentLocalMergeProject else {
            return ["当前还没有可执行的本地项目。"]
        }

        var lines = [
            "项目: \(project.displayName)",
            "仓库路径: \(project.path)",
            "执行模式: \(localOperationMode.rawValue)",
            ""
        ]

        if localOperationMode.requiresSourceBranch {
            lines.append("源分支: \(localOperationSourceBranch.nonEmpty ?? "未选择")")
            lines.append("目标分支数: \(resolvedLocalOperationTargets.count)")
            lines.append("")
        }

        lines.append("即将执行:")
        switch localOperationMode {
        case .syncEnvironments:
            for option in localTargetOptions {
                lines.append("- 更新环境分支 `\(option.envBranch)` 并 pull 最新代码")
                lines.append("- 同步到合并分支 `\(option.targetBranch)` 并 push")
            }
        case .mergeAll, .mergeCustom:
            for target in resolvedLocalOperationTargets {
                lines.append("- checkout `\(target)`")
                lines.append("- merge `\(localOperationSourceBranch)` 到 `\(target)`")
                lines.append("- push `\(target)`")
            }
        }

        if resolvedLocalOperationTargets.isEmpty && localOperationMode != .syncEnvironments {
            lines.append("- 当前还没有选中任何目标分支")
        }

        return lines
    }

    var visibleOpenMergeRequests: [MergeRequestItem] {
        filteredMergeRequests.filter { [.open, .ready, .blocked, .draft].contains($0.status) }
    }

    var selectedBatchApproveMRs: [MergeRequestItem] {
        mergeRequests.filter {
            selectedBatchApproveMRIDs.contains($0.id) &&
            [.open, .ready, .blocked, .draft].contains($0.status)
        }
    }

    var areAllVisibleOpenMergeRequestsSelected: Bool {
        !visibleOpenMergeRequests.isEmpty && visibleOpenMergeRequests.allSatisfy {
            selectedBatchApproveMRIDs.contains($0.id)
        }
    }

    var canExecuteLocalOperation: Bool {
        guard currentLocalMergeProject != nil else { return false }
        if localOperation.isRunning {
            return false
        }
        switch localOperationMode {
        case .syncEnvironments:
            return !localTargetOptions.isEmpty
        case .mergeAll:
            return localOperationSourceBranch.nonEmpty != nil && !localTargetOptions.isEmpty
        case .mergeCustom:
            return localOperationSourceBranch.nonEmpty != nil && !resolvedLocalOperationTargets.isEmpty
        }
    }

    func bootstrap() async {
        guard !didBootstrap else {
            return
        }
        didBootstrap = true
        if let ver = try? GitCliService().gitVersion() {
            gitVersion = ver
        }
        await refreshSettings()
        await refreshWorktrees()
        await refreshLocalMergeProjects()
        await refreshMergeProjects()
    }

    func refreshSettings() async {
        refreshScannedTerminals()
        refreshScannedIDEs()
        settingsOperation = OperationState(isRunning: true, title: "读取设置", detail: "正在加载 GWorkbench 配置")
        do {
            let config = try await service.loadWorkbenchConfig()
            appConfig = config
            worktreeConfig = config.asWorktreeConfig()
            settingsDraft = SettingsDraft(config: config)
            settingsTokenVisible = false
            settingsOperation = OperationState(
                isRunning: false,
                title: "设置已加载",
                detail: "当前使用独立的 GWorkbench 配置文件",
                fractionCompleted: 1,
                successMessage: "配置读取完成"
            )
        } catch {
            settingsOperation = OperationState(
                isRunning: false,
                title: "读取设置失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
            globalErrorMessage = error.localizedDescription
        }
    }

    func refreshWorktrees() async {
        appendWorktreeLog("开始扫描工作树...")
        worktreeOperation = OperationState(
            isRunning: true,
            title: "刷新工作树",
            detail: "开始读取本地配置",
            logs: worktreeOperation.logs
        )
        globalErrorMessage = nil

        do {
            if gitVersion == "Git" || gitVersion.isEmpty {
                if let ver = try? GitCliService().gitVersion() {
                    gitVersion = ver
                }
            }

            let snapshot = try await service.loadWorktreeSnapshot { [weak self] progress in
                Task { @MainActor in
                    self?.worktreeOperation = OperationState(
                        isRunning: true,
                        title: progress.title,
                        detail: progress.detail,
                        fractionCompleted: progress.fractionCompleted,
                        logs: self?.worktreeOperation.logs ?? []
                    )
                }
            }

            worktreeConfig = snapshot.config
            worktreeProjects = snapshot.projects
            worktrees = snapshot.worktrees

            if selectedProjectID == nil || !worktreeProjects.contains(where: { $0.id == selectedProjectID }) {
                selectedProjectID = worktreeProjects.first?.id
            }

            if selectedWorktreeID == nil || !filteredWorktrees.contains(where: { $0.id == selectedWorktreeID }) {
                selectedWorktreeID = filteredWorktrees.first?.id
            }

            syncSelectedWorktreeDescriptionDraft()
            syncSelectedWorktreeDetails()
            syncCreateWorktreeDefaults(resetBranchName: false)

            appendWorktreeLog("工作树刷新完成：已同步 \(snapshot.projects.count) 个项目和 \(snapshot.worktrees.count) 个工作树")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "工作树已刷新",
                detail: "已同步 \(snapshot.projects.count) 个项目和 \(snapshot.worktrees.count) 个工作树",
                fractionCompleted: 1,
                logs: worktreeOperation.logs,
                successMessage: "刷新完成"
            )
        } catch {
            appendWorktreeLog("工作树刷新失败: \(error.localizedDescription)")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "工作树刷新失败",
                detail: error.localizedDescription,
                logs: worktreeOperation.logs,
                errorMessage: error.localizedDescription
            )
            globalErrorMessage = error.localizedDescription
        }
    }

    func refreshLocalMergeProjects() async {
        localOperation = OperationState(isRunning: true, title: "刷新分支同步项目", detail: "开始读取本地配置")
        globalErrorMessage = nil

        do {
            let context = try await service.loadLocalMergeContext { [weak self] progress in
                Task { @MainActor in
                    self?.localOperation = OperationState(
                        isRunning: true,
                        title: progress.title,
                        detail: progress.detail,
                        fractionCompleted: progress.fractionCompleted
                    )
                }
            }

            localMergeContext = context
            localMergeProjects = context.projects

            if selectedLocalProjectID == nil || !localMergeProjects.contains(where: { $0.id == selectedLocalProjectID }) {
                selectedLocalProjectID = localMergeProjects.first?.id
            }

            syncLocalOperationDefaults(resetSourceBranch: false)

            localOperation = OperationState(
                isRunning: false,
                title: "分支同步项目已刷新",
                detail: "已同步 \(context.projects.count) 个本地仓库",
                fractionCompleted: 1,
                successMessage: "刷新完成"
            )
        } catch {
            localOperation = OperationState(
                isRunning: false,
                title: "分支同步项目刷新失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
            globalErrorMessage = error.localizedDescription
        }
    }

    func refreshMergeProjects() async {
        mrOperation = OperationState(isRunning: true, title: "刷新合并项目", detail: "开始读取配置")
        globalErrorMessage = nil

        do {
            let context = try await service.loadMergeContext { [weak self] progress in
                Task { @MainActor in
                    self?.mrOperation = OperationState(
                        isRunning: true,
                        title: progress.title,
                        detail: progress.detail,
                        fractionCompleted: progress.fractionCompleted
                    )
                }
            }
            mergeRequestContext = context
            mergeProjects = context.projects

            if selectedMergeProjectID == nil || !mergeProjects.contains(where: { $0.id == selectedMergeProjectID }) {
                selectedMergeProjectID = mergeProjects.first?.id
            }

            await refreshMergeRequests()
        } catch {
            mrOperation = OperationState(
                isRunning: false,
                title: "合并项目刷新失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
            globalErrorMessage = error.localizedDescription
        }
    }

    func refreshMergeRequests() async {
        guard let context = mergeRequestContext, let project = currentMergeProject else {
            mergeRequests = []
            selectedMergeRequestID = nil
            return
        }

        mrOperation = OperationState(isRunning: true, title: "刷新待合并列表", detail: "正在读取 \(project.displayName)")

        do {
            let items = try await service.loadPendingMergeRequests(context: context, project: project) { [weak self] progress in
                Task { @MainActor in
                    self?.mrOperation = OperationState(
                        isRunning: true,
                        title: progress.title,
                        detail: progress.detail,
                        fractionCompleted: progress.fractionCompleted
                    )
                }
            }

            mergeRequests = items
            selectedBatchApproveMRIDs.formIntersection(items.map(\.id))
            if selectedMergeRequestID == nil || !filteredMergeRequests.contains(where: { $0.id == selectedMergeRequestID }) {
                selectedMergeRequestID = filteredMergeRequests.first?.id
            }

            mrOperation = OperationState(
                isRunning: false,
                title: "待合并列表已刷新",
                detail: "当前项目共有 \(items.count) 条打开中的 MR",
                fractionCompleted: 1,
                successMessage: "刷新完成"
            )
        } catch {
            mrOperation = OperationState(
                isRunning: false,
                title: "待合并列表刷新失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
            globalErrorMessage = error.localizedDescription
        }
    }

    func selectProject(_ projectID: String) {
        selectedProjectID = projectID
        if !filteredWorktrees.contains(where: { $0.id == selectedWorktreeID }) {
            selectedWorktreeID = filteredWorktrees.first?.id
        }
        syncSelectedWorktreeDescriptionDraft()
        syncSelectedWorktreeDetails()
        syncCreateWorktreeDefaults(resetBranchName: false)
    }

    func selectLocalProject(_ projectID: String) {
        selectedLocalProjectID = projectID
        syncLocalOperationDefaults(resetSourceBranch: false)
    }

    func selectMergeProject(_ projectID: String) {
        selectedMergeProjectID = projectID
        selectedBatchApproveMRIDs.removeAll()
        createMRDraft = CreateMRDraft()
        Task {
            await refreshMergeRequests()
        }
    }

    func selectMergeFilter(_ filter: MergeRequestFilter) {
        selectedMergeFilter = filter
        if !filteredMergeRequests.contains(where: { $0.id == selectedMergeRequestID }) {
            selectedMergeRequestID = filteredMergeRequests.first?.id
        }
    }

    func prepareCreateWorktree() {
        syncCreateWorktreeDefaults(resetBranchName: true)
        aiSuggestedAlternatives = []
        aiGenerationError = nil
        showingCreateWorktreeSheet = true
    }

    func setLocalOperationMode(_ mode: LocalBranchOperationMode) {
        localOperationMode = mode
        syncLocalOperationDefaults(resetSourceBranch: false)
    }

    func toggleCustomLocalTarget(_ target: String) {
        if localOperationCustomTargets.contains(target) {
            localOperationCustomTargets.remove(target)
        } else {
            localOperationCustomTargets.insert(target)
        }
    }

    func selectAllLocalCustomTargets() {
        let targets = localTargetOptions.map(\.targetBranch)
        localOperationCustomTargets = Set(targets)
    }

    func deselectAllLocalCustomTargets() {
        localOperationCustomTargets.removeAll()
    }

    func selectCurrentHeadAsLocalSourceBranch() {
        if let current = currentLocalMergeProject?.currentBranch, !current.isEmpty {
            localOperationSourceBranch = current
        } else if let first = currentLocalMergeProject?.localBranches.first {
            localOperationSourceBranch = first
        }
    }

    func appendLocalOperationLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        localOperation.logs.append("[\(timestamp)] \(message)")
    }

    func clearLocalOperationLogs() {
        localOperation.logs.removeAll()
    }

    func copyLocalOperationLogs() {
        let text = localOperation.logs.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func openProjectInIDE(_ project: MergeProject) {
        guard let config = effectiveWorktreeConfig else { return }
        do {
            try service.openInIDE(config: config, path: project.path)
            appendLocalOperationLog("已在 \(config.ideLabel) 中打开: \(project.displayName)")
        } catch {
            appendLocalOperationLog("打开 IDE 失败: \(error.localizedDescription)")
        }
    }

    func openProjectInTerminal(_ project: MergeProject) {
        let termName = appConfig?.terminalApp ?? settingsDraft.terminalApp
        let bundleID = appConfig?.terminalBundleID ?? settingsDraft.terminalBundleID
        let hookMode = appConfig?.terminalLaunchHookMode ?? settingsDraft.terminalLaunchHookMode
        let hookCmd = appConfig?.terminalLaunchCommand ?? settingsDraft.terminalLaunchCommand
        do {
            try TerminalService.shared.openDirectoryWithHook(
                path: project.path,
                terminalName: termName,
                bundleID: bundleID,
                hookMode: hookMode,
                hookCommand: hookCmd
            )
            appendLocalOperationLog("已在 \(termName) 中打开: \(project.displayName)")
        } catch {
            appendLocalOperationLog("打开终端失败: \(error.localizedDescription)")
        }
    }

    func copyProjectPath(_ project: MergeProject) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(project.path, forType: .string)
        appendLocalOperationLog("已复制物理路径: \(project.path)")
    }

    func openMRInBrowser(_ item: MergeRequestItem) {
        if let url = URL(string: item.webURL) {
            NSWorkspace.shared.open(url)
        }
    }

    func copyMRWebURL(_ item: MergeRequestItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.webURL, forType: .string)
    }

    func copyMRSourceBranch(_ item: MergeRequestItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.sourceBranch, forType: .string)
    }

    func copyMRTargetBranch(_ item: MergeRequestItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.targetBranch, forType: .string)
    }

    func syncCreateWorktreeDefaults(resetBranchName: Bool) {
        let branchName = resetBranchName ? "" : createWorktreeDraft.branchName
        let projectName = currentWorktreeProject?.name ?? "project"
        let baseBranch = createWorktreeDraft.baseBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (availableBaseBranches.first ?? "main")
            : createWorktreeDraft.baseBranch
        createWorktreeDraft.baseBranch = availableBaseBranches.contains(baseBranch) ? baseBranch : (availableBaseBranches.first ?? "main")
        if resetBranchName {
            createWorktreeDraft.mode = .newBranch
            createWorktreeDraft.branchName = ""
            createWorktreeDraft.description = ""
        } else {
            createWorktreeDraft.branchName = branchName
        }
        if createWorktreeDraft.mode == .existingBranch,
           createWorktreeDraft.branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            createWorktreeDraft.branchName = availableExistingWorktreeBranchOptions.first?.name ?? ""
        }
        createWorktreeDraft.path = suggestedWorktreePath(projectName: projectName, branchName: createWorktreeDraft.branchName)
    }

    func syncLocalOperationDefaults(resetSourceBranch: Bool) {
        let branches = currentLocalMergeProject?.localBranches ?? []
        let targets = localTargetOptions.map(\.targetBranch)

        if resetSourceBranch || localOperationSourceBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !branches.contains(localOperationSourceBranch) {
            localOperationSourceBranch = branches.first ?? ""
        }

        if localOperationSingleTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !targets.contains(localOperationSingleTarget) {
            localOperationSingleTarget = targets.first ?? ""
        }

        let validCustomTargets = Set(targets)
        localOperationCustomTargets = localOperationCustomTargets.intersection(validCustomTargets)
        if localOperationMode == .mergeCustom,
           localOperationCustomTargets.isEmpty,
           let firstTarget = targets.first {
            localOperationCustomTargets = [firstTarget]
        }
    }

    func setCreateWorktreeMode(_ mode: CreateWorktreeMode) {
        createWorktreeDraft.mode = mode
        if mode == .existingBranch,
           createWorktreeDraft.branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            createWorktreeDraft.branchName = availableExistingWorktreeBranchOptions.first?.name ?? ""
        }
        updateCreateWorktreePathFromBranch()
    }

    func updateCreateWorktreePathFromBranch() {
        let projectName = currentWorktreeProject?.name ?? "project"
        createWorktreeDraft.path = suggestedWorktreePath(projectName: projectName, branchName: createWorktreeDraft.branchName)
    }

    func syncSelectedWorktreeDescriptionDraft() {
        guard let item = selectedWorktree else {
            worktreeDescriptionDraft = ""
            worktreeDescriptionLoadedForID = nil
            return
        }

        guard worktreeDescriptionLoadedForID != item.id else { return }
        worktreeDescriptionDraft = summaryAsEditableDescription(item)
        worktreeDescriptionLoadedForID = item.id
    }

    func appendWorktreeLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        worktreeOperation.logs.append("[\(timestamp)] \(message)")
    }

    func clearWorktreeLogs() {
        worktreeOperation.logs.removeAll()
    }

    func openWorktreeInIDE(_ item: WorktreeItem) {
        guard let config = effectiveWorktreeConfig else { return }
        do {
            try service.openInIDE(config: config, path: item.path)
            appendWorktreeLog("已在 \(config.ideLabel) 中打开: \(item.branch) (\(item.path))")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "已打开 IDE",
                detail: item.path,
                logs: worktreeOperation.logs,
                successMessage: "已使用 \(config.ideLabel) 打开"
            )
        } catch {
            appendWorktreeLog("打开 IDE 失败: \(error.localizedDescription)")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "打开 IDE 失败",
                detail: error.localizedDescription,
                logs: worktreeOperation.logs,
                errorMessage: error.localizedDescription
            )
        }
    }

    func openWorktreeInTerminal(_ item: WorktreeItem) {
        let termName = appConfig?.terminalApp ?? settingsDraft.terminalApp
        let bundleID = appConfig?.terminalBundleID ?? settingsDraft.terminalBundleID
        let hookMode = appConfig?.terminalLaunchHookMode ?? settingsDraft.terminalLaunchHookMode
        let hookCmd = appConfig?.terminalLaunchCommand ?? settingsDraft.terminalLaunchCommand
        do {
            try TerminalService.shared.openDirectoryWithHook(
                path: item.path,
                terminalName: termName,
                bundleID: bundleID,
                hookMode: hookMode,
                hookCommand: hookCmd
            )
            appendWorktreeLog("已在 \(termName) 中打开: \(item.branch) (\(item.path))")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "已打开终端",
                detail: item.path,
                logs: worktreeOperation.logs,
                successMessage: "已在 \(termName) 中打开"
            )
        } catch {
            appendWorktreeLog("打开终端失败: \(error.localizedDescription)")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "打开终端失败",
                detail: error.localizedDescription,
                logs: worktreeOperation.logs,
                errorMessage: error.localizedDescription
            )
        }
    }

    func copyWorktreePath(_ item: WorktreeItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.path, forType: .string)
        appendWorktreeLog("已复制物理路径: \(item.path)")
    }

    func copyWorktreeBranch(_ item: WorktreeItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.branch, forType: .string)
        appendWorktreeLog("已复制分支名称: \(item.branch)")
    }

    func openFileInIDE(path: String) {
        guard let item = selectedWorktree else { return }
        let fullPath: String
        if path.hasPrefix("/") {
            fullPath = path
        } else {
            fullPath = URL(fileURLWithPath: item.path).appendingPathComponent(path).path
        }
        do {
            if let config = effectiveWorktreeConfig {
                try service.openInIDE(config: config, path: fullPath)
                appendWorktreeLog("已在 \(config.ideLabel) 中打开: \(path)")
            } else {
                _ = try ProcessRunner.runCommand("open", arguments: [ProcessRunner.expandPath(fullPath)])
                appendWorktreeLog("已打开文件: \(path)")
            }
        } catch {
            appendWorktreeLog("打开文件失败: \(error.localizedDescription)")
        }
    }

    func copyFilePath(_ path: String, relative: Bool = true) {
        guard let item = selectedWorktree else { return }
        let textToCopy = relative ? path : URL(fileURLWithPath: item.path).appendingPathComponent(path).path
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textToCopy, forType: .string)
        appendWorktreeLog("已复制文件路径: \(textToCopy)")
    }

    func runScriptInTerminal(command: String) {
        guard let item = selectedWorktree else { return }
        let termName = appConfig?.terminalApp ?? settingsDraft.terminalApp
        do {
            try TerminalService.shared.runScriptInTerminal(command: command, path: item.path, terminalName: termName)
            appendWorktreeLog("已在 \(termName) 执行: \(command)")
        } catch {
            appendWorktreeLog("终端执行失败: \(error.localizedDescription)")
        }
    }

    func fetchSelectedWorktree() async {
        guard let item = selectedWorktree else { return }
        let path = item.path
        let branch = item.branch
        appendWorktreeLog("开始 Git Fetch: \(branch)...")
        worktreeOperation = OperationState(
            isRunning: true,
            title: "Git Fetch",
            detail: branch,
            logs: worktreeOperation.logs
        )
        let gitCli = service.gitCliService
        do {
            try await Task.detached(priority: .userInitiated) {
                try gitCli.fetchWorktree(worktreePath: path)
            }.value
            appendWorktreeLog("Git Fetch 成功: \(branch)")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "Git Fetch 成功",
                detail: branch,
                logs: worktreeOperation.logs,
                successMessage: "Fetch 成功"
            )
            syncSelectedWorktreeDetails()
        } catch {
            appendWorktreeLog("Git Fetch 失败: \(error.localizedDescription)")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "Git Fetch 失败",
                detail: error.localizedDescription,
                logs: worktreeOperation.logs,
                errorMessage: error.localizedDescription
            )
        }
    }

    func pullSelectedWorktree() async {
        guard let item = selectedWorktree else { return }
        let path = item.path
        let branch = item.branch
        appendWorktreeLog("开始 Git Pull: \(branch)...")
        worktreeOperation = OperationState(
            isRunning: true,
            title: "Git Pull",
            detail: branch,
            logs: worktreeOperation.logs
        )
        let gitCli = service.gitCliService
        do {
            try await Task.detached(priority: .userInitiated) {
                try gitCli.pullWorktree(worktreePath: path)
            }.value
            appendWorktreeLog("Git Pull 成功: \(branch)")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "Git Pull 成功",
                detail: branch,
                logs: worktreeOperation.logs,
                successMessage: "Pull 成功"
            )
            syncSelectedWorktreeDetails()
        } catch {
            appendWorktreeLog("Git Pull 失败: \(error.localizedDescription)")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "Git Pull 失败",
                detail: error.localizedDescription,
                logs: worktreeOperation.logs,
                errorMessage: error.localizedDescription
            )
        }
    }

    func pushSelectedWorktree() async {
        guard let item = selectedWorktree else { return }
        let path = item.path
        let branch = item.branch
        appendWorktreeLog("开始 Git Push: \(branch)...")
        worktreeOperation = OperationState(
            isRunning: true,
            title: "Git Push",
            detail: branch,
            logs: worktreeOperation.logs
        )
        let gitCli = service.gitCliService
        do {
            try await Task.detached(priority: .userInitiated) {
                try gitCli.pushWorktree(worktreePath: path)
            }.value
            appendWorktreeLog("Git Push 成功: \(branch)")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "Git Push 成功",
                detail: branch,
                logs: worktreeOperation.logs,
                successMessage: "Push 成功"
            )
            syncSelectedWorktreeDetails()
        } catch {
            appendWorktreeLog("Git Push 失败: \(error.localizedDescription)")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "Git Push 失败",
                detail: error.localizedDescription,
                logs: worktreeOperation.logs,
                errorMessage: error.localizedDescription
            )
        }
    }

    func syncSelectedWorktreeDetails() {
        consoleDetailsTask?.cancel()
        consoleDetailsGeneration &+= 1
        let generation = consoleDetailsGeneration

        guard let item = selectedWorktree else {
            selectedWorktreeFileChanges = []
            selectedWorktreeAheadBehind = nil
            isLoadingConsoleDetails = false
            return
        }

        let worktreePath = item.path
        let gitCli = service.gitCliService
        isLoadingConsoleDetails = true

        consoleDetailsTask = Task { [weak self] in
            defer {
                self?.isLoadingConsoleDetails = false
            }

            let (changes, aheadBehind) = await Task.detached(priority: .userInitiated) { () -> ([WorktreeFileChange], AheadBehindCount?) in
                guard !Task.isCancelled else { return ([], nil) }
                let c = (try? gitCli.worktreeDetailedChanges(worktreePath: worktreePath)) ?? []
                guard !Task.isCancelled else { return (c, nil) }
                let ab = try? gitCli.aheadBehindCount(worktreePath: worktreePath)
                return (c, ab)
            }.value

            guard !Task.isCancelled else { return }
            guard let self, self.consoleDetailsGeneration == generation else { return }
            self.selectedWorktreeFileChanges = changes
            self.selectedWorktreeAheadBehind = aheadBehind
        }
    }

    func removeWorktree(_ item: WorktreeItem, deleteLocalBranch: Bool = false, deleteRemoteBranch: Bool = false) async {
        guard let config = effectiveWorktreeConfig else { return }
        let branch = item.branch
        appendWorktreeLog("开始删除工作树: \(branch) [\(item.path)]")
        worktreeOperation = OperationState(
            isRunning: true,
            title: "删除工作树",
            detail: branch,
            logs: worktreeOperation.logs
        )
        do {
            try await service.removeWorktree(
                config: config,
                item: item,
                deleteLocalBranch: deleteLocalBranch,
                deleteRemoteBranch: deleteRemoteBranch
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.appendWorktreeLog("[\(progress.title)] \(progress.detail)")
                    self?.worktreeOperation = OperationState(
                        isRunning: true,
                        title: progress.title,
                        detail: progress.detail,
                        fractionCompleted: progress.fractionCompleted,
                        logs: self?.worktreeOperation.logs ?? []
                    )
                }
            }
            appendWorktreeLog("工作树已删除: \(branch)")
            await refreshWorktrees()
            worktreeOperation.successMessage = "已删除 \(branch)"
        } catch {
            appendWorktreeLog("删除工作树失败: \(error.localizedDescription)")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "删除工作树失败",
                detail: error.localizedDescription,
                logs: worktreeOperation.logs,
                errorMessage: error.localizedDescription
            )
        }
    }

    func createWorktree() async {
        guard let config = effectiveWorktreeConfig, let project = currentWorktreeProject else {
            worktreeOperation = OperationState(
                isRunning: false,
                title: "无法创建工作树",
                detail: "尚未读取到工作树项目配置",
                errorMessage: "尚未读取到工作树项目配置"
            )
            return
        }

        appendWorktreeLog("开始创建工作树: \(createWorktreeDraft.branchName)")
        worktreeOperation = OperationState(isRunning: true, title: "创建工作树", detail: "准备执行", logs: worktreeOperation.logs)

        do {
            let result = try await service.createWorktree(config: config, project: project, draft: createWorktreeDraft) { [weak self] progress in
                Task { @MainActor in
                    self?.appendWorktreeLog("[\(progress.title)] \(progress.detail)")
                    self?.worktreeOperation = OperationState(
                        isRunning: true,
                        title: progress.title,
                        detail: progress.detail,
                        fractionCompleted: progress.fractionCompleted,
                        logs: self?.worktreeOperation.logs ?? []
                    )
                }
            }

            for line in result.logs {
                appendWorktreeLog(line)
            }

            if createWorktreeDraft.openInIDE {
                try service.openInIDE(config: config, path: result.path)
                appendWorktreeLog("已在 \(config.ideLabel) 中打开: \(result.path)")
            }

            showingCreateWorktreeSheet = false
            await refreshWorktrees()
            selectedWorktreeID = worktrees.first(where: { $0.path == result.path })?.id
            worktreeOperation.successMessage = result.successMessage
        } catch {
            appendWorktreeLog("创建工作树失败: \(error.localizedDescription)")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "创建工作树失败",
                detail: error.localizedDescription,
                logs: worktreeOperation.logs,
                errorMessage: error.localizedDescription
            )
        }
    }

    func openSelectedWorktreeInIDE() {
        if let item = selectedWorktree {
            openWorktreeInIDE(item)
        }
    }

    func openSelectedWorktreeInTerminal() {
        if let item = selectedWorktree {
            openWorktreeInTerminal(item)
        }
    }

    func refreshScannedTerminals() {
        scannedTerminals = TerminalService.shared.scanInstalledTerminals()
    }

    func selectTerminal(_ terminal: InstalledTerminalApp) {
        settingsDraft.terminalApp = terminal.name
        settingsDraft.terminalBundleID = terminal.bundleID
    }

    func refreshScannedIDEs() {
        scannedIDEs = IDEService.shared.scanInstalledIDEs()
    }

    func selectIDE(_ ide: InstalledIDEApp) {
        settingsDraft.ideMode = "app"
        settingsDraft.ideCommand = ide.name
        settingsDraft.ideLabel = ide.displayName
        Task {
            await saveSettings()
        }
    }

    func testOpenIDE() {
        let mode = settingsDraft.ideMode.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = settingsDraft.ideCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let testPath = currentWorktreeProject?.path ?? FileManager.default.homeDirectoryForCurrentUser.path
        do {
            try IDEService.shared.openDirectory(path: testPath, ideMode: mode, ideCommand: command)
            let label = settingsDraft.ideLabel.isEmpty ? command : settingsDraft.ideLabel
            settingsOperation = OperationState(
                isRunning: false,
                title: "已打开 IDE",
                detail: "已使用 \(label) 打开目录 \(testPath)",
                successMessage: "测试成功：已调起 \(label)"
            )
        } catch {
            settingsOperation = OperationState(
                isRunning: false,
                title: "调起 IDE 失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func selectAIProviderPreset(_ preset: AIProviderPreset) {
        settingsDraft.aiProvider = preset.id
        if preset.id != "custom" {
            settingsDraft.aiBaseURL = preset.defaultBaseURL
            settingsDraft.aiModel = preset.defaultModel
        }
    }

    func testAIConnection() async {
        let baseURL = settingsDraft.aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = settingsDraft.aiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = settingsDraft.aiModel.trimmingCharacters(in: .whitespacesAndNewlines)

        settingsOperation = OperationState(isRunning: true, title: "测试 AI 连接", detail: "正在向 \(baseURL) 发起测试握手...")
        do {
            let msg = try await AIService.shared.testConnection(baseURL: baseURL, apiKey: apiKey, model: model)
            settingsOperation = OperationState(
                isRunning: false,
                title: "AI 连接成功",
                detail: "\(model) · \(msg)",
                successMessage: "连接成功：\(msg)"
            )
        } catch {
            settingsOperation = OperationState(
                isRunning: false,
                title: "AI 连接失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func generateBranchNameWithAI() async {
        let desc = createWorktreeDraft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty else {
            aiGenerationError = "请先填写功能描述"
            return
        }

        let baseURL = appConfig?.aiBaseURL ?? settingsDraft.aiBaseURL
        let apiKey = appConfig?.aiAPIKey ?? settingsDraft.aiAPIKey
        let model = appConfig?.aiModel ?? settingsDraft.aiModel

        let projectName = currentWorktreeProject?.name ?? "project"
        let isEnterprise = currentWorktreeProject?.platform == .gitlab
        let middle = appConfig?.mergeBranchMiddle ?? settingsDraft.mergeBranchMiddle

        isAIGeneratingBranch = true
        aiGenerationError = nil

        do {
            let result = try await AIService.shared.generateBranchName(
                description: desc,
                projectName: projectName,
                isEnterprise: isEnterprise,
                middle: middle,
                baseURL: baseURL,
                apiKey: apiKey,
                model: model
            )

            createWorktreeDraft.branchName = result.recommended
            updateCreateWorktreePathFromBranch()
            aiSuggestedAlternatives = result.alternatives
            isAIGeneratingBranch = false
        } catch {
            isAIGeneratingBranch = false
            aiGenerationError = error.localizedDescription
        }
    }

    func applyAISuggestedBranch(_ branch: String) {
        createWorktreeDraft.branchName = branch
        updateCreateWorktreePathFromBranch()
    }

    func testOpenTerminal() {
        let termName = settingsDraft.terminalApp.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleID = settingsDraft.terminalBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let testPath = currentWorktreeProject?.path ?? FileManager.default.homeDirectoryForCurrentUser.path
        do {
            try TerminalService.shared.openDirectory(path: testPath, terminalName: termName, bundleID: bundleID)
            settingsOperation = OperationState(
                isRunning: false,
                title: "已打开终端",
                detail: "已使用 \(termName) 打开目录 \(testPath)",
                successMessage: "测试成功：已调起 \(termName)"
            )
        } catch {
            settingsOperation = OperationState(
                isRunning: false,
                title: "调起终端失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func removeSelectedWorktree() async {
        if let item = selectedWorktree {
            await removeWorktree(
                item,
                deleteLocalBranch: deleteLocalBranchOnRemove,
                deleteRemoteBranch: deleteRemoteBranchOnRemove
            )
            deleteLocalBranchOnRemove = false
            deleteRemoteBranchOnRemove = false
        }
    }

    func saveSelectedWorktreeDescription() async {
        guard let config = effectiveWorktreeConfig, let item = selectedWorktree else { return }
        guard item.kind == .worktree else {
            worktreeOperation = OperationState(
                isRunning: false,
                title: "主仓库无需补充描述",
                detail: "主仓库默认不写功能描述",
                successMessage: "已忽略主仓库"
            )
            return
        }

        worktreeOperation = OperationState(isRunning: true, title: "保存功能描述", detail: item.branch)
        do {
            try await service.updateWorktreeDescription(
                config: config,
                item: item,
                description: worktreeDescriptionDraft
            )
            let selectedID = item.id
            await refreshWorktrees()
            selectedWorktreeID = worktrees.first(where: { $0.id == selectedID })?.id
            syncSelectedWorktreeDescriptionDraft()
            worktreeOperation = OperationState(
                isRunning: false,
                title: "功能描述已保存",
                detail: item.branch,
                fractionCompleted: 1,
                successMessage: worktreeDescriptionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "已清空描述"
                    : "描述更新成功"
            )
        } catch {
            worktreeOperation = OperationState(
                isRunning: false,
                title: "保存功能描述失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func executeLocalOperation() async {
        guard let context = localMergeContext, let project = currentLocalMergeProject else {
            localOperation = OperationState(
                isRunning: false,
                title: "无法执行分支同步",
                detail: "尚未读取到本地项目配置",
                errorMessage: "尚未读取到本地项目配置"
            )
            return
        }

        let sourceBranch = localOperationSourceBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        let targets = resolvedLocalOperationTargets
        appendLocalOperationLog("开始执行: \(localOperationMode.rawValue) [\(project.displayName)]")
        localOperation = OperationState(
            isRunning: true,
            title: localOperationMode.rawValue,
            detail: project.displayName,
            logs: localOperation.logs
        )

        do {
            let logs: [String]
            switch localOperationMode {
            case .syncEnvironments:
                logs = try await service.executeLocalSync(context: context, project: project) { [weak self] progress in
                    Task { @MainActor in
                        self?.appendLocalOperationLog("[\(progress.title)] \(progress.detail)")
                        self?.localOperation = OperationState(
                            isRunning: true,
                            title: progress.title,
                            detail: progress.detail,
                            fractionCompleted: progress.fractionCompleted,
                            logs: self?.localOperation.logs ?? []
                        )
                    }
                }
            case .mergeAll, .mergeCustom:
                guard !sourceBranch.isEmpty else {
                    throw WorkbenchError.message("请先选择一个源分支")
                }
                guard !targets.isEmpty else {
                    throw WorkbenchError.message("请先选择至少一个目标分支")
                }
                logs = try await service.executeLocalMerge(
                    context: context,
                    project: project,
                    sourceBranch: sourceBranch,
                    targets: targets
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.appendLocalOperationLog("[\(progress.title)] \(progress.detail)")
                        self?.localOperation = OperationState(
                            isRunning: true,
                            title: progress.title,
                            detail: progress.detail,
                            fractionCompleted: progress.fractionCompleted,
                            logs: self?.localOperation.logs ?? []
                        )
                    }
                }
            }

            for line in logs {
                appendLocalOperationLog(line)
            }

            let successCount = logs.filter { !$0.hasPrefix("失败:") && !$0.hasPrefix("错误:") }.count
            localOperation = OperationState(
                isRunning: false,
                title: "\(localOperationMode.rawValue)完成",
                detail: "共返回 \(logs.count) 条执行结果",
                fractionCompleted: 1,
                logs: localOperation.logs,
                successMessage: "已完成 \(successCount) 项处理"
            )
        } catch {
            appendLocalOperationLog("执行失败: \(error.localizedDescription)")
            localOperation = OperationState(
                isRunning: false,
                title: "\(localOperationMode.rawValue)失败",
                detail: error.localizedDescription,
                logs: localOperation.logs,
                errorMessage: error.localizedDescription
            )
        }
    }

    func prepareCreateMergeRequest() {
        let defaultSourceBranch = availableMRMappings
            .map(\.source)
            .first { availableMRSourceBranches.contains($0) }
            ?? availableMRSourceBranches.first
            ?? ""
        let defaultTargetBranch = availableMRTargetBranches.first ?? ""

        createMRDraft.sourceBranch = defaultSourceBranch
        createMRDraft.targetBranch = defaultTargetBranch
        showingCreateMRSheet = true
    }

    func prepareBatchMergeRequests() {
        selectedBatchMRMappingIDs = Set(availableBatchMRMappings.map(\.id))
        showingBatchCreateMRSheet = true
    }

    func toggleBatchApproveMR(_ mrID: String) {
        if selectedBatchApproveMRIDs.contains(mrID) {
            selectedBatchApproveMRIDs.remove(mrID)
        } else {
            selectedBatchApproveMRIDs.insert(mrID)
        }
    }

    func selectAllVisibleOpenMergeRequests() {
        selectedBatchApproveMRIDs.formUnion(visibleOpenMergeRequests.map(\.id))
    }

    func clearBatchApproveSelection() {
        selectedBatchApproveMRIDs.removeAll()
    }

    func createMergeRequest() async {
        guard let context = mergeRequestContext, let project = currentMergeProject else { return }
        mrOperation = OperationState(isRunning: true, title: "创建 MR", detail: "\(createMRDraft.sourceBranch) -> \(createMRDraft.targetBranch)")

        do {
            _ = try await service.createMergeRequest(
                context: context,
                project: project,
                sourceBranch: createMRDraft.sourceBranch,
                targetBranch: createMRDraft.targetBranch
            )
            showingCreateMRSheet = false
            await refreshMergeRequests()
            mrOperation.successMessage = "MR 创建成功"
        } catch {
            mrOperation = OperationState(
                isRunning: false,
                title: "创建 MR 失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func createBatchMergeRequests() async {
        guard let context = mergeRequestContext, let project = currentMergeProject else { return }
        let mappings = selectedBatchMRMappings
        guard !mappings.isEmpty else {
            mrOperation = OperationState(
                isRunning: false,
                title: "批量创建 MR",
                detail: "请至少选择一组分支映射",
                errorMessage: "请至少选择一组分支映射"
            )
            return
        }
        mrOperation = OperationState(isRunning: true, title: "批量创建 MR", detail: "准备执行")

        do {
            let messages = try await service.createBatchMergeRequests(context: context, project: project, mappings: mappings) { [weak self] progress in
                Task { @MainActor in
                    self?.mrOperation = OperationState(
                        isRunning: true,
                        title: progress.title,
                        detail: progress.detail,
                        fractionCompleted: progress.fractionCompleted
                    )
                }
            }
            showingBatchCreateMRSheet = false
            await refreshMergeRequests()
            mrOperation.logs = messages
            mrOperation.successMessage = "已创建 \(mappings.count) 组映射对应的 MR"
        } catch {
            mrOperation = OperationState(
                isRunning: false,
                title: "批量创建 MR 失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func approveAndMergeSelectedBatchMRs() async {
        guard let context = mergeRequestContext else { return }
        let items = selectedBatchApproveMRs
        guard !items.isEmpty else {
            mrOperation = OperationState(
                isRunning: false,
                title: "没有可处理的 MR",
                detail: "请先勾选要审批并合并的 MR",
                successMessage: "无需处理"
            )
            return
        }

        mrOperation = OperationState(
            isRunning: true,
            title: "批量审批并合并",
            detail: "准备处理 \(items.count) 条 MR"
        )

        do {
            let logs = try await service.approveAndMergeBatch(context: context, items: items) { [weak self] progress in
                Task { @MainActor in
                    self?.mrOperation = OperationState(
                        isRunning: true,
                        title: progress.title,
                        detail: progress.detail,
                        fractionCompleted: progress.fractionCompleted
                    )
                }
            }
            await refreshMergeRequests()
            mrOperation = OperationState(
                isRunning: false,
                title: "批量审批并合并完成",
                detail: "共处理 \(items.count) 条 MR",
                fractionCompleted: 1,
                logs: logs,
                successMessage: "批量处理完成"
            )
        } catch {
            mrOperation = OperationState(
                isRunning: false,
                title: "一键审批并合并失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func approveAndMergeSelectedMR() async {
        guard let context = mergeRequestContext, let item = selectedMergeRequest else { return }
        mrOperation = OperationState(isRunning: true, title: "审批并合并", detail: "\(item.iidLabel) \(item.sourceBranch) -> \(item.targetBranch)")

        do {
            let logs = try await service.approveAndMerge(context: context, item: item) { [weak self] progress in
                Task { @MainActor in
                    self?.mrOperation = OperationState(
                        isRunning: true,
                        title: progress.title,
                        detail: progress.detail,
                        fractionCompleted: progress.fractionCompleted
                    )
                }
            }
            await refreshMergeRequests()
            mrOperation.logs = logs
            mrOperation.successMessage = logs.last ?? "审批并合并完成"
        } catch {
            mrOperation = OperationState(
                isRunning: false,
                title: "审批并合并失败",
                detail: error.localizedDescription,
                logs: mrOperation.logs,
                errorMessage: error.localizedDescription
            )
        }
    }

    func closeSelectedMR() async {
        guard let context = mergeRequestContext, let item = selectedMergeRequest else { return }
        mrOperation = OperationState(isRunning: true, title: "关闭 MR", detail: item.iidLabel)

        do {
            try await service.closeMergeRequest(context: context, item: item)
            await refreshMergeRequests()
            mrOperation.successMessage = "已关闭 \(item.iidLabel)"
        } catch {
            mrOperation = OperationState(
                isRunning: false,
                title: "关闭 MR 失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func saveSettings() async {
        settingsOperation = OperationState(isRunning: true, title: "保存设置", detail: "正在校验并写入配置文件")
        do {
            let config = try makeConfigFromDraft()
            let saved = try await service.saveWorkbenchConfig(config)
            appConfig = saved
            worktreeConfig = saved.asWorktreeConfig()
            settingsDraft = SettingsDraft(config: saved)
            settingsTokenVisible = false
            settingsOperation = OperationState(
                isRunning: false,
                title: "设置已保存",
                detail: "已更新 GWorkbench 配置并刷新数据",
                fractionCompleted: 1,
                successMessage: "保存成功"
            )
            await refreshWorktrees()
            await refreshLocalMergeProjects()
            await refreshMergeProjects()
        } catch {
            settingsOperation = OperationState(
                isRunning: false,
                title: "保存失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func reloadSettingsOnly() async {
        settingsOperation = OperationState(isRunning: true, title: "重新加载设置", detail: "正在从 GWorkbench 配置文件读取")
        do {
            let config = try await service.reloadWorkbenchConfig()
            appConfig = config
            worktreeConfig = config.asWorktreeConfig()
            settingsDraft = SettingsDraft(config: config)
            settingsTokenVisible = false
            settingsOperation = OperationState(
                isRunning: false,
                title: "设置已重新加载",
                detail: "已从配置文件读取最新内容",
                fractionCompleted: 1,
                successMessage: "重新加载完成"
            )
            await refreshWorktrees()
            await refreshLocalMergeProjects()
            await refreshMergeProjects()
        } catch {
            settingsOperation = OperationState(
                isRunning: false,
                title: "重新加载失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func suggestedWorktreePath(projectName: String, branchName: String) -> String {
        let basePath: String
        if let wtPath = worktreeConfig?.worktreesRootDir, !wtPath.isEmpty {
            basePath = wtPath
        } else if let appPath = appConfig?.worktreesRootDir, !appPath.isEmpty {
            basePath = appPath
        } else if !settingsDraft.worktreesRootDir.isEmpty {
            basePath = settingsDraft.worktreesRootDir
        } else {
            basePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("worktrees").path
        }
        let template = appConfig?.worktreePathTemplate
            ?? settingsDraft.worktreePathTemplate
        let safeBranch = branchName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        let branchValue = safeBranch.isEmpty ? "new-worktree" : safeBranch

        return resolveWorktreePathTemplate(
            template: template.isEmpty ? "${rootDir}/${project}/${branch}" : template,
            rootDir: basePath,
            projectName: projectName,
            branchName: branchValue
        )
    }

    func resolveWorktreePathTemplate(template: String, rootDir: String, projectName: String, branchName: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateValue = dateFormatter.string(from: Date())

        let safeBranch = branchName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")

        var result = template
            .replacingOccurrences(of: "${rootDir}", with: rootDir)
            .replacingOccurrences(of: "${project}", with: projectName)
            .replacingOccurrences(of: "${branch}", with: safeBranch.isEmpty ? "feat-demo" : safeBranch)
            .replacingOccurrences(of: "${date}", with: dateValue)

        if !result.hasPrefix("/") {
            result = URL(fileURLWithPath: rootDir).appendingPathComponent(result).path
        }
        return (result as NSString).standardizingPath
    }

    private func mergeRequests(for filter: MergeRequestFilter) -> [MergeRequestItem] {
        switch filter {
        case .open:
            return mergeRequests.filter { [.open, .ready, .blocked, .draft].contains($0.status) }
        case .mine:
            guard let currentUsername = mergeRequestContext?.currentUsername else { return [] }
            return mergeRequests.filter { $0.authorUsername == currentUsername }
        case .awaitingMine:
            return mergeRequests.filter { !$0.approvedByMe && [.open, .ready].contains($0.status) }
        case .merged:
            return mergeRequests.filter { $0.status == .merged }
        case .closed:
            return mergeRequests.filter { $0.status == .closed }
        }
    }

    private func summaryAsEditableDescription(_ item: WorktreeItem) -> String {
        switch item.summary {
        case "主仓库", "未填写功能描述":
            return ""
        default:
            return item.summary
        }
    }

    private func mergeBranchName(envBranch: String, projectName: String, middle: String) -> String {
        BranchSyncService.mergeBranchName(envBranch: envBranch, middle: middle, projectName: projectName)
    }

    private func makeConfigFromDraft() throws -> GWorkbenchConfig {
        let delay = Int(settingsDraft.autoMergeDelaySecondsText.trimmingCharacters(in: .whitespacesAndNewlines))
        let retry = Int(settingsDraft.autoMergeRetryCountText.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let delay, delay >= 0 else {
            throw WorkbenchError.message("自动合并等待秒数必须是非负整数")
        }
        guard let retry, retry >= 0 else {
            throw WorkbenchError.message("自动合并重试次数必须是非负整数")
        }

        let worktreeRoots = settingsDraft.worktreeProjectsRootDirs
            .map(\.path)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let mergeRoots = settingsDraft.mergeRootDirs
            .map(\.path)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let envBranches = parseList(settingsDraft.envBranchesText)
        let protectedTargets = parseList(settingsDraft.protectedTargetsText)
        let branchMap = try parseBranchMappings(settingsDraft.branchMappings)

        guard !worktreeRoots.isEmpty else {
            throw WorkbenchError.message("至少需要一个工作树项目根目录")
        }
        guard !mergeRoots.isEmpty else {
            throw WorkbenchError.message("至少需要一个 MR 项目根目录")
        }
        guard !envBranches.isEmpty else {
            throw WorkbenchError.message("环境分支不能为空")
        }

        return GWorkbenchConfig(
            configPath: settingsDraft.configPath,
            metadataPath: settingsDraft.metadataPath,
            worktreeProjectsRootDirs: worktreeRoots,
            worktreesRootDir: settingsDraft.worktreesRootDir.trimmingCharacters(in: .whitespacesAndNewlines),
            worktreePathTemplate: settingsDraft.worktreePathTemplate.trimmingCharacters(in: .whitespacesAndNewlines),
            ideMode: settingsDraft.ideMode.trimmingCharacters(in: .whitespacesAndNewlines),
            ideCommand: settingsDraft.ideCommand.trimmingCharacters(in: .whitespacesAndNewlines),
            ideLabel: settingsDraft.ideLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            terminalApp: settingsDraft.terminalApp.trimmingCharacters(in: .whitespacesAndNewlines),
            terminalBundleID: settingsDraft.terminalBundleID.trimmingCharacters(in: .whitespacesAndNewlines),
            terminalLaunchHookMode: settingsDraft.terminalLaunchHookMode.trimmingCharacters(in: .whitespacesAndNewlines),
            terminalLaunchCommand: settingsDraft.terminalLaunchCommand.trimmingCharacters(in: .whitespacesAndNewlines),
            gitlabHost: settingsDraft.gitlabHost.trimmingCharacters(in: .whitespacesAndNewlines),
            gitlabToken: settingsDraft.gitlabToken.trimmingCharacters(in: .whitespacesAndNewlines),
            githubToken: settingsDraft.githubToken.trimmingCharacters(in: .whitespacesAndNewlines),
            aiProvider: settingsDraft.aiProvider.trimmingCharacters(in: .whitespacesAndNewlines),
            aiBaseURL: settingsDraft.aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            aiAPIKey: settingsDraft.aiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
            aiModel: settingsDraft.aiModel.trimmingCharacters(in: .whitespacesAndNewlines),
            activeWorkflowPreset: settingsDraft.activeWorkflowPreset.trimmingCharacters(in: .whitespacesAndNewlines),
            githubDefaultTargetBranch: settingsDraft.githubDefaultTargetBranch.trimmingCharacters(in: .whitespacesAndNewlines),
            mergeRootDirs: mergeRoots,
            mergeBranchMiddle: settingsDraft.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines),
            envBranches: envBranches,
            branchMap: branchMap,
            protectedTargets: protectedTargets,
            autoMergeDelaySeconds: delay,
            autoMergeRetryCount: retry
        )
    }

    private func parseList(_ text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .flatMap { line in
                line.split(separator: ",").map(String.init)
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func parseBranchMappings(_ mappings: [BranchMappingDraft]) throws -> [String: String] {
        var result: [String: String] = [:]
        for mapping in mappings {
            let source = mapping.source.trimmingCharacters(in: .whitespacesAndNewlines)
            let target = mapping.target.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty || !target.isEmpty else { continue }
            guard !source.isEmpty, !target.isEmpty else {
                throw WorkbenchError.message("分支映射不能有空值：\(mapping.source) = \(mapping.target)")
            }
            result[source] = target
        }
        return result
    }

    func addWorktreeProjectsRoot(_ path: String) {
        let normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        if !settingsDraft.worktreeProjectsRootDirs.contains(where: { $0.path == normalized }) {
            settingsDraft.worktreeProjectsRootDirs.append(PathEntryDraft(path: normalized))
        }
    }

    func removeWorktreeProjectsRoot(id: UUID) {
        settingsDraft.worktreeProjectsRootDirs.removeAll { $0.id == id }
    }

    func addMergeRoot(_ path: String) {
        let normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        if !settingsDraft.mergeRootDirs.contains(where: { $0.path == normalized }) {
            settingsDraft.mergeRootDirs.append(PathEntryDraft(path: normalized))
        }
    }

    func removeMergeRoot(id: UUID) {
        settingsDraft.mergeRootDirs.removeAll { $0.id == id }
    }

    var currentDraftTargetBranchOptions: [String] {
        let envs = parseList(settingsDraft.envBranchesText)
        let protectedTargets = parseList(settingsDraft.protectedTargetsText)
        var list: [String] = []
        for e in envs where !list.contains(e) {
            list.append(e)
        }
        for p in protectedTargets where !list.contains(p) {
            list.append(p)
        }
        return list.isEmpty ? ["uat", "test", "stage", "pre_prod", "master"] : list
    }

    func regenerateBranchMappingsFromEnvironment() {
        let middle = settingsDraft.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "henry"
            : settingsDraft.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines)
        let envs = parseList(settingsDraft.envBranchesText)
        let protectedTargets = parseList(settingsDraft.protectedTargetsText)

        guard !envs.isEmpty else { return }

        var newMappings: [BranchMappingDraft] = []

        // 如果配置了保护目标(如 master)，且最后一个高阶环境(如 pre_prod)存在，生成 pre_prod -> master
        if let lastEnv = envs.last, let target = protectedTargets.first, lastEnv != target {
            newMappings.append(BranchMappingDraft(source: lastEnv, target: target))
        }

        // 各环境分支的标准合并分支: ${env}_${middle}_meger -> ${env}
        for env in envs.reversed() {
            newMappings.append(BranchMappingDraft(
                source: "\(env)_\(middle)_meger",
                target: env
            ))
        }

        settingsDraft.branchMappings = newMappings
        settingsOperation = OperationState(
            isRunning: false,
            title: "映射已同步",
            detail: "已根据环境分支列表生成 \(newMappings.count) 条映射",
            successMessage: "已同步 \(newMappings.count) 条映射"
        )
    }

    func addBranchMapping(target: String? = nil) {
        let defaultTarget = target ?? currentDraftTargetBranchOptions.first ?? "uat"
        let middle = settingsDraft.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "henry"
            : settingsDraft.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultSource = "\(defaultTarget)_\(middle)_meger"
        settingsDraft.branchMappings.append(BranchMappingDraft(source: defaultSource, target: defaultTarget))
    }

    func removeBranchMapping(id: UUID) {
        settingsDraft.branchMappings.removeAll { $0.id == id }
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        self?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? self : nil
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var nonEmptyArray: [String] {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? [] : [trimmed]
    }
}

private extension Array {
    var nonEmptyArray: [Element]? {
        isEmpty ? nil : self
    }
}
