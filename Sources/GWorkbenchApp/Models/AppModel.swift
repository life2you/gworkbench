import Foundation
import AppKit

enum AppSection: String, CaseIterable, Identifiable {
    case mergeDashboard
    case worktrees
    case branchSync
    case mergeRequests

    var id: String { rawValue }

    var title: String {
        switch self {
        case .worktrees:
            "工作树"
        case .mergeDashboard:
            "看板"
        case .branchSync:
            "分支同步"
        case .mergeRequests:
            "合并请求"
        }
    }

    var icon: String {
        switch self {
        case .worktrees:
            "point.3.connected.trianglepath.dotted"
        case .mergeDashboard:
            "chart.bar.xaxis"
        case .branchSync:
            "arrow.triangle.branch"
        case .mergeRequests:
            "arrow.triangle.merge"
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
    var diskUsage: String
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
    var platform: RepositoryPlatform = .gitlab
    var repoSlug: String? = nil

    var iidLabel: String {
        platform == .github ? "#\(iid)" : "!\(iid)"
    }
}

struct CreateWorktreeDraft: Sendable {
    var mode: CreateWorktreeMode = .newBranch
    var baseBranch: String = ""
    var branchName: String = ""
    var description: String = ""
    var path: String = ""
    var openInIDE: Bool = true
    var installDependencies: Bool = false
    var syncIDEConfigs: Bool = false
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

    var selectedSection: AppSection? = .worktrees {
        didSet {
            if selectedSection == .mergeRequests && (mergeRequestContext == nil || mergeProjects.isEmpty) && !mrOperation.isRunning {
                Task {
                    await refreshMergeProjects()
                }
            } else if selectedSection == .branchSync && (localMergeContext == nil || localMergeProjects.isEmpty) && !localOperation.isRunning {
                Task {
                    await refreshLocalMergeProjects()
                }
            } else if selectedSection == .mergeDashboard {
                Task {
                    if worktreeProjects.isEmpty {
                        await refreshWorktrees()
                    }
                    await refreshMergeDashboard()
                }
            }
        }
    }

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
    private var isSwitchingWorkspace: Bool = false
    private var workspaceSwitchGeneration: Int = 0
    private var workspaceCaches: [String: WorkspaceViewSnapshotCache] = [:]

    private struct WorkspaceViewSnapshotCache {
        var worktreeProjects: [LocalProject]
        var worktrees: [WorktreeItem]
        var localMergeProjects: [MergeProject]
        var mergeProjects: [MergeProject]
        var selectedProjectID: String?
        var selectedWorktreeID: String?
        var selectedLocalProjectID: String?
        var selectedMergeProjectID: String?
        var mergeDashboardProjectID: String?
        var mergeDashboardItems: [MergeDashboardItem]
        var selectedDashboardItemID: String?
    }
    var selectedMergeRequestID: String?
    var selectedDashboardItemID: String?
    var selectedMergeFilter: MergeRequestFilter = .open
    var selectedWorktreeCategory: WorktreeCategoryFilter = .all
    var selectedPlatformFilter: RepositoryPlatform = .github {
        didSet {
            if selectedPlatformFilter != oldValue {
                handleActivePlatformChanged()
            }
        }
    }

    var activeWorkspaceID: String = ""
    var showingSettingsSheet: Bool = false
    var sidebarRepoSearchText: String = ""
    var showingWorkspaceEditorSheet: Bool = false
    var workspaceEditorDraft: WorkspaceProfileDraft? = nil

    var workspaces: [WorkspaceProfile] {
        let saved = appConfig?.workspaces ?? []
        if !saved.isEmpty {
            return saved
        }
        return settingsDraft.workspaces.map { $0.toWorkspaceProfile() }
    }

    var activeWorkspace: WorkspaceProfile? {
        let list = workspaces
        if let matched = list.first(where: { $0.id == activeWorkspaceID }) {
            return matched
        }
        return list.first
    }

    var activePlatform: RepositoryPlatform {
        get { activeWorkspace?.platform ?? selectedPlatformFilter }
        set { selectedPlatformFilter = newValue }
    }

    var isGitHubActive: Bool {
        activePlatform == .github
    }

    var requestSectionTitle: String {
        isGitHubActive ? "Pull Requests" : "Merge Requests"
    }

    var requestShortLabel: String {
        isGitHubActive ? "PR" : "MR"
    }

    var currentDashboardBaselines: [String] {
        if let ws = activeWorkspace {
            return ws.effectiveDashboardBaselines
        }
        switch activePlatform {
        case .github:
            let configured = appConfig?.githubDashboardBaselines.filterNonEmpty() ?? []
            return configured.isEmpty ? DefaultDashboardBaselines.github : configured
        case .gitlab:
            let configured = appConfig?.gitlabDashboardBaselines.filterNonEmpty() ?? []
            return configured.isEmpty ? DefaultDashboardBaselines.gitlab : configured
        case .local, .all:
            return DefaultDashboardBaselines.local
        }
    }
    var sortOrder: [KeyPathComparator<WorktreeItem>] = [
        KeyPathComparator(\.branch, order: .forward)
    ]
    var gitVersion: String = "Git"

    var worktreeSearchText = ""
    var localBranchSearchText = ""
    var mergeRequestSearchText = ""
    var existingBranchSearchText = ""

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

    // MARK: - Interactive Sync Pipeline State
    var activeSyncSession: ActiveSyncSession? = nil
    var isInspectingConflictFiles: Bool = false
    private var conflictMonitorTask: Task<Void, Never>? = nil
    private var conflictMonitorActivity: NSObjectProtocol? = nil
    var showingRebasedInstallSheet: Bool = false
    var showingOnboardingSheet: Bool = false
    var ghCLITokenAvailable: Bool = false
    var isInstallingRebased: Bool = false
    var rebasedInstallLog: String = ""

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

    // MARK: - Merge Dashboard State
    var mergeDashboardItems: [MergeDashboardItem] = []
    var isMergeDashboardAnalyzing: Bool = false
    var mergeDashboardProjectID: String? = nil

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
            return app.asWorktreeConfig(for: activeWorkspace)
        }
        return worktreeConfig
    }

    var configuredIDEProfiles: [IDEProfile] {
        if let app = appConfig {
            return app.effectiveIDEProfiles
        }
        if let wt = worktreeConfig {
            return wt.effectiveIDEProfiles
        }
        let fromDraft = settingsDraft.ideProfiles.map { $0.toIDEProfile() }
        if !fromDraft.isEmpty {
            return fromDraft
        }
        return [
            IDEProfile(
                id: "default-ide",
                label: settingsDraft.ideLabel.isEmpty ? "默认应用" : settingsDraft.ideLabel,
                mode: settingsDraft.ideMode.isEmpty ? "app" : settingsDraft.ideMode,
                command: settingsDraft.ideCommand.isEmpty ? "open" : settingsDraft.ideCommand
            )
        ]
    }

    var defaultIDEProfile: IDEProfile {
        if let app = appConfig {
            return app.defaultIDEProfile
        }
        let profiles = configuredIDEProfiles
        if !settingsDraft.defaultIDEProfileID.isEmpty,
           let matched = profiles.first(where: { $0.id == settingsDraft.defaultIDEProfileID }) {
            return matched
        }
        return profiles[0]
    }

    var currentIDELabel: String {
        defaultIDEProfile.effectiveLabel
    }

    var selectedWorktree: WorktreeItem? {
        filteredWorktrees.first(where: { $0.id == selectedWorktreeID })
            ?? worktrees.first(where: { $0.id == selectedWorktreeID })
    }

    var selectedMergeRequest: MergeRequestItem? {
        filteredMergeRequests.first(where: { $0.id == selectedMergeRequestID })
            ?? mergeRequests.first(where: { $0.id == selectedMergeRequestID })
    }

    var selectedDashboardItem: MergeDashboardItem? {
        mergeDashboardItems.first(where: { $0.id == selectedDashboardItemID })
    }

    /// 看板中选中项对应的完整 WorktreeItem（用于展示详情）
    var selectedDashboardWorktree: WorktreeItem? {
        guard let dashItem = selectedDashboardItem else { return nil }
        return worktrees.first(where: { $0.id == dashItem.id })
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

    var sidebarFilteredProjects: [LocalProject] {
        let q = sidebarRepoSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return filteredWorktreeProjects }
        return filteredWorktreeProjects.filter {
            $0.displayName.localizedCaseInsensitiveContains(q)
                || $0.name.localizedCaseInsensitiveContains(q)
                || $0.currentBranch.localizedCaseInsensitiveContains(q)
        }
    }

    var dirtyProjectNames: Set<String> {
        Set(worktrees.filter(\.isDirty).map(\.projectName))
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

    var switchablePlatforms: [RepositoryPlatform] {
        let platforms = Set(worktreeProjects.map(\.platform))
        var list: [RepositoryPlatform] = [.github, .gitlab]
        if platforms.contains(.local) {
            list.append(.local)
        }
        return list
    }

    var availablePlatforms: [RepositoryPlatform] {
        switchablePlatforms
    }

    var appVersionString: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.2.9"
    }

    var sidebarPlatformStatusText: String {
        if let ws = activeWorkspace {
            switch ws.platform {
            case .github:
                let cleanHost = ws.host
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://", with: "")
                let hostLabel = cleanHost.isEmpty ? "github.com" : cleanHost
                if !ws.token.isEmpty {
                    return "\(ws.name) · \(hostLabel) (PAT)"
                }
                return ghCLITokenAvailable ? "\(ws.name) · \(hostLabel) (gh CLI)" : "\(ws.name) · \(hostLabel)"
            case .gitlab:
                let cleanHost = ws.host
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://", with: "")
                return cleanHost.isEmpty ? "\(ws.name) · 未配置 Host" : "\(ws.name) · \(cleanHost)"
            case .local, .all:
                return ws.name
            }
        }
        switch activePlatform {
        case .github:
            if !(appConfig?.githubToken ?? "").isEmpty {
                return "GitHub 模式 · PAT 已配置"
            }
            return ghCLITokenAvailable ? "GitHub 模式 · gh 凭据已认证" : "GitHub 模式 · 未配置凭据"
        case .gitlab:
            let host = appConfig?.gitlabHost ?? ""
            if !host.isEmpty {
                let clean = host
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://", with: "")
                return "GitLab 模式 · \(clean)"
            }
            return "GitLab 模式 · 未配置实例"
        case .local, .all:
            return "本地 Git 模式"
        }
    }

