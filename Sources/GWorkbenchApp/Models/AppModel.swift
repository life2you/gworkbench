import Foundation

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

enum WorktreeKind: String, Hashable {
    case mainRepo = "主仓库"
    case worktree = "工作树"
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
    case mergeSingle = "合并到单个目标"
    case mergeCustom = "自定义目标"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .syncEnvironments:
            return "依次更新环境分支，再同步到对应合并分支并推送。"
        case .mergeAll:
            return "选择一个源分支，批量合并到全部目标合并分支。"
        case .mergeSingle:
            return "选择一个源分支，只合并到一个目标分支。"
        case .mergeCustom:
            return "手动勾选多个目标分支，适合灰度或局部回合并。"
        }
    }

    var requiresSourceBranch: Bool {
        self != .syncEnvironments
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
    var selectedWorktreeID: String?
    var selectedMergeRequestID: String?
    var selectedMergeFilter: MergeRequestFilter = .open

    var worktreeSearchText = ""
    var localBranchSearchText = ""
    var mergeRequestSearchText = ""

    var showingCreateWorktreeSheet = false
    var showingCreateMRSheet = false
    var showingBatchCreateMRSheet = false
    var createWorktreeDraft = CreateWorktreeDraft()
    var createMRDraft = CreateMRDraft()
    var selectedBatchMRMappingIDs = Set<String>()
    var worktreeDescriptionDraft = ""
    var worktreeDescriptionLoadedForID: String?
    var localOperationMode: LocalBranchOperationMode = .syncEnvironments
    var localOperationSourceBranch = ""
    var localOperationSingleTarget = ""
    var localOperationCustomTargets = Set<String>()

    var deleteLocalBranchOnRemove = false
    var deleteRemoteBranchOnRemove = false

    var worktreeOperation = OperationState.idle(title: "工作树状态")
    var localOperation = OperationState.idle(title: "分支同步状态")
    var mrOperation = OperationState.idle(title: "MR 状态")
    var settingsOperation = OperationState.idle(title: "设置状态")

    var appConfig: GWorkbenchConfig?
    var gwtmConfig: GwtmConfig?
    var localMergeContext: LocalMergeContext?
    var gmuxContext: GmuxContext?
    var settingsDraft = SettingsDraft()
    var settingsTokenVisible = false
    var globalErrorMessage: String?

    private var didBootstrap = false

    var selectedWorktree: WorktreeItem? {
        filteredWorktrees.first(where: { $0.id == selectedWorktreeID })
            ?? worktrees.first(where: { $0.id == selectedWorktreeID })
    }

    var selectedMergeRequest: MergeRequestItem? {
        filteredMergeRequests.first(where: { $0.id == selectedMergeRequestID })
            ?? mergeRequests.first(where: { $0.id == selectedMergeRequestID })
    }

    var currentWorktreeProject: LocalProject? {
        worktreeProjects.first(where: { $0.id == selectedProjectID }) ?? worktreeProjects.first
    }

    var currentLocalMergeProject: MergeProject? {
        localMergeProjects.first(where: { $0.id == selectedLocalProjectID }) ?? localMergeProjects.first
    }

    var currentMergeProject: MergeProject? {
        mergeProjects.first(where: { $0.id == selectedMergeProjectID }) ?? mergeProjects.first
    }

    var worktreeCountByProject: [String: Int] {
        Dictionary(grouping: worktrees, by: \.project).mapValues(\.count)
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
            item.projectPath == currentProject.path &&
            (worktreeSearchText.isEmpty ||
             item.branch.localizedCaseInsensitiveContains(worktreeSearchText) ||
             item.summary.localizedCaseInsensitiveContains(worktreeSearchText))
        }
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

    var availableBatchMRMappings: [BranchMapping] {
        availableMRMappings.filter { !$0.protectedTarget }
    }

    var selectedBatchMRMappings: [BranchMapping] {
        availableBatchMRMappings.filter { selectedBatchMRMappingIDs.contains($0.id) }
    }

    var canCreateSelectedBatchMRs: Bool {
        !mrOperation.isRunning && !selectedBatchMRMappings.isEmpty
    }

    var canBatchApproveAndMergeVisibleMRs: Bool {
        !mrOperation.isRunning && !visibleOpenMergeRequests.isEmpty
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
        case .syncEnvironments:
            return localTargetOptions.map(\.targetBranch)
        case .mergeAll:
            return localTargetOptions.map(\.targetBranch)
        case .mergeSingle:
            return localOperationSingleTarget.nonEmptyArray
        case .mergeCustom:
            return localTargetOptions
                .map(\.targetBranch)
                .filter { localOperationCustomTargets.contains($0) }
        }
    }

    var localOperationPreviewLines: [String] {
        guard let project = currentLocalMergeProject else {
            return ["当前还没有可执行的 gmux 本地项目。"]
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
        case .mergeAll, .mergeSingle, .mergeCustom:
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
        case .mergeSingle:
            return localOperationSourceBranch.nonEmpty != nil && localOperationSingleTarget.nonEmpty != nil
        case .mergeCustom:
            return localOperationSourceBranch.nonEmpty != nil && !resolvedLocalOperationTargets.isEmpty
        }
    }

    func bootstrap() async {
        guard !didBootstrap else {
            return
        }
        didBootstrap = true
        await refreshSettings()
        await refreshWorktrees()
        await refreshLocalMergeProjects()
        await refreshMergeProjects()
    }

    func refreshSettings() async {
        settingsOperation = OperationState(isRunning: true, title: "读取设置", detail: "正在加载 GWorkbench 配置")
        do {
            let config = try await service.loadWorkbenchConfig()
            appConfig = config
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
        worktreeOperation = OperationState(isRunning: true, title: "刷新工作树", detail: "开始读取本地配置")
        globalErrorMessage = nil

        do {
            let snapshot = try await service.loadWorktreeSnapshot { [weak self] progress in
                Task { @MainActor in
                    self?.worktreeOperation = OperationState(
                        isRunning: true,
                        title: progress.title,
                        detail: progress.detail,
                        fractionCompleted: progress.fractionCompleted
                    )
                }
            }

            gwtmConfig = snapshot.config
            worktreeProjects = snapshot.projects
            worktrees = snapshot.worktrees

            if selectedProjectID == nil || !worktreeProjects.contains(where: { $0.id == selectedProjectID }) {
                selectedProjectID = worktreeProjects.first?.id
            }

            if selectedWorktreeID == nil || !filteredWorktrees.contains(where: { $0.id == selectedWorktreeID }) {
                selectedWorktreeID = filteredWorktrees.first?.id
            }

            syncSelectedWorktreeDescriptionDraft()
            syncCreateWorktreeDefaults(resetBranchName: false)

            worktreeOperation = OperationState(
                isRunning: false,
                title: "工作树已刷新",
                detail: "已同步 \(snapshot.projects.count) 个项目和 \(snapshot.worktrees.count) 个工作树",
                fractionCompleted: 1,
                successMessage: "刷新完成"
            )
        } catch {
            worktreeOperation = OperationState(
                isRunning: false,
                title: "工作树刷新失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
            globalErrorMessage = error.localizedDescription
        }
    }

    func refreshLocalMergeProjects() async {
        localOperation = OperationState(isRunning: true, title: "刷新分支同步项目", detail: "开始读取 gmux 本地配置")
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
        mrOperation = OperationState(isRunning: true, title: "刷新 gmux 项目", detail: "开始读取配置")
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
            gmuxContext = context
            mergeProjects = context.projects

            if selectedMergeProjectID == nil || !mergeProjects.contains(where: { $0.id == selectedMergeProjectID }) {
                selectedMergeProjectID = mergeProjects.first?.id
            }

            await refreshMergeRequests()
        } catch {
            mrOperation = OperationState(
                isRunning: false,
                title: "gmux 项目刷新失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
            globalErrorMessage = error.localizedDescription
        }
    }

    func refreshMergeRequests() async {
        guard let context = gmuxContext, let project = currentMergeProject else {
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
        syncCreateWorktreeDefaults(resetBranchName: false)
    }

    func selectLocalProject(_ projectID: String) {
        selectedLocalProjectID = projectID
        syncLocalOperationDefaults(resetSourceBranch: false)
    }

    func selectMergeProject(_ projectID: String) {
        selectedMergeProjectID = projectID
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

    func createWorktree() async {
        guard let config = gwtmConfig, let project = currentWorktreeProject else {
            worktreeOperation = OperationState(
                isRunning: false,
                title: "无法创建工作树",
                detail: "尚未读取到 gwtm 项目配置",
                errorMessage: "尚未读取到 gwtm 项目配置"
            )
            return
        }

        worktreeOperation = OperationState(isRunning: true, title: "创建工作树", detail: "准备执行")

        do {
            let result = try await service.createWorktree(config: config, project: project, draft: createWorktreeDraft) { [weak self] progress in
                Task { @MainActor in
                    self?.worktreeOperation = OperationState(
                        isRunning: true,
                        title: progress.title,
                        detail: progress.detail,
                        fractionCompleted: progress.fractionCompleted
                    )
                }
            }

            if createWorktreeDraft.openInIDE {
                try service.openInIDE(config: config, path: result.path)
            }

            showingCreateWorktreeSheet = false
            await refreshWorktrees()
            selectedWorktreeID = worktrees.first(where: { $0.path == result.path })?.id
            worktreeOperation.successMessage = result.successMessage
            worktreeOperation.logs = result.logs
        } catch {
            worktreeOperation = OperationState(
                isRunning: false,
                title: "创建工作树失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func openSelectedWorktreeInIDE() {
        guard let config = gwtmConfig, let item = selectedWorktree else { return }
        do {
            try service.openInIDE(config: config, path: item.path)
            worktreeOperation = OperationState(
                isRunning: false,
                title: "已打开 IDE",
                detail: item.path,
                successMessage: "已使用 \(config.ideLabel) 打开"
            )
        } catch {
            worktreeOperation = OperationState(
                isRunning: false,
                title: "打开 IDE 失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func openSelectedWorktreeInTerminal() {
        guard let item = selectedWorktree else { return }
        do {
            try service.openInTerminal(path: item.path)
            worktreeOperation = OperationState(
                isRunning: false,
                title: "已打开终端",
                detail: item.path,
                successMessage: "已在 Terminal 中打开"
            )
        } catch {
            worktreeOperation = OperationState(
                isRunning: false,
                title: "打开终端失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func removeSelectedWorktree() async {
        guard let config = gwtmConfig, let item = selectedWorktree else { return }
        do {
            let branch = item.branch
            worktreeOperation = OperationState(isRunning: true, title: "删除工作树", detail: branch)
            try await service.removeWorktree(
                config: config,
                item: item,
                deleteLocalBranch: deleteLocalBranchOnRemove,
                deleteRemoteBranch: deleteRemoteBranchOnRemove
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.worktreeOperation = OperationState(
                        isRunning: true,
                        title: progress.title,
                        detail: progress.detail,
                        fractionCompleted: progress.fractionCompleted
                    )
                }
            }
            deleteLocalBranchOnRemove = false
            deleteRemoteBranchOnRemove = false
            await refreshWorktrees()
            worktreeOperation.successMessage = "已删除 \(branch)"
        } catch {
            worktreeOperation = OperationState(
                isRunning: false,
                title: "删除工作树失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func saveSelectedWorktreeDescription() async {
        guard let config = gwtmConfig, let item = selectedWorktree else { return }
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
                detail: "尚未读取到 gmux 本地项目配置",
                errorMessage: "尚未读取到 gmux 本地项目配置"
            )
            return
        }

        let sourceBranch = localOperationSourceBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        let targets = resolvedLocalOperationTargets
        localOperation = OperationState(
            isRunning: true,
            title: localOperationMode.rawValue,
            detail: project.displayName
        )

        do {
            let logs: [String]
            switch localOperationMode {
            case .syncEnvironments:
                logs = try await service.executeLocalSync(context: context, project: project) { [weak self] progress in
                    Task { @MainActor in
                        self?.localOperation = OperationState(
                            isRunning: true,
                            title: progress.title,
                            detail: progress.detail,
                            fractionCompleted: progress.fractionCompleted
                        )
                    }
                }
            case .mergeAll, .mergeSingle, .mergeCustom:
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
                        self?.localOperation = OperationState(
                            isRunning: true,
                            title: progress.title,
                            detail: progress.detail,
                            fractionCompleted: progress.fractionCompleted
                        )
                    }
                }
            }

            let successCount = logs.filter { !$0.hasPrefix("失败:") && !$0.hasPrefix("错误:") }.count
            localOperation = OperationState(
                isRunning: false,
                title: "\(localOperationMode.rawValue)完成",
                detail: "共返回 \(logs.count) 条执行结果",
                fractionCompleted: 1,
                logs: logs,
                successMessage: "已完成 \(successCount) 项处理"
            )
        } catch {
            localOperation = OperationState(
                isRunning: false,
                title: "\(localOperationMode.rawValue)失败",
                detail: error.localizedDescription,
                errorMessage: error.localizedDescription
            )
        }
    }

    func prepareCreateMergeRequest() {
        if let mapping = availableMRMappings.first {
            createMRDraft.sourceBranch = mapping.source
            createMRDraft.targetBranch = mapping.target
        }
        showingCreateMRSheet = true
    }

    func prepareBatchMergeRequests() {
        selectedBatchMRMappingIDs = Set(availableBatchMRMappings.map(\.id))
        showingBatchCreateMRSheet = true
    }

    func createMergeRequest() async {
        guard let context = gmuxContext, let project = currentMergeProject else { return }
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
        guard let context = gmuxContext, let project = currentMergeProject else { return }
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

    func approveAndMergeVisibleMRs() async {
        guard let context = gmuxContext else { return }
        let items = visibleOpenMergeRequests
        guard !items.isEmpty else {
            mrOperation = OperationState(
                isRunning: false,
                title: "没有可处理的 MR",
                detail: "当前筛选结果里没有可审批并合并的 MR",
                successMessage: "无需处理"
            )
            return
        }

        mrOperation = OperationState(
            isRunning: true,
            title: "一键审批并合并",
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
                title: "一键审批并合并完成",
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
        guard let context = gmuxContext, let item = selectedMergeRequest else { return }
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
        guard let context = gmuxContext, let item = selectedMergeRequest else { return }
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

    func importLegacyConfigs() async {
        settingsOperation = OperationState(isRunning: true, title: "导入旧配置", detail: "正在从 gwtm / gmux 导入")
        do {
            let config = try await service.importLegacyWorkbenchConfig()
            appConfig = config
            settingsDraft = SettingsDraft(config: config)
            settingsTokenVisible = false
            settingsOperation = OperationState(
                isRunning: false,
                title: "导入完成",
                detail: "已写入 GWorkbench 独立配置",
                fractionCompleted: 1,
                successMessage: "导入成功"
            )
            await refreshWorktrees()
            await refreshLocalMergeProjects()
            await refreshMergeProjects()
        } catch {
            settingsOperation = OperationState(
                isRunning: false,
                title: "导入失败",
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
            let config = try await service.reloadWorkbenchConfigWithoutImport()
            appConfig = config
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
        let basePath = gwtmConfig?.worktreesRootDir
            ?? appConfig?.worktreesRootDir
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("worktrees").path
        let safeBranch = branchName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        return URL(fileURLWithPath: basePath)
            .appendingPathComponent(projectName)
            .appendingPathComponent(safeBranch.isEmpty ? "new-worktree" : safeBranch)
            .path
    }

    private func mergeRequests(for filter: MergeRequestFilter) -> [MergeRequestItem] {
        switch filter {
        case .open:
            return mergeRequests.filter { [.open, .ready, .blocked, .draft].contains($0.status) }
        case .mine:
            guard let currentUsername = gmuxContext?.currentUsername else { return [] }
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
        let actualMiddle = middle == "PROJECT_NAME" ? projectName : middle
        return "\(envBranch)_\(actualMiddle)_meger"
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
            ideMode: settingsDraft.ideMode.trimmingCharacters(in: .whitespacesAndNewlines),
            ideCommand: settingsDraft.ideCommand.trimmingCharacters(in: .whitespacesAndNewlines),
            ideLabel: settingsDraft.ideLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            gitlabHost: settingsDraft.gitlabHost.trimmingCharacters(in: .whitespacesAndNewlines),
            gitlabToken: settingsDraft.gitlabToken.trimmingCharacters(in: .whitespacesAndNewlines),
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

    func addBranchMapping() {
        settingsDraft.branchMappings.append(BranchMappingDraft())
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