    func selectWorkspace(_ id: String) {
        guard let target = workspaces.first(where: { $0.id == id }) else { return }
        let previousID = activeWorkspaceID
        if previousID == target.id { return }

        // 1. 缓存旧工作区快照，避免切回时重复冷扫描
        if !previousID.isEmpty, !worktreeProjects.isEmpty {
            workspaceCaches[previousID] = WorkspaceViewSnapshotCache(
                worktreeProjects: worktreeProjects,
                worktrees: worktrees,
                localMergeProjects: localMergeProjects,
                mergeProjects: mergeProjects,
                selectedProjectID: selectedProjectID,
                selectedWorktreeID: selectedWorktreeID,
                selectedLocalProjectID: selectedLocalProjectID,
                selectedMergeProjectID: selectedMergeProjectID,
                mergeDashboardProjectID: mergeDashboardProjectID,
                mergeDashboardItems: mergeDashboardItems,
                selectedDashboardItemID: selectedDashboardItemID
            )
        }

        workspaceSwitchGeneration += 1
        let expectedGen = workspaceSwitchGeneration
        let expectedWSID = target.id

        isSwitchingWorkspace = true
        activeWorkspaceID = target.id
        settingsDraft.activeWorkspaceID = target.id
        settingsDraft.activePlatform = target.platform.rawValue
        selectedPlatformFilter = target.platform
        isSwitchingWorkspace = false

        GitLabHostStore.shared.update(target.platform == .gitlab ? target.host : appConfig?.gitlabHost)
        GitCredentialStore.shared.update(
            gitlabToken: target.platform == .gitlab ? target.token : (appConfig?.gitlabToken ?? ""),
            githubToken: target.platform == .github ? target.token : (appConfig?.githubToken ?? "")
        )

        if let cached = workspaceCaches[target.id] {
            // 2A. 命中缓存：0ms 立即恢复全部仓库、工作树与上次选中项
            worktreeProjects = cached.worktreeProjects
            worktrees = cached.worktrees
            localMergeProjects = cached.localMergeProjects
            mergeProjects = cached.mergeProjects
            selectedProjectID = cached.selectedProjectID ?? cached.worktreeProjects.first?.id
            selectedWorktreeID = cached.selectedWorktreeID ?? filteredWorktrees.first?.id
            selectedLocalProjectID = cached.selectedLocalProjectID ?? cached.localMergeProjects.first?.id
            selectedMergeProjectID = cached.selectedMergeProjectID ?? cached.mergeProjects.first?.id
            mergeDashboardProjectID = cached.mergeDashboardProjectID
            mergeDashboardItems = cached.mergeDashboardItems
            selectedDashboardItemID = cached.selectedDashboardItemID
            syncSelectedWorktreeDescriptionDraft()
            syncSelectedWorktreeDetails()
            syncCreateWorktreeDefaults(resetBranchName: false)
            syncLocalOperationDefaults(resetSourceBranch: false)
        } else {
            // 2B. 首次切入：零子进程纯文件系统快扫（<3ms），让左侧仓库列表立即出现
            let placeholders = service.gitCliService.scanProjectPlaceholders(
                rootDirs: target.projectsRootDirs,
                forcedPlatform: target.platform
            )
            worktreeProjects = placeholders
            worktrees = []
            localMergeProjects = []
            mergeProjects = []
            mergeRequests = []
            selectedProjectID = placeholders.first?.id
            selectedWorktreeID = nil
            selectedLocalProjectID = nil
            selectedMergeProjectID = nil
            selectedMergeRequestID = nil
            mergeDashboardProjectID = nil
            mergeDashboardItems = []
            selectedDashboardItemID = nil
        }

        if let current = appConfig {
            let updatedConfig = GWorkbenchConfig(
                configPath: current.configPath,
                metadataPath: current.metadataPath,
                worktreeProjectsRootDirs: current.worktreeProjectsRootDirs,
                worktreesRootDir: current.worktreesRootDir,
                worktreePathTemplate: current.worktreePathTemplate,
                ideMode: current.ideMode,
                ideCommand: current.ideCommand,
                ideLabel: current.ideLabel,
                ideProfiles: current.ideProfiles,
                defaultIDEProfileID: current.defaultIDEProfileID,
                terminalApp: current.terminalApp,
                terminalBundleID: current.terminalBundleID,
                terminalLaunchHookMode: current.terminalLaunchHookMode,
                terminalLaunchCommand: current.terminalLaunchCommand,
                terminalSetTabTitle: current.terminalSetTabTitle,
                gitlabHost: current.gitlabHost,
                gitlabToken: current.gitlabToken,
                githubHost: current.githubHost,
                githubToken: current.githubToken,
                aiProvider: current.aiProvider,
                aiBaseURL: current.aiBaseURL,
                aiAPIKey: current.aiAPIKey,
                aiModel: current.aiModel,
                aiCustomPrompt: current.aiCustomPrompt,
                activeWorkflowPreset: current.activeWorkflowPreset,
                activePlatform: target.platform.rawValue,
                activeWorkspaceID: target.id,
                workspaces: current.workspaces,
                githubDefaultTargetBranch: current.githubDefaultTargetBranch,
                githubDashboardBaselines: current.githubDashboardBaselines,
                gitlabDashboardBaselines: current.gitlabDashboardBaselines,
                mergeRootDirs: current.mergeRootDirs,
                mergeBranchMiddle: current.mergeBranchMiddle,
                envBranches: current.envBranches,
                branchMap: current.branchMap,
                protectedTargets: current.protectedTargets,
                autoMergeDelaySeconds: current.autoMergeDelaySeconds,
                autoMergeRetryCount: current.autoMergeRetryCount,
                syncIDEConfigs: current.syncIDEConfigs,
                ideConfigSyncItems: current.ideConfigSyncItems
            )
            appConfig = updatedConfig
            worktreeConfig = updatedConfig.asWorktreeConfig(for: target)
            Task.detached(priority: .utility) { [service] in
                _ = try? await service.saveWorkbenchConfig(updatedConfig)
            }
        }

        // 3. 后台静默更新全量工作树与远端状态（带代际防覆盖校验）
        Task {
            guard self.workspaceSwitchGeneration == expectedGen, self.activeWorkspace?.id == expectedWSID else { return }
            await refreshWorktrees(silent: true)
            guard self.workspaceSwitchGeneration == expectedGen, self.activeWorkspace?.id == expectedWSID else { return }
            await refreshLocalMergeProjects(silent: true)
            guard self.workspaceSwitchGeneration == expectedGen, self.activeWorkspace?.id == expectedWSID else { return }
            await refreshMergeProjects(silent: true)
            if selectedSection == .mergeDashboard, self.workspaceSwitchGeneration == expectedGen {
                await refreshMergeDashboard()
            }
        }
    }

    func openNewWorkspaceEditor(defaultPlatform: RepositoryPlatform = .gitlab) {
        workspaceEditorDraft = WorkspaceProfileDraft(
            id: UUID().uuidString,
            name: defaultPlatform == .github ? "GitHub 工作区" : "私有 GitLab",
            platform: defaultPlatform,
            projectsRootDirs: [],
            worktreesRootDir: "",
            host: defaultPlatform == .github ? "https://github.com" : "",
            token: "",
            defaultTargetBranch: defaultPlatform == .github ? "main" : "master",
            dashboardBaselinesText: defaultPlatform == .github
                ? DefaultDashboardBaselines.github.joined(separator: ", ")
                : DefaultDashboardBaselines.gitlab.joined(separator: ", "),
            envBranchesText: defaultPlatform == .gitlab ? "dev, test, stage, uat" : "",
            mergeBranchMiddle: "sync",
            branchMappings: []
        )
        showingWorkspaceEditorSheet = true
    }

    func openEditWorkspaceEditor(_ profile: WorkspaceProfile) {
        workspaceEditorDraft = WorkspaceProfileDraft(profile: profile)
        showingWorkspaceEditorSheet = true
    }

    func saveWorkspaceEditorDraft(_ draft: WorkspaceProfileDraft, switchToIt: Bool = true) async {
        let profile = draft.toWorkspaceProfile()
        if let idx = settingsDraft.workspaces.firstIndex(where: { $0.id == profile.id }) {
            settingsDraft.workspaces[idx] = WorkspaceProfileDraft(profile: profile)
        } else {
            settingsDraft.workspaces.append(WorkspaceProfileDraft(profile: profile))
        }
        if switchToIt || settingsDraft.activeWorkspaceID.isEmpty {
            activeWorkspaceID = profile.id
            settingsDraft.activeWorkspaceID = profile.id
            settingsDraft.activePlatform = profile.platform.rawValue
            selectedPlatformFilter = profile.platform
        }
        showingWorkspaceEditorSheet = false
        workspaceEditorDraft = nil
        workspaceCaches.removeValue(forKey: profile.id)
        await saveSettings()
    }

    func deleteWorkspaceProfile(id: String) async {
        guard settingsDraft.workspaces.count > 1 else {
            settingsOperation = OperationState(
                isRunning: false,
                title: "无法删除",
                detail: "至少需要保留一个工作区标签",
                errorMessage: "至少需要保留一个工作区标签"
            )
            return
        }
        settingsDraft.workspaces.removeAll { $0.id == id }
        if activeWorkspaceID == id || settingsDraft.activeWorkspaceID == id {
            if let next = settingsDraft.workspaces.first {
                activeWorkspaceID = next.id
                settingsDraft.activeWorkspaceID = next.id
                settingsDraft.activePlatform = next.platform.rawValue
                selectedPlatformFilter = next.platform
            }
        }
        workspaceCaches.removeValue(forKey: id)
        await saveSettings()
    }

    func worktreeBaselineStatus(for item: WorktreeItem) -> [(target: String, merged: Bool)] {
        let targets = currentDashboardBaselines
        if let dashItem = mergeDashboardItems.first(where: { $0.id == item.id || $0.branch == item.branch }) {
            return targets.map { ($0, dashItem.mergeStatus[$0] ?? false) }
        }
        return targets.map { ($0, false) }
    }

    func prepareCreateMergeRequest(fromWorktree item: WorktreeItem) {
        if let project = mergeProjects.first(where: { $0.path == item.projectPath }) {
            selectedMergeProjectID = project.id
        }
        selectedSection = .mergeRequests
        prepareCreateMergeRequest()
        if !item.branch.isEmpty {
            createMRDraft.sourceBranch = item.branch
        }
    }

    func setActivePlatform(_ platform: RepositoryPlatform) {
        guard platform != .all else { return }
        selectedPlatformFilter = platform
        if settingsDraft.activePlatform != platform.rawValue {
            settingsDraft.activePlatform = platform.rawValue
        }
    }

    private func handleActivePlatformChanged() {
        guard !isSwitchingWorkspace else { return }
        let wtProjects = filteredWorktreeProjects
        if let cur = currentWorktreeProject, cur.platform != activePlatform {
            selectedProjectID = wtProjects.first?.id
        } else if selectedProjectID == nil || !wtProjects.contains(where: { $0.id == selectedProjectID }) {
            selectedProjectID = wtProjects.first?.id
        }

        if selectedWorktreeID == nil || !filteredWorktrees.contains(where: { $0.id == selectedWorktreeID }) {
            selectedWorktreeID = filteredWorktrees.first?.id
        }

        let localProjects = filteredLocalMergeProjects
        if let cur = currentLocalMergeProject, cur.platform != activePlatform {
            selectedLocalProjectID = localProjects.first?.id
        } else if selectedLocalProjectID == nil || !localProjects.contains(where: { $0.id == selectedLocalProjectID }) {
            selectedLocalProjectID = localProjects.first?.id
        }
        syncLocalOperationDefaults(resetSourceBranch: false)

        let mrProjects = filteredMergeProjects
        if let cur = currentMergeProject, cur.platform != activePlatform {
            selectedMergeProjectID = mrProjects.first?.id
        } else if selectedMergeProjectID == nil || !mrProjects.contains(where: { $0.id == selectedMergeProjectID }) {
            selectedMergeProjectID = mrProjects.first?.id
        }

        mergeDashboardProjectID = nil
        mergeDashboardItems = []
        selectedDashboardItemID = nil

        if selectedSection == .mergeDashboard {
            Task {
                await refreshMergeDashboard()
            }
        } else if selectedSection == .mergeRequests && currentMergeProject != nil {
            Task {
                await refreshMergeRequests(silent: true)
            }
        }
    }

    var filteredMergeProjects: [MergeProject] {
        mergeProjects.filter { project in
            activePlatform == .all || project.platform == activePlatform
        }
    }

    var currentMergeProject: MergeProject? {
        if let id = selectedMergeProjectID {
            return filteredMergeProjects.first(where: { $0.id == id })
                ?? mergeProjects.first(where: { $0.id == id })
        }
        return filteredMergeProjects.first ?? mergeProjects.first
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
            case .fullyMerged:
                if case .fullyMerged = item.statusType { return true }
                if case .remoteDeleted = item.statusType { return true }
                return item.isFullyMerged
            case .partialMerged:
                if case .partiallyMerged = item.statusType { return true }
                return false
            case .stale:
                if case .stale = item.statusType { return true }
                return false
            case .protected:
                return item.isProtected
            }
        }
    }

    var sweeperFullyMergedCount: Int {
        sweeperItems.filter { $0.isFullyMerged && !$0.isProtected }.count
    }

    var sweeperPartiallyMergedCount: Int {
        sweeperItems.filter {
            if case .partiallyMerged = $0.statusType { return true }
            return false
        }.count
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
        let baselines = currentDashboardBaselines
        isSweeperAnalyzing = true
        sweeperOperation = OperationState(
            isRunning: true,
            title: "正在分析",
            detail: "正在比对 \(baselines.joined(separator: " / ")) 的合入状态..."
        )

        let projectWorktrees = worktrees.filter { $0.projectPath == project.path }
        // 分支引用集合：包含本地名与 origin/* 远端引用
        // baseBranches 来自 remoteBranches()，已去掉 origin/ 前缀，这里补回远端引用名
        var existingBranches = Set(project.baseBranches)
        existingBranches.formUnion(project.localBranches)
        for name in project.baseBranches {
            existingBranches.insert("origin/\(name)")
        }

        let candidatesByTarget = resolveCandidateBases(targets: baselines)

        for target in baselines {
            if (try? service.gitCliService.remoteBranchExists(projectPath: project.path, branch: target)) == true {
                existingBranches.insert("origin/\(target)")
            }
            if (try? service.gitCliService.localBranchExists(projectPath: project.path, branch: target)) == true {
                existingBranches.insert(target)
            }
        }

        let results = await WorktreeSweeperAnalyzer.analyze(
            projectWorktrees: projectWorktrees,
            projectPath: project.path,
            targets: baselines,
            candidateBasesByTarget: candidatesByTarget,
            existingBranches: existingBranches,
            gitCli: service.gitCliService
        )

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
        // 清理后同步刷新合入看板，避免显示已删除的工作树
        if let removedID = selectedDashboardItemID, !worktrees.contains(where: { $0.id == removedID }) {
            selectedDashboardItemID = nil
        }
        await forceRefreshMergeDashboard()

        sweeperOperation = OperationState(
            isRunning: false,
            title: "回收完成",
            detail: "已成功释放 \(purgedCount) 个工作树目录与空间",
            fractionCompleted: 1,
            successMessage: "成功回收 \(purgedCount) 个工作树！"
        )
    }

    nonisolated static func formatSizeMB(_ totalMB: Double) -> String {
        if totalMB >= 1024 {
            return String(format: "%.2f GB", totalMB / 1024)
        } else {
            return String(format: "%.0f MB", totalMB)
        }
    }

    var mrSortOrder = [KeyPathComparator(\MergeRequestItem.iid, order: .reverse)]

    // MARK: - Merge Dashboard Computeds & Methods

    var mergeDashboardFullyMergedCount: Int {
        mergeDashboardItems.filter { $0.isFullyMerged && !$0.isDirty && $0.kind != .mainRepo }.count
    }

    var mergeDashboardDirtyCount: Int {
        mergeDashboardItems.filter { $0.isDirty && $0.kind != .mainRepo }.count
    }

    var mergeDashboardPartiallyMergedCount: Int {
        mergeDashboardItems.filter { !$0.isFullyMerged && !$0.isNotMerged && !$0.isDirty && $0.kind != .mainRepo }.count
    }

    var mergeDashboardNotMergedCount: Int {
        mergeDashboardItems.filter { $0.isNotMerged && !$0.isDirty && $0.kind != .mainRepo }.count
    }

    func refreshMergeDashboard(force: Bool = false) async {
        guard let project = currentWorktreeProject else { return }

        // 避免重复分析同一项目（非强制模式下）
        if !force && mergeDashboardProjectID == project.id && !mergeDashboardItems.isEmpty { return }

        // 避免重复并发分析
        if isMergeDashboardAnalyzing { return }

        isMergeDashboardAnalyzing = true
        let targetProjectID = project.id

        let gitCli = service.gitCliService
        let projectPath = project.path

        // 后台并发分析前，静默 fetch 远端 origin，确保本地的 origin/* 引用与远端 GitLab 保持最新
        await Task.detached(priority: .utility) {
            _ = try? gitCli.fetch(projectPath: projectPath, remote: "origin")
        }.value

        let projectWorktrees = worktrees.filter { $0.projectPath == project.path }
        let mergeTargets = currentDashboardBaselines
        let targetNames = mergeTargets
        let candidatesByTarget = resolveCandidateBases(targets: targetNames)

        // 构建分支引用集合
        var existingBranches = Set(project.baseBranches)
        existingBranches.formUnion(project.localBranches)
        for name in project.baseBranches {
            existingBranches.insert("origin/\(name)")
        }
        for target in targetNames {
            if (try? gitCli.remoteBranchExists(projectPath: project.path, branch: target)) == true {
                existingBranches.insert("origin/\(target)")
            }
            if (try? gitCli.localBranchExists(projectPath: project.path, branch: target)) == true {
                existingBranches.insert(target)
            }
        }

        let existingBranchSet = existingBranches

        // 后台并发分析
        let items = await Task.detached(priority: .utility) { () -> [MergeDashboardItem] in
            final class Collector: @unchecked Sendable {
                private var items: [MergeDashboardItem] = []
                private let lock = NSLock()
                func append(_ item: MergeDashboardItem) {
                    lock.lock()
                    defer { lock.unlock() }
                    items.append(item)
                }
                var all: [MergeDashboardItem] {
                    lock.lock()
                    defer { lock.unlock() }
                    return items
                }
            }

            let collector = Collector()
            DispatchQueue.concurrentPerform(iterations: projectWorktrees.count) { index in
                let wt = projectWorktrees[index]
                let isMain = wt.kind == .mainRepo

                let statuses: [String: Bool]
                let matchedMap: [String: String]

                if isMain {
                    statuses = Dictionary(uniqueKeysWithValues: mergeTargets.map { ($0, true) })
                    matchedMap = Dictionary(uniqueKeysWithValues: mergeTargets.map { ($0, "主仓库") })
                } else {
                    let detail = gitCli.checkBranchMergedTargetsWithDetails(
                        projectPath: projectPath,
                        branch: wt.branch,
                        targets: targetNames,
                        candidateBasesByTarget: candidatesByTarget,
                        existingBranches: existingBranchSet
                    )
                    statuses = Dictionary(uniqueKeysWithValues: mergeTargets.map { ($0, detail.mergedStatus[$0] ?? false) })
                    matchedMap = Dictionary(uniqueKeysWithValues: mergeTargets.compactMap { target in
                        if let matched = detail.matchedBranches[target] {
                            return (target, matched)
                        }
                        return nil
                    })
                }

                collector.append(MergeDashboardItem(
                    id: wt.id,
                    branch: wt.branch,
                    kind: wt.kind,
                    isDirty: wt.isDirty,
                    updatedAt: wt.updatedAt,
                    mergeTargets: mergeTargets,
                    mergeStatus: statuses,
                    matchedBranches: matchedMap
                ))
            }
            return collector.all
        }.value

        // 确保分析完成时用户仍然停留在同一个项目
        guard currentWorktreeProject?.id == targetProjectID else {
            isMergeDashboardAnalyzing = false
            return
        }

        // 排序：主仓库置顶 → 全部合入 → 部分合入 → 未合入
        let sortedItems = items.sorted { lhs, rhs in
            if lhs.kind == .mainRepo && rhs.kind != .mainRepo { return true }
            if lhs.kind != .mainRepo && rhs.kind == .mainRepo { return false }
            if lhs.mergedCount != rhs.mergedCount { return lhs.mergedCount > rhs.mergedCount }
            return lhs.branch.localizedStandardCompare(rhs.branch) == .orderedAscending
        }

        mergeDashboardProjectID = targetProjectID
        mergeDashboardItems = sortedItems
        if selectedDashboardItemID == nil || !sortedItems.contains(where: { $0.id == selectedDashboardItemID }) {
            selectedDashboardItemID = sortedItems.first(where: { $0.kind != .mainRepo })?.id ?? sortedItems.first?.id
        }
        isMergeDashboardAnalyzing = false
    }

    func forceRefreshMergeDashboard() async {
        // 原地刷新：绝不清空已有 mergeDashboardItems，避免界面剧烈跳闪
        await refreshMergeDashboard(force: true)
    }

    /// 为指定的项目构建每个基线目标（master/stage/test/uat）的候选分支列表
    /// 严格只比对真正的基线分支：优先远端权威基线 origin/<target>，其次本地环境分支 <target>
    private func resolveCandidateBases(targets: [String]) -> [String: [String]] {
        var candidatesByTarget: [String: [String]] = [:]
        for target in targets {
            candidatesByTarget[target] = ["origin/\(target)", target]
        }
        return candidatesByTarget
    }

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

    var filteredExistingWorktreeBranchOptions: [ExistingWorktreeBranchOption] {
        let all = availableExistingWorktreeBranchOptions
        let keyword = existingBranchSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return all }

        let matched = all.filter { $0.name.localizedCaseInsensitiveContains(keyword) }
        // 当前选中项始终保留在列表中，否则 Picker 的 selection 找不到对应 tag 会显示空白
        if let selected = all.first(where: { $0.name == createWorktreeDraft.branchName }),
           !matched.contains(where: { $0.name == selected.name }) {
            return [selected] + matched
        }
        return matched
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

        if let mainline = activeWorkspace?.primaryMainlineBranch ?? localMergeContext?.config.mainlineBranches.first {
            lines.append("- 完成后自动切回主干分支 `\(mainline)`")
        } else {
            lines.append("- 未配置主干分支，完成后保持当前分支")
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
        if localOperation.isRunning || activeSyncSession != nil {
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
        if let ws = activeWorkspace, !ws.projectsRootDirs.isEmpty {
            let placeholders = service.gitCliService.scanProjectPlaceholders(
                rootDirs: ws.projectsRootDirs,
                forcedPlatform: ws.platform
            )
            if !placeholders.isEmpty {
                worktreeProjects = placeholders
                selectedProjectID = placeholders.first?.id
            }
        }
        if workspaces.isEmpty && appConfig?.worktreeProjectsRootDirs.isEmpty == true {
            showingOnboardingSheet = true
        }
        Task.detached(priority: .utility) {
            let hasGH = !GitHubProvider.resolveToken(configuredToken: "").isEmpty
            await MainActor.run {
                self.ghCLITokenAvailable = hasGH
            }
        }
        // 核心工作区（工作树）立即加载并渲染（并发并行扫描，只需 ~0.25s）
        await refreshWorktrees()

        // 分支同步与远程项目在后台异步并发加载，并预热其余工作区缓存实现秒切
        Task {
            await refreshLocalMergeProjects(silent: true)
        }
        Task {
            await refreshMergeProjects(silent: true)
        }
        Task {
            await prewarmInactiveWorkspaces()
        }
    }

    private func prewarmInactiveWorkspaces() async {
        let activeID = activeWorkspace?.id
        let others = workspaces.filter { $0.id != activeID && !$0.projectsRootDirs.isEmpty }
        for ws in others {
            if workspaceCaches[ws.id] != nil { continue }
            if let snapshot = try? await service.loadWorktreeSnapshot(workspace: ws, onProgress: { _ in }) {
                if workspaceCaches[ws.id] == nil {
                    workspaceCaches[ws.id] = WorkspaceViewSnapshotCache(
                        worktreeProjects: snapshot.projects,
                        worktrees: snapshot.worktrees,
                        localMergeProjects: [],
                        mergeProjects: [],
                        selectedProjectID: snapshot.projects.first?.id,
                        selectedWorktreeID: snapshot.worktrees.first(where: { $0.projectPath == snapshot.projects.first?.path })?.id,
                        selectedLocalProjectID: nil,
                        selectedMergeProjectID: nil,
                        mergeDashboardProjectID: nil,
                        mergeDashboardItems: [],
                        selectedDashboardItemID: nil
                    )
                }
            }
        }
    }

    func refreshSettings() async {
        refreshScannedTerminals()
        refreshScannedIDEs()
        settingsOperation = OperationState(isRunning: true, title: "读取设置", detail: "正在加载 GWorkbench 配置")
        do {
            let config = try await service.loadWorkbenchConfig()
            appConfig = config
            if !config.activeWorkspaceID.isEmpty {
                activeWorkspaceID = config.activeWorkspaceID
            } else if let firstWS = config.workspaces.first {
                activeWorkspaceID = firstWS.id
            }
            let currentWS = config.currentWorkspace
            worktreeConfig = config.asWorktreeConfig(for: currentWS)
            // 让平台判定兜底逻辑拿到当前工作区的 GitLab/GitHub 主机与凭据
            GitLabHostStore.shared.update(currentWS?.platform == .gitlab ? currentWS?.host : config.gitlabHost)
            GitCredentialStore.shared.update(
                gitlabToken: currentWS?.platform == .gitlab ? (currentWS?.token ?? config.gitlabToken) : config.gitlabToken,
                githubToken: currentWS?.platform == .github ? (currentWS?.token ?? config.githubToken) : config.githubToken
            )
            if let wsPlatform = currentWS?.platform {
                selectedPlatformFilter = wsPlatform
            } else if let restored = RepositoryPlatform(rawValue: config.activePlatform), restored != .all {
                selectedPlatformFilter = restored
            }
            settingsDraft = SettingsDraft(config: config)
            if settingsDraft.activeWorkspaceID.isEmpty {
                settingsDraft.activeWorkspaceID = activeWorkspaceID
            }
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

    private var lastForegroundRefreshTime: Date = .distantPast

    func handleWindowDidBecomeActive() async {
        guard didBootstrap else { return }

        // 防抖：3秒内重复切窗不重复触发，避免 Command+Tab 连续切换引发并发刷新
        let now = Date()
        guard now.timeIntervalSince(lastForegroundRefreshTime) >= 3.0 else { return }
        lastForegroundRefreshTime = now

        switch selectedSection ?? .worktrees {
        case .worktrees:
            // 立即刷新当前选中的工作树文件改动与 Ahead/Behind
            syncSelectedWorktreeDetails()
            // 同时静默刷新工作树状态与分支
            await refreshWorktrees(silent: true)
        case .mergeDashboard:
            await refreshWorktrees(silent: true)
            await forceRefreshMergeDashboard()
        case .branchSync:
            await refreshLocalMergeProjects(silent: true)
        case .mergeRequests:
            await refreshMergeRequests(silent: true)
        }
    }

    func refreshWorktrees(silent: Bool = false) async {
        let expectedWSID = activeWorkspace?.id
        let expectedGen = workspaceSwitchGeneration
        if !silent {
            appendWorktreeLog("开始扫描工作树...")
            worktreeOperation = OperationState(
                isRunning: true,
                title: "刷新工作树",
                detail: "开始读取本地配置",
                logs: worktreeOperation.logs
            )
        }
        globalErrorMessage = nil

        do {
            if gitVersion == "Git" || gitVersion.isEmpty {
                if let ver = try? GitCliService().gitVersion() {
                    gitVersion = ver
                }
            }

            let snapshot = try await service.loadWorktreeSnapshot(workspace: activeWorkspace) { [weak self] progress in
                if !silent {
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
            }

            guard expectedGen == workspaceSwitchGeneration, expectedWSID == activeWorkspace?.id else {
                if let expectedWSID {
                    workspaceCaches[expectedWSID] = WorkspaceViewSnapshotCache(
                        worktreeProjects: snapshot.projects,
                        worktrees: snapshot.worktrees,
                        localMergeProjects: workspaceCaches[expectedWSID]?.localMergeProjects ?? [],
                        mergeProjects: workspaceCaches[expectedWSID]?.mergeProjects ?? [],
                        selectedProjectID: snapshot.projects.first?.id,
                        selectedWorktreeID: snapshot.worktrees.first?.id,
                        selectedLocalProjectID: workspaceCaches[expectedWSID]?.selectedLocalProjectID,
                        selectedMergeProjectID: workspaceCaches[expectedWSID]?.selectedMergeProjectID,
                        mergeDashboardProjectID: nil,
                        mergeDashboardItems: [],
                        selectedDashboardItemID: nil
                    )
                }
                return
            }

            worktreeConfig = snapshot.config
            worktreeProjects = snapshot.projects
            worktrees = snapshot.worktrees

            if activeWorkspace == nil, !worktreeProjects.isEmpty, filteredWorktreeProjects.isEmpty {
                if let firstAvailable = switchablePlatforms.first {
                    selectedPlatformFilter = firstAvailable
                }
            }

            if selectedProjectID == nil || !filteredWorktreeProjects.contains(where: { $0.id == selectedProjectID }) {
                selectedProjectID = filteredWorktreeProjects.first?.id ?? worktreeProjects.first?.id
            }

            if selectedWorktreeID == nil || !filteredWorktrees.contains(where: { $0.id == selectedWorktreeID }) {
                selectedWorktreeID = filteredWorktrees.first?.id
            }

            syncSelectedWorktreeDescriptionDraft()
            syncSelectedWorktreeDetails()
            syncCreateWorktreeDefaults(resetBranchName: false)
            refreshWorktreeDiskUsagesInBackground()

            if !silent {
                appendWorktreeLog("工作树刷新完成：已同步 \(snapshot.projects.count) 个项目和 \(snapshot.worktrees.count) 个工作树")
                worktreeOperation = OperationState(
                    isRunning: false,
                    title: "工作树已刷新",
                    detail: "已同步 \(snapshot.projects.count) 个项目和 \(snapshot.worktrees.count) 个工作树",
                    fractionCompleted: 1,
                    logs: worktreeOperation.logs,
                    successMessage: "刷新完成"
                )
            }
        } catch {
            if !silent {
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
    }

    func refreshWorktreeDiskUsagesInBackground() {
        let uncachedItems = worktrees.filter { $0.diskUsage == "-" || $0.diskUsage == "未知" || $0.diskUsage.isEmpty }
        guard !uncachedItems.isEmpty else { return }

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let gitCli = self.service.gitCliService

            // 使用 concurrentPerform：du -sh 是阻塞式子进程调用，
            // 放在 withTaskGroup 里会占满 Swift 协作线程池并可能导致任务组永不完成。
            final class UsageCollector: @unchecked Sendable {
                private var items: [(String, String)] = []
                private let lock = NSLock()
                func append(id: String, usage: String) {
                    lock.lock()
                    defer { lock.unlock() }
                    items.append((id, usage))
                }
                var all: [(String, String)] {
                    lock.lock()
                    defer { lock.unlock() }
                    return items
                }
            }

            let collector = UsageCollector()
            let targets = uncachedItems

            DispatchQueue.concurrentPerform(iterations: targets.count) { index in
                let item = targets[index]
                let usage = (try? gitCli.diskUsage(path: item.path)) ?? "未知"
                DiskUsageStore.shared.set(usage, for: item.path)
                collector.append(id: item.id, usage: usage)
            }

            let updatedList = collector.all

            await MainActor.run {
                let map = Dictionary(uniqueKeysWithValues: updatedList)
                for i in 0..<self.worktrees.count {
                    if let newUsage = map[self.worktrees[i].id] {
                        self.worktrees[i].diskUsage = newUsage
                    }
                }
            }
        }
    }

    func refreshLocalMergeProjects(silent: Bool = false) async {
        if !silent {
            localOperation = OperationState(isRunning: true, title: "刷新分支同步项目", detail: "开始读取本地配置")
        }
        globalErrorMessage = nil

        do {
            let context = try await service.loadLocalMergeContext(workspace: activeWorkspace) { [weak self] progress in
                if !silent {
                    Task { @MainActor in
                        self?.localOperation = OperationState(
                            isRunning: true,
                            title: progress.title,
                            detail: progress.detail,
                            fractionCompleted: progress.fractionCompleted
                        )
                    }
                }
            }

            localMergeContext = context
            localMergeProjects = context.projects

            if let currentPath = currentWorktreeProject?.path,
               let matched = filteredLocalMergeProjects.first(where: { $0.path == currentPath }) {
                selectedLocalProjectID = matched.id
            } else if selectedLocalProjectID == nil || !filteredLocalMergeProjects.contains(where: { $0.id == selectedLocalProjectID }) {
                selectedLocalProjectID = filteredLocalMergeProjects.first?.id ?? localMergeProjects.first?.id
            }

            syncLocalOperationDefaults(resetSourceBranch: false)

            if !silent {
                localOperation = OperationState(
                    isRunning: false,
                    title: "分支同步项目已刷新",
                    detail: "已同步 \(context.projects.count) 个本地仓库",
                    fractionCompleted: 1,
                    successMessage: "刷新完成"
                )
            }
        } catch {
            if !silent {
                localOperation = OperationState(
                    isRunning: false,
                    title: "分支同步项目刷新失败",
                    detail: error.localizedDescription,
                    errorMessage: error.localizedDescription
                )
                globalErrorMessage = error.localizedDescription
            }
        }
    }

    func refreshMergeProjects(silent: Bool = false) async {
        if !silent {
            mrOperation = OperationState(isRunning: true, title: "刷新合并项目", detail: "开始读取配置")
        }
        globalErrorMessage = nil

        do {
            let context = try await service.loadMergeContext(workspace: activeWorkspace) { [weak self] progress in
                if !silent {
                    Task { @MainActor in
                        self?.mrOperation = OperationState(
                            isRunning: true,
                            title: progress.title,
                            detail: progress.detail,
                            fractionCompleted: progress.fractionCompleted
                        )
                    }
                }
            }
            mergeRequestContext = context
            mergeProjects = context.projects

            if let currentPath = currentWorktreeProject?.path,
               let matched = filteredMergeProjects.first(where: { $0.path == currentPath }) {
                selectedMergeProjectID = matched.id
            } else if selectedMergeProjectID == nil || !filteredMergeProjects.contains(where: { $0.id == selectedMergeProjectID }) {
                selectedMergeProjectID = filteredMergeProjects.first?.id ?? mergeProjects.first?.id
            }

            await refreshMergeRequests(silent: silent)
        } catch {
            if !silent {
                mrOperation = OperationState(
                    isRunning: false,
                    title: "合并项目刷新失败",
                    detail: error.localizedDescription,
                    errorMessage: error.localizedDescription
                )
                globalErrorMessage = error.localizedDescription
            }
        }
    }

    func refreshMergeRequests(silent: Bool = false) async {
        if mergeRequestContext == nil || mergeProjects.isEmpty {
            await refreshMergeProjects()
            return
        }
        guard let context = mergeRequestContext, let project = currentMergeProject else {
            mergeRequests = []
            selectedMergeRequestID = nil
            return
        }

        if !silent {
            mrOperation = OperationState(isRunning: true, title: "刷新待合并列表", detail: "正在读取 \(project.displayName)")
        }

        do {
            let items = try await service.loadPendingMergeRequests(context: context, project: project) { [weak self] progress in
                if !silent {
                    Task { @MainActor in
                        self?.mrOperation = OperationState(
                            isRunning: true,
                            title: progress.title,
                            detail: progress.detail,
                            fractionCompleted: progress.fractionCompleted
                        )
                    }
                }
            }

            mergeRequests = items
            selectedBatchApproveMRIDs.formIntersection(items.map(\.id))
            if selectedMergeRequestID == nil || !filteredMergeRequests.contains(where: { $0.id == selectedMergeRequestID }) {
                selectedMergeRequestID = filteredMergeRequests.first?.id
            }

            if !silent {
                mrOperation = OperationState(
                    isRunning: false,
                    title: "待合并列表已刷新",
                    detail: "当前项目共有 \(items.count) 条打开中的 MR",
                    fractionCompleted: 1,
                    successMessage: "刷新完成"
                )
            }
        } catch {
            if !silent {
                mrOperation = OperationState(
                    isRunning: false,
                    title: "待合并列表刷新失败",
                    detail: error.localizedDescription,
                    errorMessage: error.localizedDescription
                )
                globalErrorMessage = error.localizedDescription
            }
        }
    }

    func selectWorkspaceProject(_ project: LocalProject) {
        let prevProjectID = selectedProjectID
        selectedProjectID = project.id

        if !filteredWorktrees.contains(where: { $0.id == selectedWorktreeID }) {
            selectedWorktreeID = filteredWorktrees.first?.id
        }
        syncSelectedWorktreeDescriptionDraft()
        syncSelectedWorktreeDetails()
        syncCreateWorktreeDefaults(resetBranchName: false)

        if let matchedLocal = localMergeProjects.first(where: { $0.path == project.path || $0.name == project.name }) {
            selectedLocalProjectID = matchedLocal.id
            syncLocalOperationDefaults(resetSourceBranch: false)
        }

        if let matchedMerge = mergeProjects.first(where: { $0.path == project.path || $0.name == project.name }) {
            if selectedMergeProjectID != matchedMerge.id {
                selectedMergeProjectID = matchedMerge.id
                selectedBatchApproveMRIDs.removeAll()
                createMRDraft = CreateMRDraft()
                if selectedSection == .mergeRequests {
                    Task {
                        await refreshMergeRequests()
                    }
                }
            }
        }

        if prevProjectID != project.id {
            mergeDashboardProjectID = nil
            mergeDashboardItems = []
            selectedDashboardItemID = nil
            if selectedSection == .mergeDashboard {
                Task {
                    await refreshMergeDashboard()
                }
            }
        }
    }

    func openBranchSync(forBranch branch: String, projectPath: String?) {
        if let projectPath,
           let matchedWorktreeProj = worktreeProjects.first(where: { $0.path == projectPath }) {
            selectWorkspaceProject(matchedWorktreeProj)
        }
        if let projectPath,
           let matchedLocal = localMergeProjects.first(where: { $0.path == projectPath }) {
            selectedLocalProjectID = matchedLocal.id
        }
        if !branch.isEmpty {
            localOperationSourceBranch = branch
            if localOperationMode == .syncEnvironments {
                localOperationMode = .mergeCustom
            }
        }
        syncLocalOperationDefaults(resetSourceBranch: false)
        if !branch.isEmpty {
            localOperationSourceBranch = branch
        }
        selectedSection = .branchSync
    }

    func openCreateMR(forBranch branch: String, projectPath: String?) {
        if let projectPath,
           let matchedWorktreeProj = worktreeProjects.first(where: { $0.path == projectPath }) {
            selectWorkspaceProject(matchedWorktreeProj)
        }
        selectedSection = .mergeRequests
        Task {
            if mergeRequestContext == nil || mergeProjects.isEmpty {
                await refreshMergeProjects(silent: true)
            }
            if let projectPath,
               let matchedMerge = mergeProjects.first(where: { $0.path == projectPath }) {
                selectedMergeProjectID = matchedMerge.id
            }
            prepareCreateMergeRequest()
            if !branch.isEmpty {
                createMRDraft.sourceBranch = branch
            }
        }
    }

    func selectProject(_ projectID: String) {
        if let proj = worktreeProjects.first(where: { $0.id == projectID }) {
            selectWorkspaceProject(proj)
            return
        }
        guard selectedProjectID != projectID else { return }
        selectedProjectID = projectID
        if !filteredWorktrees.contains(where: { $0.id == selectedWorktreeID }) {
            selectedWorktreeID = filteredWorktrees.first?.id
        }
        syncSelectedWorktreeDescriptionDraft()
        syncSelectedWorktreeDetails()
        syncCreateWorktreeDefaults(resetBranchName: false)
        mergeDashboardProjectID = nil
        mergeDashboardItems = []
    }

    func selectDashboardProject(_ projectID: String) {
        if let proj = worktreeProjects.first(where: { $0.id == projectID }) {
            if selectedProjectID == projectID && mergeDashboardProjectID == projectID && !mergeDashboardItems.isEmpty {
                return
            }
            selectWorkspaceProject(proj)
            return
        }
        if selectedProjectID == projectID && mergeDashboardProjectID == projectID && !mergeDashboardItems.isEmpty {
            return
        }
        selectedProjectID = projectID
        mergeDashboardProjectID = nil
        mergeDashboardItems = []
        selectedDashboardItemID = nil
        Task {
            await refreshMergeDashboard()
        }
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
        existingBranchSearchText = ""
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

    func openProjectInIDE(_ project: MergeProject, ide: IDEProfile? = nil) {
        let profile = ide ?? defaultIDEProfile
        do {
            try service.openInIDE(profile: profile, path: project.path)
            appendLocalOperationLog("已在 \(profile.effectiveLabel) 中打开: \(project.displayName)")
        } catch {
            appendLocalOperationLog("打开 IDE 失败: \(error.localizedDescription)")
        }
    }

    func openProjectInRebased(_ project: MergeProject) {
        if RebasedService.shared.isInstalled {
            do {
                try RebasedService.shared.openProject(path: project.path)
                appendLocalOperationLog("已在 Rebased 中打开: \(project.displayName)")
            } catch {
                appendLocalOperationLog("打开 Rebased 失败: \(error.localizedDescription)")
            }
        } else {
            showingRebasedInstallSheet = true
        }
    }

    func openProjectInTerminal(_ project: MergeProject) {
        let termName = appConfig?.terminalApp ?? settingsDraft.terminalApp
        let bundleID = appConfig?.terminalBundleID ?? settingsDraft.terminalBundleID
        let hookMode = appConfig?.terminalLaunchHookMode ?? settingsDraft.terminalLaunchHookMode
        let hookCmd = appConfig?.terminalLaunchCommand ?? settingsDraft.terminalLaunchCommand
        let shouldSetTitle = appConfig?.terminalSetTabTitle ?? settingsDraft.terminalSetTabTitle
        let tabTitle = shouldSetTitle ? resolvedProjectTabTitle(project) : nil
        do {
            try TerminalService.shared.openDirectoryWithHook(
                path: project.path,
                terminalName: termName,
                bundleID: bundleID,
                tabTitle: tabTitle,
                hookMode: hookMode,
                hookCommand: hookCmd
            )
            let tabInfo = tabTitle.map { " (Tab: \($0))" } ?? ""
            appendLocalOperationLog("已在 \(termName) 中打开: \(project.displayName)\(tabInfo)")
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
        mrOperation = OperationState(
            isRunning: false,
            title: "已复制 MR 链接",
            detail: item.webURL,
            logs: mrOperation.logs,
            successMessage: "已复制链接: \(item.iidLabel)"
        )
    }

    func copySelectedMRWebURL() {
        if let mr = selectedMergeRequest {
            copyMRWebURL(mr)
        }
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
        if resetBranchName {
            createWorktreeDraft.syncIDEConfigs = effectiveWorktreeConfig?.syncIDEConfigs ?? false
        }
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

    func openWorktreeInIDE(_ item: WorktreeItem, ide: IDEProfile? = nil) {
        let profile = ide ?? defaultIDEProfile
        do {
            try service.openInIDE(profile: profile, path: item.path)
            appendWorktreeLog("已在 \(profile.effectiveLabel) 中打开: \(item.branch) (\(item.path))")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "已打开 IDE",
                detail: item.path,
                logs: worktreeOperation.logs,
                successMessage: "已使用 \(profile.effectiveLabel) 打开"
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

    func openWorktreeInRebased(_ item: WorktreeItem) {
        if RebasedService.shared.isInstalled {
            do {
                try RebasedService.shared.openProject(path: item.path)
                appendWorktreeLog("已在 Rebased 中打开: \(item.branch) (\(item.path))")
            } catch {
                appendWorktreeLog("打开 Rebased 失败: \(error.localizedDescription)")
            }
        } else {
            showingRebasedInstallSheet = true
        }
    }

    func openWorktreeInTerminal(_ item: WorktreeItem) {
        let termName = appConfig?.terminalApp ?? settingsDraft.terminalApp
        let bundleID = appConfig?.terminalBundleID ?? settingsDraft.terminalBundleID
        let hookMode = appConfig?.terminalLaunchHookMode ?? settingsDraft.terminalLaunchHookMode
        let hookCmd = appConfig?.terminalLaunchCommand ?? settingsDraft.terminalLaunchCommand
        let shouldSetTitle = appConfig?.terminalSetTabTitle ?? settingsDraft.terminalSetTabTitle
        let tabTitle = shouldSetTitle ? resolvedWorktreeTabTitle(item) : nil
        do {
            try TerminalService.shared.openDirectoryWithHook(
                path: item.path,
                terminalName: termName,
                bundleID: bundleID,
                tabTitle: tabTitle,
                hookMode: hookMode,
                hookCommand: hookCmd
            )
            let tabInfo = tabTitle.map { " (Tab: \($0))" } ?? ""
            appendWorktreeLog("已在 \(termName) 中打开: \(item.branch) (\(item.path))\(tabInfo)")
            worktreeOperation = OperationState(
                isRunning: false,
                title: "已打开终端",
                detail: item.path,
                logs: worktreeOperation.logs,
                successMessage: "已在 \(termName) 中打开\(tabInfo)"
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

    func openFileInIDE(path: String, ide: IDEProfile? = nil) {
        guard let item = selectedWorktree else { return }
        let fullPath: String
        if path.hasPrefix("/") {
            fullPath = path
        } else {
            fullPath = URL(fileURLWithPath: item.path).appendingPathComponent(path).path
        }
        let profile = ide ?? defaultIDEProfile
        do {
            try service.openInIDE(profile: profile, path: fullPath)
            appendWorktreeLog("已在 \(profile.effectiveLabel) 中打开: \(path)")
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
        let shouldSetTitle = appConfig?.terminalSetTabTitle ?? settingsDraft.terminalSetTabTitle
        let tabTitle = shouldSetTitle ? resolvedWorktreeTabTitle(item) : nil
        do {
            try TerminalService.shared.runScriptInTerminal(command: command, path: item.path, terminalName: termName, tabTitle: tabTitle)
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

    func openSelectedWorktreeInIDE(ide: IDEProfile? = nil) {
        if let item = selectedWorktree {
            openWorktreeInIDE(item, ide: ide)
        }
    }

    func openCurrentSelectionInIDE(_ ide: IDEProfile? = nil) {
        switch selectedSection {
        case .mergeDashboard:
            if let wt = selectedDashboardWorktree {
                openWorktreeInIDE(wt, ide: ide)
            } else if let project = currentWorktreeProject {
                let profile = ide ?? defaultIDEProfile
                try? service.openInIDE(profile: profile, path: project.path)
            }
        case .worktrees:
            if let wt = selectedWorktree {
                openWorktreeInIDE(wt, ide: ide)
            } else if let project = currentWorktreeProject {
                let profile = ide ?? defaultIDEProfile
                try? service.openInIDE(profile: profile, path: project.path)
            }
        case .branchSync:
            if let project = currentLocalMergeProject {
                openProjectInIDE(project, ide: ide)
            }
        case .mergeRequests:
            if let project = currentWorktreeProject {
                let profile = ide ?? defaultIDEProfile
                try? service.openInIDE(profile: profile, path: project.path)
            }
        case .none:
            if let project = currentWorktreeProject {
                let profile = ide ?? defaultIDEProfile
                try? service.openInIDE(profile: profile, path: project.path)
            }
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

    func isInstalledIDEConfigured(_ ide: InstalledIDEApp) -> Bool {
        settingsDraft.ideProfiles.contains {
            $0.mode == "app" && (
                $0.command.caseInsensitiveCompare(ide.name) == .orderedSame ||
                $0.command.caseInsensitiveCompare(ide.defaultAppName) == .orderedSame ||
                $0.label.caseInsensitiveCompare(ide.displayName) == .orderedSame
            )
        }
    }

    func toggleInstalledIDEInDraft(_ ide: InstalledIDEApp) {
        if let existingIndex = settingsDraft.ideProfiles.firstIndex(where: {
            $0.mode == "app" && (
                $0.command.caseInsensitiveCompare(ide.name) == .orderedSame ||
                $0.command.caseInsensitiveCompare(ide.defaultAppName) == .orderedSame ||
                $0.label.caseInsensitiveCompare(ide.displayName) == .orderedSame
            )
        }) {
            let removedID = settingsDraft.ideProfiles[existingIndex].id
            removeIDEProfile(id: removedID)
            return
        }

        // 如果当前只有系统占位项 ("open" / "默认应用")，直接替换为所选编辑器
        if settingsDraft.ideProfiles.count == 1,
           let only = settingsDraft.ideProfiles.first,
           only.command == "open" || only.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let newProfile = IDEProfileDraft(
                id: only.id,
                label: ide.displayName,
                mode: "app",
                command: ide.name
            )
            settingsDraft.ideProfiles = [newProfile]
            setDefaultIDEProfile(id: newProfile.id)
            return
        }

        let newProfile = IDEProfileDraft(
            id: "ide-\(UUID().uuidString.prefix(8))",
            label: ide.displayName,
            mode: "app",
            command: ide.name
        )
        settingsDraft.ideProfiles.append(newProfile)
        if settingsDraft.defaultIDEProfileID.isEmpty {
            setDefaultIDEProfile(id: newProfile.id)
        }
    }

    func addCustomIDEProfile() {
        let newProfile = IDEProfileDraft(
            id: "ide-\(UUID().uuidString.prefix(8))",
            label: "自定义编辑器",
            mode: "custom",
            command: ""
        )
        settingsDraft.ideProfiles.append(newProfile)
        if settingsDraft.defaultIDEProfileID.isEmpty {
            setDefaultIDEProfile(id: newProfile.id)
        }
    }

    func removeIDEProfile(id: String) {
        settingsDraft.ideProfiles.removeAll { $0.id == id }
        if settingsDraft.ideProfiles.isEmpty {
            let fallback = IDEProfileDraft(id: "default-ide", label: "默认应用", mode: "app", command: "open")
            settingsDraft.ideProfiles = [fallback]
            setDefaultIDEProfile(id: fallback.id)
            return
        }
        if settingsDraft.defaultIDEProfileID == id || !settingsDraft.ideProfiles.contains(where: { $0.id == settingsDraft.defaultIDEProfileID }) {
            if let first = settingsDraft.ideProfiles.first {
                setDefaultIDEProfile(id: first.id)
            }
        }
    }

    func setDefaultIDEProfile(id: String) {
        settingsDraft.defaultIDEProfileID = id
        if let matched = settingsDraft.ideProfiles.first(where: { $0.id == id }) {
            settingsDraft.ideMode = matched.mode
            settingsDraft.ideCommand = matched.command
            settingsDraft.ideLabel = matched.label
        }
    }

    func selectIDE(_ ide: InstalledIDEApp) {
        if !isInstalledIDEConfigured(ide) {
            toggleInstalledIDEInDraft(ide)
        }
        if let matched = settingsDraft.ideProfiles.first(where: {
            $0.command.caseInsensitiveCompare(ide.name) == .orderedSame ||
            $0.label.caseInsensitiveCompare(ide.displayName) == .orderedSame
        }) {
            setDefaultIDEProfile(id: matched.id)
        }
        Task {
            await saveSettings()
        }
    }

    func testOpenIDE(_ draftProfile: IDEProfileDraft? = nil) {
        let profile: IDEProfile
        if let draftProfile {
            profile = draftProfile.toIDEProfile()
        } else if let matched = settingsDraft.ideProfiles.first(where: { $0.id == settingsDraft.defaultIDEProfileID }) {
            profile = matched.toIDEProfile()
        } else {
            profile = IDEProfile(
                id: "default-ide",
                label: settingsDraft.ideLabel,
                mode: settingsDraft.ideMode,
                command: settingsDraft.ideCommand
            )
        }
        let testPath = currentWorktreeProject?.path ?? FileManager.default.homeDirectoryForCurrentUser.path
        do {
            try IDEService.shared.openDirectory(path: testPath, ideMode: profile.mode, ideCommand: profile.command)
            let label = profile.effectiveLabel
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

    func testGitHubConnection(host: String? = nil, token: String? = nil) async {
        let activeDraft = settingsDraft.workspaces.first(where: { $0.id == activeWorkspaceID })
        let resolvedHost = (host ?? activeDraft?.host ?? settingsDraft.githubHost).trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedToken = (token ?? activeDraft?.token ?? settingsDraft.githubToken).trimmingCharacters(in: .whitespacesAndNewlines)
        settingsOperation = OperationState(isRunning: true, title: "测试 GitHub 连通性", detail: "正在请求 \(GitHubProvider.apiBaseURL(from: resolvedHost))/user ...")
        do {
            let msg = try await GitHubProvider.testConnection(configuredToken: resolvedToken, host: resolvedHost)
            ghCLITokenAvailable = !GitHubProvider.resolveToken(configuredToken: resolvedToken, host: resolvedHost).isEmpty
            settingsOperation = OperationState(
                isRunning: false,
                title: "GitHub 连通成功",
                detail: msg,
                fractionCompleted: 1,
                successMessage: msg
            )
        } catch {
            settingsOperation = OperationState(
                isRunning: false,
                title: "GitHub 连通失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func testGitLabConnection(host: String? = nil, token: String? = nil) async {
        let activeDraft = settingsDraft.workspaces.first(where: { $0.id == activeWorkspaceID })
        let resolvedHost = host ?? activeDraft?.host ?? settingsDraft.gitlabHost
        let resolvedToken = token ?? activeDraft?.token ?? settingsDraft.gitlabToken
        settingsOperation = OperationState(isRunning: true, title: "测试 GitLab 连通性", detail: "正在验证实例与访问令牌...")
        do {
            let msg = try await GitLabProvider.testConnection(host: resolvedHost, token: resolvedToken)
            settingsOperation = OperationState(
                isRunning: false,
                title: "GitLab 连通成功",
                detail: msg,
                fractionCompleted: 1,
                successMessage: msg
            )
        } catch {
            settingsOperation = OperationState(
                isRunning: false,
                title: "GitLab 连通失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
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
        let customPrompt = appConfig?.aiCustomPrompt ?? settingsDraft.aiCustomPrompt

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
                model: model,
                customPrompt: customPrompt
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
        let tabTitle = settingsDraft.terminalSetTabTitle ? (currentWorktreeProject?.displayName ?? "GWorkbench 测试") : nil
        do {
            try TerminalService.shared.openDirectory(path: testPath, terminalName: termName, bundleID: bundleID, tabTitle: tabTitle)
            let tabInfo = tabTitle.map { "，Tab: \($0)" } ?? ""
            settingsOperation = OperationState(
                isRunning: false,
                title: "已打开终端",
                detail: "已使用 \(termName) 打开目录 \(testPath)\(tabInfo)",
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

                // 启动交互式流水线
                await startInteractiveSyncPipeline(
                    project: project,
                    sourceBranch: sourceBranch,
                    targets: targets
                )
                return
            }

            for line in logs {
                appendLocalOperationLog(line)
            }

            await refreshSingleLocalMergeProjectBranchState(projectPath: project.path)

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

    // MARK: - 交互式同步状态机逻辑

    /// 启动交互式合并流水线
    func startInteractiveSyncPipeline(
        project: MergeProject,
        sourceBranch: String,
        targets: [String]
    ) async {
        let initialBranch = (try? GitCliService().currentLocalBranch(projectPath: project.path)) ?? sourceBranch
        let targetItems = targets.map {
            SyncSessionTargetItem(sourceBranch: sourceBranch, targetBranch: $0, status: .pending)
        }

        activeSyncSession = ActiveSyncSession(
            projectID: project.id,
            projectPath: project.path,
            projectName: project.displayName,
            initialBranch: initialBranch,
            targets: targetItems,
            currentTargetIndex: 0,
            activeConflictFiles: []
        )

        appendLocalOperationLog("开始交互式合并流水线: \(sourceBranch) -> \(targets.joined(separator: ", "))")
        await processNextInteractiveTarget()
    }

    /// 推进交互式流水线的下一个目标
    func processNextInteractiveTarget() async {
        guard var session = activeSyncSession else { return }

        // 如果全部目标已遍历完毕，收尾并归位初始分支
        if session.currentTargetIndex >= session.targets.count {
            await finishInteractiveSyncPipeline()
            return
        }

        let index = session.currentTargetIndex
        let targetItem = session.targets[index]
        session.targets[index].status = .inProgress
        session.activeConflictFiles = []
        session.conflictPhase = .none
        session.conflictMergeHeadSHA = nil
        session.isAutoCommittingConflict = false
        activeSyncSession = session

        let progressFraction = Double(index) / Double(session.targets.count)
        localOperation = OperationState(
            isRunning: true,
            title: "正在合并目标 (\(index + 1)/\(session.targets.count))",
            detail: "\(targetItem.sourceBranch) -> \(targetItem.targetBranch)",
            fractionCompleted: progressFraction,
            logs: localOperation.logs
        )
        appendLocalOperationLog("[\(index + 1)/\(session.targets.count)] 正在同步到: \(targetItem.targetBranch)...")

        let projectPath = session.projectPath
        let syncService = BranchSyncService()

        do {
            let result = try await Task.detached(priority: .userInitiated) { () -> GitMergeExecutionResult in
                try syncService.syncToMergeBranchInteractive(
                    projectPath: projectPath,
                    sourceBranch: targetItem.sourceBranch,
                    mergeBranch: targetItem.targetBranch
                )
            }.value

            switch result {
            case .success:
                session.targets[index].status = .success(message: "合并并推送成功")
                activeSyncSession = session
                appendLocalOperationLog("✅ [\(targetItem.targetBranch)] 合并推送成功")
                session.currentTargetIndex += 1
                activeSyncSession = session
                await processNextInteractiveTarget()

            case .alreadyUpToDate:
                session.targets[index].status = .success(message: "已是最新")
                activeSyncSession = session
                appendLocalOperationLog("✅ [\(targetItem.targetBranch)] 已是最新")
                session.currentTargetIndex += 1
                activeSyncSession = session
                await processNextInteractiveTarget()

            case .conflict(let files):
                // 发生冲突！挂起流水线并记录 MERGE_HEAD SHA 供后续识别外部提交/中止状态
                let mergeHeadSHA = try? GitCliService().activeMergeHeadSHA(projectPath: projectPath)
                session.activeConflictFiles = files
                session.conflictPhase = .awaitingResolution(markerFreeFiles: [])
                session.conflictMergeHeadSHA = mergeHeadSHA
                session.isAutoCommittingConflict = false
                activeSyncSession = session

                localOperation = OperationState(
                    isRunning: false,
                    title: "合并冲突等待解决 (\(index + 1)/\(session.targets.count))",
                    detail: "\(targetItem.sourceBranch) -> \(targetItem.targetBranch)",
                    fractionCompleted: progressFraction,
                    logs: localOperation.logs
                )
                appendLocalOperationLog("⚠️ [\(targetItem.targetBranch)] 检测到合并冲突！冲突文件: \(files.joined(separator: ", "))")

                // 唤起 Rebased 检查与引导，并启动后台防休眠冲突监视器
                startConflictResolutionMonitor()
                handleConflictEncountered(projectPath: projectPath)
            }
        } catch {
            session.targets[index].status = .failed(error: error.localizedDescription)
            activeSyncSession = session
            appendLocalOperationLog("❌ [\(targetItem.targetBranch)] 执行失败: \(error.localizedDescription)")
            session.currentTargetIndex += 1
            activeSyncSession = session
            await processNextInteractiveTarget()
        }
    }

    /// 发生冲突时唤起 Rebased 或引导安装
    func handleConflictEncountered(projectPath: String) {
        if RebasedService.shared.isInstalled {
            do {
                try RebasedService.shared.openProject(path: projectPath)
                appendLocalOperationLog("已在 Rebased 中调起冲突解决工程: \(projectPath)")
            } catch {
                appendLocalOperationLog("调起 Rebased 失败: \(error.localizedDescription)")
            }
        } else {
            showingRebasedInstallSheet = true
            appendLocalOperationLog("未检测到 Rebased，弹出安装引导弹窗")
        }
    }

    /// 用户或自动轮询完成冲突解决并提交推送
    func resolveAndContinueCurrentTarget(triggeredAutomatically: Bool = false) async {
        guard var session = activeSyncSession,
              !session.isAutoCommittingConflict,
              let currentTarget = session.currentTarget else { return }

        let projectPath = session.projectPath
        let sourceRef = session.conflictMergeHeadSHA ?? currentTarget.sourceBranch
        let shouldStageMarkerFree = !triggeredAutomatically && session.allConflictFilesMarkerFree
        let syncService = BranchSyncService()

        session.isAutoCommittingConflict = true
        activeSyncSession = session
        stopConflictResolutionMonitor()

        localOperation = OperationState(
            isRunning: true,
            title: triggeredAutomatically ? "正在自动完成合并提交与推送" : "正在提交已解决的冲突",
            detail: currentTarget.targetBranch,
            fractionCompleted: localOperation.fractionCompleted,
            logs: localOperation.logs
        )

        do {
            let resultMessage = try await Task.detached(priority: .userInitiated) {
                try syncService.finalizeResolvedMergeAndPush(
                    projectPath: projectPath,
                    sourceRef: sourceRef,
                    mergeBranch: currentTarget.targetBranch,
                    stageFilesIfAllMarkerFree: shouldStageMarkerFree
                )
            }.value

            guard var updatedSession = activeSyncSession else { return }
            let index = updatedSession.currentTargetIndex
            updatedSession.targets[index].status = .success(message: resultMessage)
            updatedSession.activeConflictFiles = []
            updatedSession.conflictPhase = .none
            updatedSession.conflictMergeHeadSHA = nil
            updatedSession.isAutoCommittingConflict = false
            updatedSession.currentTargetIndex += 1
            activeSyncSession = updatedSession

            appendLocalOperationLog("✅ [\(currentTarget.targetBranch)] \(resultMessage)")
            await processNextInteractiveTarget()
        } catch {
            if var updatedSession = activeSyncSession {
                updatedSession.isAutoCommittingConflict = false
                if triggeredAutomatically {
                    // 自动提交/推送失败时关闭本次自动触发，避免定时器高频循环重试
                    updatedSession.autoCommitWhenResolved = false
                }
                activeSyncSession = updatedSession
            }
            appendLocalOperationLog("提交冲突解决失败: \(error.localizedDescription)")
            localOperation = OperationState(
                isRunning: false,
                title: "提交失败",
                detail: error.localizedDescription,
                logs: localOperation.logs,
                errorMessage: error.localizedDescription
            )
            await pollConflictResolutionState()
            startConflictResolutionMonitor()
        }
    }

    /// 检测到合并已在外部（Rebased）中止后，重新执行当前目标合并
    func retryCurrentTargetMerge() async {
        guard activeSyncSession != nil else { return }
        await processNextInteractiveTarget()
    }

    /// 切换「冲突解决并暂存后自动完成 Merge Commit 并推送」开关
    func setAutoCommitWhenResolved(_ enabled: Bool) {
        guard var session = activeSyncSession else { return }
        session.autoCommitWhenResolved = enabled
        activeSyncSession = session
        if enabled {
            refreshActiveConflictFiles()
        }
    }

    /// 用户点击「跳过当前分支，继续下一个」
    func skipCurrentTargetAndContinue() async {
        guard var session = activeSyncSession, let currentTarget = session.currentTarget else { return }
        let projectPath = session.projectPath
        let syncService = BranchSyncService()

        appendLocalOperationLog("⏩ [\(currentTarget.targetBranch)] 用户选择跳过该目标分支，正在中止本次合并...")
        stopConflictResolutionMonitor()
        try? syncService.abortMerge(projectPath: projectPath)

        let index = session.currentTargetIndex
        session.targets[index].status = .skippedDueToConflict(files: session.activeConflictFiles)
        session.activeConflictFiles = []
        session.conflictPhase = .none
        session.conflictMergeHeadSHA = nil
        session.isAutoCommittingConflict = false
        session.currentTargetIndex += 1
        activeSyncSession = session

        await processNextInteractiveTarget()
    }

    /// 用户点击「全部中止 (Abort All)」
    func abortAllSyncSession() async {
        guard let session = activeSyncSession else { return }
        let projectPath = session.projectPath
        let syncService = BranchSyncService()

        appendLocalOperationLog("🛑 用户选择全部中止流水线，正在回退现场...")
        stopConflictResolutionMonitor()
        try? syncService.abortMerge(projectPath: projectPath)
        try? GitCliService().checkoutBranch(projectPath: projectPath, branch: session.initialBranch)

        activeSyncSession = nil
        localOperation = OperationState(
            isRunning: false,
            title: "已全部中止",
            detail: "已安全回退到分支 \(session.initialBranch)",
            logs: localOperation.logs,
            errorMessage: "流水线已被用户中止"
        )
    }

    /// 流水线全部处理完成，若配置了主干分支则自动切回主干分支；未配置则保持当前分支
    private func finishInteractiveSyncPipeline() async {
        stopConflictResolutionMonitor()
        guard let session = activeSyncSession else { return }
        let projectPath = session.projectPath
        let mainlineBranches = activeWorkspace?.configuredMainlineBranches
            ?? localMergeContext?.config.mainlineBranches
            ?? []

        let restoreResult = await Task.detached(priority: .userInitiated) {
            BranchSyncService().restoreMainlineBranchIfConfigured(
                projectPath: projectPath,
                mainlineBranches: mainlineBranches
            )
        }.value

        switch restoreResult {
        case .notConfigured:
            appendLocalOperationLog("ℹ️ \(restoreResult.logLine)")
        case .alreadyOnMainline, .switched:
            appendLocalOperationLog("✅ \(restoreResult.logLine)")
        case .branchNotFound, .failed:
            appendLocalOperationLog("⚠️ \(restoreResult.logLine)")
        }

        await refreshSingleLocalMergeProjectBranchState(projectPath: projectPath)

        let total = session.targets.count
        let succ = session.successfulCount
        let skipped = session.skippedCount
        let failed = session.failedCount

        var summary = "共 \(total) 个目标: 成功 \(succ)"
        if skipped > 0 { summary += ", 跳过 \(skipped)" }
        if failed > 0 { summary += ", 失败 \(failed)" }

        appendLocalOperationLog("🎉 流水线执行完毕！\(summary)")

        localOperation = OperationState(
            isRunning: false,
            title: "多分支合并完成",
            detail: summary,
            fractionCompleted: 1,
            logs: localOperation.logs,
            successMessage: summary
        )
        activeSyncSession = nil
    }

    private func refreshSingleLocalMergeProjectBranchState(projectPath: String) async {
        let updated = await Task.detached(priority: .userInitiated) { () -> (String, [String], [String])? in
            let cli = GitCliService()
            guard let current = try? cli.currentLocalBranch(projectPath: projectPath) else { return nil }
            let locals = (try? cli.localBranches(projectPath: projectPath)) ?? []
            let remotes = (try? cli.remoteBranches(projectPath: projectPath)) ?? []
            return (current, locals, remotes)
        }.value

        guard let (current, locals, remotes) = updated else { return }
        if let idx = localMergeProjects.firstIndex(where: { $0.path == projectPath }) {
            let old = localMergeProjects[idx]
            localMergeProjects[idx] = MergeProject(
                id: old.id,
                name: old.name,
                displayName: old.displayName,
                path: old.path,
                sourceRoot: old.sourceRoot,
                currentBranch: current,
                gitLabProjectID: old.gitLabProjectID,
                githubRepoSlug: old.githubRepoSlug,
                branchMappings: old.branchMappings,
                remoteBranches: remotes.isEmpty ? old.remoteBranches : remotes,
                localBranches: locals.isEmpty ? old.localBranches : locals,
                remoteURL: old.remoteURL,
                platform: old.platform
            )
        }
    }

    /// 刷新当前冲突文件及合并现场状态（可由后台监视器或用户点击触发）
    func refreshActiveConflictFiles() {
        Task { @MainActor in
            await pollConflictResolutionState()
        }
    }

    /// 启动后台冲突解决监视器（持有防 App Nap 活动凭证，不依赖前端视图是否显示，切到 Rebased 期间也能毫秒级响应）
    func startConflictResolutionMonitor() {
        stopConflictResolutionMonitor()
        conflictMonitorActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Waiting for conflict resolution in Rebased to auto-complete merge commit"
        )
        conflictMonitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled, let self else { break }
                guard let session = self.activeSyncSession, session.isPausedForConflict else {
                    self.stopConflictResolutionMonitor()
                    break
                }
                await self.pollConflictResolutionState()
            }
        }
    }

    func stopConflictResolutionMonitor() {
        conflictMonitorTask?.cancel()
        conflictMonitorTask = nil
        if let activity = conflictMonitorActivity {
            ProcessInfo.processInfo.endActivity(activity)
            conflictMonitorActivity = nil
        }
    }

    /// 异步探测 Git 合并现场，并在冲突全部解决并暂存后自动完成 Merge Commit + Push + 推进下一分支
    func pollConflictResolutionState() async {
        guard let session = activeSyncSession,
              session.isPausedForConflict,
              !session.isAutoCommittingConflict,
              !isInspectingConflictFiles,
              let currentTarget = session.currentTarget else { return }

        isInspectingConflictFiles = true
        defer { isInspectingConflictFiles = false }

        let projectPath = session.projectPath
        let targetIndex = session.currentTargetIndex
        let sourceRef = session.conflictMergeHeadSHA ?? currentTarget.sourceBranch

        let inspection: GitMergeStateInspection? = await Task.detached(priority: .utility) {
            try? GitCliService().inspectMergeState(projectPath: projectPath, sourceRef: sourceRef)
        }.value

        guard let inspection,
              var latestSession = activeSyncSession,
              latestSession.projectPath == projectPath,
              latestSession.currentTargetIndex == targetIndex,
              latestSession.isPausedForConflict,
              !latestSession.isAutoCommittingConflict else { return }

        switch inspection {
        case .mergingWithUnresolvedFiles(let files, let markerFree):
            latestSession.activeConflictFiles = files
            latestSession.conflictPhase = .awaitingResolution(markerFreeFiles: markerFree)
            activeSyncSession = latestSession

        case .mergingReadyToCommit:
            let previousPhase = latestSession.conflictPhase
            latestSession.activeConflictFiles = []
            latestSession.conflictPhase = .readyToCommit
            activeSyncSession = latestSession

            if previousPhase != .readyToCommit {
                appendLocalOperationLog("🟢 [\(currentTarget.targetBranch)] 检测到冲突已全部解决并暂存")
            }
            if latestSession.autoCommitWhenResolved {
                appendLocalOperationLog("🚀 [\(currentTarget.targetBranch)] 正在自动完成 Merge Commit 并推送...")
                await resolveAndContinueCurrentTarget(triggeredAutomatically: true)
            }

        case .committedExternally:
            let previousPhase = latestSession.conflictPhase
            latestSession.activeConflictFiles = []
            latestSession.conflictPhase = .committedExternally
            activeSyncSession = latestSession

            if previousPhase != .committedExternally {
                appendLocalOperationLog("🟢 [\(currentTarget.targetBranch)] 检测到合并已在外部提交")
            }
            if latestSession.autoCommitWhenResolved {
                await resolveAndContinueCurrentTarget(triggeredAutomatically: true)
            }

        case .abortedExternally:
            let previousPhase = latestSession.conflictPhase
            latestSession.activeConflictFiles = []
            latestSession.conflictPhase = .abortedExternally
            activeSyncSession = latestSession

            if previousPhase != .abortedExternally {
                appendLocalOperationLog("⚠️ [\(currentTarget.targetBranch)] 检测到合并已在外部（Rebased）中止，请选择重新合并、跳过或全部中止。")
            }
        }
    }

    /// 一键安装 Rebased
    func installRebased() async {
        isInstallingRebased = true
        rebasedInstallLog = "正在准备通过 Homebrew 安装 Rebased..."
        do {
            try await RebasedService.shared.installViaBrew { [weak self] line in
                Task { @MainActor in
                    self?.rebasedInstallLog = line
                }
            }
            isInstallingRebased = false
            showingRebasedInstallSheet = false

            // 安装完毕后，如果当前正好有冲突未解，自动调起打开
            if let session = activeSyncSession, session.hasActiveConflict {
                try? RebasedService.shared.openProject(path: session.projectPath)
            }
        } catch {
            isInstallingRebased = false
            rebasedInstallLog = "安装失败: \(error.localizedDescription)"
        }
    }

    func prepareCreateMergeRequest() {
        if let project = currentMergeProject, project.platform == .github {
            let preferredTarget = mergeRequestContext?.config.githubDefaultTargetBranch ?? "main"
            let defaultTargetBranch = availableMRTargetBranches.contains(preferredTarget)
                ? preferredTarget
                : (availableMRTargetBranches.first(where: { $0 == "main" || $0 == "master" })
                    ?? availableMRTargetBranches.first
                    ?? preferredTarget)
            let defaultSourceBranch = availableMRSourceBranches.first(where: { $0 == project.currentBranch && $0 != defaultTargetBranch })
                ?? availableMRSourceBranches.first(where: { $0 != defaultTargetBranch })
                ?? availableMRSourceBranches.first
                ?? project.currentBranch

            createMRDraft.sourceBranch = defaultSourceBranch
            createMRDraft.targetBranch = defaultTargetBranch
            showingCreateMRSheet = true
            return
        }

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
            if !saved.activeWorkspaceID.isEmpty {
                activeWorkspaceID = saved.activeWorkspaceID
            } else if let first = saved.workspaces.first {
                activeWorkspaceID = first.id
            }
            let currentWS = saved.currentWorkspace
            if let wsPlatform = currentWS?.platform {
                selectedPlatformFilter = wsPlatform
            }
            worktreeConfig = saved.asWorktreeConfig(for: currentWS)
            GitLabHostStore.shared.update(currentWS?.platform == .gitlab ? currentWS?.host : saved.gitlabHost)
            GitCredentialStore.shared.update(
                gitlabToken: currentWS?.platform == .gitlab ? (currentWS?.token ?? saved.gitlabToken) : saved.gitlabToken,
                githubToken: currentWS?.platform == .github ? (currentWS?.token ?? saved.githubToken) : saved.githubToken
            )
            settingsDraft = SettingsDraft(config: saved)
            settingsTokenVisible = false
            settingsOperation = OperationState(
                isRunning: false,
                title: "设置已保存",
                detail: "已更新 GWorkbench 配置并刷新数据",
                fractionCompleted: 1,
                successMessage: "保存成功"
            )
            ProjectScanCache.shared.invalidate()
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
            if !config.activeWorkspaceID.isEmpty {
                activeWorkspaceID = config.activeWorkspaceID
            } else if let first = config.workspaces.first {
                activeWorkspaceID = first.id
            }
            let currentWS = config.currentWorkspace
            if let wsPlatform = currentWS?.platform {
                selectedPlatformFilter = wsPlatform
            }
            worktreeConfig = config.asWorktreeConfig(for: currentWS)
            GitLabHostStore.shared.update(currentWS?.platform == .gitlab ? currentWS?.host : config.gitlabHost)
            GitCredentialStore.shared.update(
                gitlabToken: currentWS?.platform == .gitlab ? (currentWS?.token ?? config.gitlabToken) : config.gitlabToken,
                githubToken: currentWS?.platform == .github ? (currentWS?.token ?? config.githubToken) : config.githubToken
            )
            settingsDraft = SettingsDraft(config: config)
            settingsTokenVisible = false
            settingsOperation = OperationState(
                isRunning: false,
                title: "设置已重新加载",
                detail: "已从配置文件读取最新内容",
                fractionCompleted: 1,
                successMessage: "重新加载完成"
            )
            ProjectScanCache.shared.invalidate()
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
        if let wsRoot = activeWorkspace?.worktreesRootDir.trimmedNonEmpty {
            basePath = wsRoot
        } else if let wtPath = worktreeConfig?.worktreesRootDir, !wtPath.isEmpty {
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

    /// 为工作树解析终端 Tab 标题：有自定义描述用描述，主仓库或无描述用仓库名称
    func resolvedWorktreeTabTitle(_ item: WorktreeItem) -> String {
        let trimmed = item.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != "主仓库" && trimmed != "未填写功能描述" {
            return sanitizeTerminalTabTitle(trimmed)
        }
        if !item.projectName.isEmpty {
            return sanitizeTerminalTabTitle(item.projectName)
        }
        let lastComp = URL(fileURLWithPath: item.path).lastPathComponent
        return sanitizeTerminalTabTitle(!lastComp.isEmpty ? lastComp : item.branch)
    }

    /// 为合并项目解析终端 Tab 标题：使用仓库名称
    func resolvedProjectTabTitle(_ project: MergeProject) -> String {
        if !project.displayName.isEmpty {
            return sanitizeTerminalTabTitle(project.displayName)
        }
        if !project.name.isEmpty {
            return sanitizeTerminalTabTitle(project.name)
        }
        let lastComp = URL(fileURLWithPath: project.path).lastPathComponent
        return sanitizeTerminalTabTitle(lastComp)
    }

    private func sanitizeTerminalTabTitle(_ raw: String) -> String {
        let singleLine = raw.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if singleLine.count > 40 {
            return String(singleLine.prefix(40)) + "..."
        }
        return singleLine
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

        let workspaceProfiles = settingsDraft.workspaces.map { $0.toWorkspaceProfile() }
        for wsDraft in settingsDraft.workspaces {
            _ = try parseBranchMappings(wsDraft.branchMappings)
        }
        let workspaceRoots = Array(Set(workspaceProfiles.flatMap(\.projectsRootDirs))).sorted()
        let draftWorktreeRoots = settingsDraft.worktreeProjectsRootDirs
            .map(\.path)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let draftMergeRoots = settingsDraft.mergeRootDirs
            .map(\.path)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let worktreeRoots = workspaceRoots.isEmpty ? draftWorktreeRoots : workspaceRoots
        let mergeRoots = workspaceRoots.isEmpty ? (draftMergeRoots.isEmpty ? worktreeRoots : draftMergeRoots) : workspaceRoots

        let envBranches = parseList(settingsDraft.envBranchesText)
        let protectedTargets = parseList(settingsDraft.protectedTargetsText)
        let githubBaselines = parseList(settingsDraft.githubDashboardBaselinesText)
        let gitlabBaselines = parseList(settingsDraft.gitlabDashboardBaselinesText)
        let globalBranchMap = try parseBranchMappings(settingsDraft.branchMappings)

        guard !worktreeRoots.isEmpty else {
            throw WorkbenchError.message("至少需要为一个工作区标签绑定一个代码仓库目录")
        }

        let resolvedActiveWorkspaceID = settingsDraft.activeWorkspaceID.trimmedNonEmpty
            ?? (activeWorkspaceID.trimmedNonEmpty)
            ?? workspaceProfiles.first?.id
            ?? ""
        let resolvedActiveWS = workspaceProfiles.first(where: { $0.id == resolvedActiveWorkspaceID }) ?? workspaceProfiles.first
        let firstGitLab = workspaceProfiles.first(where: { $0.platform == .gitlab })
        let firstGitHub = workspaceProfiles.first(where: { $0.platform == .github })
        let fallbackGitLabLike = (resolvedActiveWS?.platform == .gitlab ? resolvedActiveWS : nil) ?? firstGitLab ?? resolvedActiveWS
        let effectiveEnvs = !(fallbackGitLabLike?.envBranches.isEmpty ?? true)
            ? (fallbackGitLabLike?.envBranches ?? [])
            : (envBranches.isEmpty ? ["dev", "test", "stage", "uat"] : envBranches)
        let effectiveMiddle = fallbackGitLabLike?.mergeBranchMiddle.trimmedNonEmpty
            ?? settingsDraft.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveBranchMap = !(fallbackGitLabLike?.branchMap.isEmpty ?? true)
            ? (fallbackGitLabLike?.branchMap ?? [:])
            : globalBranchMap

        var builtIDEProfiles = settingsDraft.ideProfiles
            .map { $0.toIDEProfile() }
            .filter { !$0.command.isEmpty || $0.mode == "system" }
        if builtIDEProfiles.isEmpty {
            builtIDEProfiles = [
                IDEProfile(
                    id: "default-ide",
                    label: settingsDraft.ideLabel.trimmedNonEmpty ?? "默认应用",
                    mode: settingsDraft.ideMode.trimmedNonEmpty ?? "app",
                    command: settingsDraft.ideCommand.trimmedNonEmpty ?? "open"
                )
            ]
        }
        let primaryIDE = builtIDEProfiles.first(where: { $0.id == settingsDraft.defaultIDEProfileID }) ?? builtIDEProfiles[0]

        return GWorkbenchConfig(
            configPath: settingsDraft.configPath,
            metadataPath: settingsDraft.metadataPath,
            worktreeProjectsRootDirs: worktreeRoots,
            worktreesRootDir: settingsDraft.worktreesRootDir.trimmingCharacters(in: .whitespacesAndNewlines),
            worktreePathTemplate: settingsDraft.worktreePathTemplate.trimmingCharacters(in: .whitespacesAndNewlines),
            ideMode: primaryIDE.mode,
            ideCommand: primaryIDE.command,
            ideLabel: primaryIDE.effectiveLabel,
            ideProfiles: builtIDEProfiles,
            defaultIDEProfileID: primaryIDE.id,
            terminalApp: settingsDraft.terminalApp.trimmingCharacters(in: .whitespacesAndNewlines),
            terminalBundleID: settingsDraft.terminalBundleID.trimmingCharacters(in: .whitespacesAndNewlines),
            terminalLaunchHookMode: settingsDraft.terminalLaunchHookMode.trimmingCharacters(in: .whitespacesAndNewlines),
            terminalLaunchCommand: settingsDraft.terminalLaunchCommand.trimmingCharacters(in: .whitespacesAndNewlines),
            terminalSetTabTitle: settingsDraft.terminalSetTabTitle,
            gitlabHost: (firstGitLab?.host ?? settingsDraft.gitlabHost).trimmingCharacters(in: .whitespacesAndNewlines),
            gitlabToken: (firstGitLab?.token ?? settingsDraft.gitlabToken).trimmingCharacters(in: .whitespacesAndNewlines),
            githubHost: (firstGitHub?.host ?? settingsDraft.githubHost).trimmingCharacters(in: .whitespacesAndNewlines),
            githubToken: (firstGitHub?.token ?? settingsDraft.githubToken).trimmingCharacters(in: .whitespacesAndNewlines),
            aiProvider: settingsDraft.aiProvider.trimmingCharacters(in: .whitespacesAndNewlines),
            aiBaseURL: settingsDraft.aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            aiAPIKey: settingsDraft.aiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
            aiModel: settingsDraft.aiModel.trimmingCharacters(in: .whitespacesAndNewlines),
            aiCustomPrompt: settingsDraft.aiCustomPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            activeWorkflowPreset: settingsDraft.activeWorkflowPreset.trimmingCharacters(in: .whitespacesAndNewlines),
            activePlatform: resolvedActiveWS?.platform.rawValue ?? activePlatform.rawValue,
            activeWorkspaceID: resolvedActiveWorkspaceID,
            workspaces: workspaceProfiles,
            githubDefaultTargetBranch: firstGitHub?.defaultTargetBranch ?? settingsDraft.githubDefaultTargetBranch.trimmingCharacters(in: .whitespacesAndNewlines),
            githubDashboardBaselines: firstGitHub?.effectiveDashboardBaselines ?? (githubBaselines.isEmpty ? DefaultDashboardBaselines.github : githubBaselines),
            gitlabDashboardBaselines: firstGitLab?.effectiveDashboardBaselines ?? (gitlabBaselines.isEmpty ? DefaultDashboardBaselines.gitlab : gitlabBaselines),
            mergeRootDirs: mergeRoots,
            mergeBranchMiddle: effectiveMiddle,
            envBranches: effectiveEnvs,
            branchMap: effectiveBranchMap,
            protectedTargets: protectedTargets,
            autoMergeDelaySeconds: delay,
            autoMergeRetryCount: retry,
            syncIDEConfigs: settingsDraft.syncIDEConfigs,
            ideConfigSyncItems: parseList(settingsDraft.ideConfigSyncItemsText)
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

    var activeWorkspaceDraftIndex: Int? {
        let targetID = activeWorkspace?.id ?? settingsDraft.activeWorkspaceID
        return settingsDraft.workspaces.firstIndex(where: { $0.id == targetID })
            ?? (settingsDraft.workspaces.isEmpty ? nil : 0)
    }

    var currentDraftTargetBranchOptions: [String] {
        let protectedTargets = parseList(settingsDraft.protectedTargetsText)
        var list: [String] = []
        if let idx = activeWorkspaceDraftIndex {
            let ws = settingsDraft.workspaces[idx]
            for e in ws.protectedEnvBranchList where !list.contains(e) {
                list.append(e)
            }
            for m in ws.mainlineBranchList where !list.contains(m) {
                list.append(m)
            }
        } else {
            for e in parseList(settingsDraft.envBranchesText) where !list.contains(e) {
                list.append(e)
            }
        }
        for p in protectedTargets where !list.contains(p) {
            list.append(p)
        }
        return list.isEmpty ? ["uat", "test", "stage", "pre_prod", "master"] : list
    }

    func regenerateBranchMappingsFromEnvironment() {
        let globalProtected = parseList(settingsDraft.protectedTargetsText)

        if let idx = activeWorkspaceDraftIndex {
            let ws = settingsDraft.workspaces[idx]
            let envs = ws.protectedEnvBranchList
            let mainlines = ws.mainlineBranchList.isEmpty ? globalProtected : ws.mainlineBranchList
            let middle = ws.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "sync"
                : ws.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !envs.isEmpty else {
                settingsOperation = OperationState(
                    isRunning: false,
                    title: "无法生成分支映射",
                    detail: "请先在「当前标签「\(ws.name)」→ 分支架构与流转规则」中添加保护分支（非生产环境）",
                    errorMessage: "保护分支列表为空"
                )
                return
            }

            let newMappings = ws.buildRecommendedBranchMappings(extraProtectedTargets: globalProtected)
            settingsDraft.workspaces[idx].branchMappings = newMappings
            settingsDraft.branchMappings = newMappings

            let mainlineDisplay = mainlines.first ?? "未设置"
            settingsOperation = OperationState(
                isRunning: false,
                title: "映射已同步",
                detail: "已读取标签「\(ws.name)」分支架构（保护分支: \(envs.joined(separator: ", ")) · 后缀: \(middle) · 主干: \(mainlineDisplay)）生成 \(newMappings.count) 条映射",
                successMessage: "已同步 \(newMappings.count) 条映射"
            )
            return
        }

        let middle = settingsDraft.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "sync"
            : settingsDraft.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines)
        let envs = parseList(settingsDraft.envBranchesText)

        guard !envs.isEmpty else {
            settingsOperation = OperationState(
                isRunning: false,
                title: "无法生成分支映射",
                detail: "尚未配置非生产保护分支列表",
                errorMessage: "保护分支列表为空"
            )
            return
        }

        let newMappings = WorkspaceProfileDraft.buildBranchMappings(
            envs: envs,
            mainlines: globalProtected,
            middle: middle
        )
        settingsDraft.branchMappings = newMappings
        settingsOperation = OperationState(
            isRunning: false,
            title: "映射已同步",
            detail: "已根据环境分支列表生成 \(newMappings.count) 条映射",
            successMessage: "已同步 \(newMappings.count) 条映射"
        )
    }

    func addBranchMapping(target: String? = nil) {
        let defaultTarget = target ?? currentDraftTargetBranchOptions.first ?? "dev"
        if let idx = activeWorkspaceDraftIndex {
            let middle = settingsDraft.workspaces[idx].mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "sync"
                : settingsDraft.workspaces[idx].mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines)
            let defaultSource = "\(defaultTarget)_\(middle)"
            settingsDraft.workspaces[idx].branchMappings.append(BranchMappingDraft(source: defaultSource, target: defaultTarget))
            settingsDraft.branchMappings = settingsDraft.workspaces[idx].branchMappings
            return
        }

        let middle = settingsDraft.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "sync"
            : settingsDraft.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultSource = "\(defaultTarget)_\(middle)"
        settingsDraft.branchMappings.append(BranchMappingDraft(source: defaultSource, target: defaultTarget))
    }

    func removeBranchMapping(id: UUID) {
        if let idx = activeWorkspaceDraftIndex {
            settingsDraft.workspaces[idx].branchMappings.removeAll { $0.id == id }
            settingsDraft.branchMappings = settingsDraft.workspaces[idx].branchMappings
            return
        }
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
