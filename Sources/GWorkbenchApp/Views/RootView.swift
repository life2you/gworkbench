import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var appModel = appModel

        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } detail: {
            mainWorkspaceColumn
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $appModel.showingRebasedInstallSheet) {
            RebasedInstallSheetView()
        }
        .sheet(isPresented: $appModel.showingSettingsSheet) {
            SettingsModalSheetView()
        }
        .sheet(isPresented: Binding(
            get: { appModel.showingOnboardingSheet && !appModel.showingSettingsSheet },
            set: { appModel.showingOnboardingSheet = $0 }
        )) {
            OnboardingSheetView()
        }
        .sheet(isPresented: Binding(
            get: { appModel.showingWorkspaceEditorSheet && !appModel.showingSettingsSheet },
            set: { appModel.showingWorkspaceEditorSheet = $0 }
        )) {
            WorkspaceEditorSheetView(
                initialDraft: appModel.workspaceEditorDraft,
                isEditing: appModel.workspaceEditorDraft.map { draft in
                    appModel.workspaces.contains(where: { $0.id == draft.id })
                } ?? false
            )
        }
        .background(keyboardShortcutHooks)
        .task {
            await appModel.bootstrap()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await appModel.handleWindowDidBecomeActive()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await appModel.handleWindowDidBecomeActive()
            }
        }
    }

    // MARK: - Hidden Keyboard Shortcuts (⌘1..⌘4 & ⌘,)

    private var keyboardShortcutHooks: some View {
        Group {
            Button("") { appModel.selectedSection = .mergeDashboard }
                .keyboardShortcut("1", modifiers: .command)
            Button("") { appModel.selectedSection = .worktrees }
                .keyboardShortcut("2", modifiers: .command)
            Button("") { appModel.selectedSection = .branchSync }
                .keyboardShortcut("3", modifiers: .command)
            Button("") { appModel.selectedSection = .mergeRequests }
                .keyboardShortcut("4", modifiers: .command)
            Button("") { appModel.showingSettingsSheet = true }
                .keyboardShortcut(",", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    // MARK: - Sidebar (Always-present Persistent Repository List)

    private var sidebarContent: some View {
        @Bindable var appModel = appModel

        return VStack(spacing: 0) {
            workspaceSwitcherHeader
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)

            sidebarRepoSearchBar
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            List {
                persistentProjectsSidebarSection
            }
            .listStyle(.sidebar)

            Divider().opacity(0.6)
            sidebarSettingsDock
            Divider().opacity(0.5)
            sidebarFooter
        }
        .navigationTitle("GWorkbench")
        .navigationSplitViewColumnWidth(min: 230, ideal: 256, max: 300)
    }

    private var sidebarRepoSearchBar: some View {
        @Bindable var appModel = appModel

        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("搜索当前工作区仓库...", text: $appModel.sidebarRepoSearchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
            if !appModel.sidebarRepoSearchText.isEmpty {
                Button {
                    appModel.sidebarRepoSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 0.6)
        )
    }

    @ViewBuilder
    private var persistentProjectsSidebarSection: some View {
        let projects = appModel.sidebarFilteredProjects
        let wsTitle = appModel.activeWorkspace?.name ?? appModel.activePlatform.shortName
        let dirtyNames = appModel.dirtyProjectNames

        if projects.isEmpty {
            Section("\(wsTitle) 仓库 (0)") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appModel.sidebarRepoSearchText.isEmpty ? "当前工作区尚未绑定仓库目录" : "没有匹配的仓库")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    if appModel.sidebarRepoSearchText.isEmpty {
                        Button("配置仓库目录...") {
                            if let ws = appModel.activeWorkspace {
                                appModel.openEditWorkspaceEditor(ws)
                            } else {
                                appModel.showingSettingsSheet = true
                            }
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 6)
            }
        } else {
            Section("\(wsTitle) 仓库 (\(projects.count))") {
                ForEach(projects) { project in
                    let count = appModel.worktreeCountByProject[project.displayName, default: 0]
                    let isDirty = dirtyNames.contains(project.displayName) || dirtyNames.contains(project.name)
                    let isSelected = appModel.currentWorktreeProject?.id == project.id
                    let dotColor: Color = isDirty ? .orange : (count > 0 ? .green : Color.secondary.opacity(0.35))

                    Button {
                        appModel.selectWorkspaceProject(project)
                    } label: {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(dotColor)
                                .frame(width: 6, height: 6)

                            Text(project.displayName)
                                .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer(minLength: 4)

                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(isSelected ? Color.white.opacity(0.22) : Color.secondary.opacity(0.16))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(isSelected ? Color.accentColor : Color.clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                }
            }
        }
    }

    private var sidebarSettingsDock: some View {
        Button {
            appModel.showingSettingsSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(appModel.showingSettingsSheet ? Color.accentColor : Color.secondary)
                Text("工作区与全局设置")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text("⌘,")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(appModel.showingSettingsSheet
                          ? Color.accentColor.opacity(0.16)
                          : Color(NSColor.controlBackgroundColor).opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 0.6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private var sidebarFooter: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appModel.activePlatform.tintColor)
                .frame(width: 6, height: 6)
            Text(appModel.sidebarPlatformStatusText)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Text("v\(appModel.appVersionString)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(.bar)
    }

    private var workspaceSwitcherHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Group {
                    if appModel.workspaces.count <= 3 {
                        HStack(spacing: 3) {
                            workspaceTabButtons(fillWidth: true)
                        }
                        .padding(3)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 3) {
                                workspaceTabButtons(fillWidth: false)
                            }
                            .padding(3)
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.16), lineWidth: 0.5)
                )

                Button {
                    appModel.openNewWorkspaceEditor()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.18), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help("新建工作区标签")
            }
        }
    }

    @ViewBuilder
    private func workspaceTabButtons(fillWidth: Bool) -> some View {
        ForEach(appModel.workspaces) { workspace in
            let isSelected = appModel.activeWorkspace?.id == workspace.id
            Button {
                appModel.selectWorkspace(workspace.id)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: workspace.platform.icon)
                        .font(.system(size: 10.5, weight: .medium))
                    Text(workspace.name)
                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .frame(maxWidth: fillWidth ? .infinity : nil)
                .foregroundStyle(isSelected ? workspace.platform.tintColor : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? workspace.platform.tintColor.opacity(0.16) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? workspace.platform.tintColor.opacity(0.45) : Color.clear, lineWidth: 0.75)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("编辑工作区...") {
                    appModel.openEditWorkspaceEditor(workspace)
                }
            }
        }
    }

    // MARK: - Main Workspace Column (Unified Top Bar + Center | Inspector)

    private var mainWorkspaceColumn: some View {
        VStack(spacing: 0) {
            unifiedWorkspaceTopBar
            Divider()

            HSplitView {
                contentColumn
                    .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)

                detailColumn
                    .frame(minWidth: 330, idealWidth: 365, maxWidth: 460, maxHeight: .infinity)
            }
        }
    }

    private var unifiedWorkspaceTopBar: some View {
        let projectName = appModel.currentWorktreeProject?.displayName
            ?? appModel.currentLocalMergeProject?.displayName
            ?? appModel.currentMergeProject?.displayName
            ?? "未选择仓库"
        let branchName = appModel.currentWorktreeProject?.currentBranch
            ?? appModel.currentLocalMergeProject?.currentBranch
            ?? ""
        let currentSection = appModel.selectedSection ?? .worktrees

        return HStack(spacing: 12) {
            // 1. 当前仓库与分支标识
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(appModel.activePlatform.tintColor)
                Text(projectName)
                    .font(.system(size: 13.5, weight: .bold))
                    .lineLimit(1)
                if !branchName.isEmpty {
                    Text(branchName)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.secondary.opacity(0.18), lineWidth: 0.5)
                        )
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 160, alignment: .leading)

            Spacer(minLength: 8)

            // 2. 4 态横向工作区视图切换
            HStack(spacing: 3) {
                ForEach(AppSection.allCases) { section in
                    let isSelected = currentSection == section
                    let title = section == .mergeRequests ? appModel.requestSectionTitle : section.title
                    let badge = sectionBadgeText(for: section)

                    Button {
                        appModel.selectedSection = section
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: section.icon)
                                .font(.system(size: 11, weight: .medium))
                            Text(title)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                .lineLimit(1)
                            if let badge {
                                Text(badge)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.22))
                                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5.5)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(isSelected ? Color(NSColor.controlBackgroundColor) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(isSelected ? Color.secondary.opacity(0.25) : Color.clear, lineWidth: 0.6)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 0.6)
            )

            Spacer(minLength: 8)

            // 3. 当前视图专属操作按钮
            HStack(spacing: 8) {
                refreshButton(for: currentSection)
                primaryActionButton(for: currentSection)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder
    private func refreshButton(for section: AppSection) -> some View {
        switch section {
        case .mergeDashboard:
            Button {
                Task { await appModel.forceRefreshMergeDashboard() }
            } label: {
                if appModel.isMergeDashboardAnalyzing {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text("分析中")
                    }
                } else {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
            .disabled(appModel.isMergeDashboardAnalyzing)
            .help("重新分析所有工作树的合入状态")
        case .worktrees:
            Button {
                Task { await appModel.refreshWorktrees() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .help("重新扫描工作树状态")
        case .branchSync:
            Button {
                Task { await appModel.refreshLocalMergeProjects() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .help("重新读取本地项目分支与环境配置")
        case .mergeRequests:
            Button {
                Task { await appModel.refreshMergeRequests() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .help("从 \(appModel.activePlatform.shortName) 重新拉取最新 \(appModel.requestShortLabel) 状态")
        }
    }

    @ViewBuilder
    private func primaryActionButton(for section: AppSection) -> some View {
        switch section {
        case .mergeDashboard:
            let cleanCount = appModel.mergeDashboardFullyMergedCount
            Button {
                appModel.openWorktreeSweeper()
            } label: {
                Label(cleanCount > 0 ? "空间清理 (\(cleanCount))" : "空间清理", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .help("分析并一键回收已合入或休眠的陈旧工作树")
        case .worktrees:
            Button {
                appModel.prepareCreateWorktree()
            } label: {
                Label("新建工作树", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        case .branchSync:
            Button {
                Task { await appModel.executeLocalOperation() }
            } label: {
                HStack(spacing: 5) {
                    if appModel.localOperation.isRunning {
                        ProgressView().controlSize(.small)
                        Text("执行中...")
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("开始执行")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!appModel.canExecuteLocalOperation || appModel.localOperation.isRunning)
        case .mergeRequests:
            Button {
                appModel.prepareCreateMergeRequest()
            } label: {
                Label("创建 \(appModel.requestShortLabel)", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Content & Detail Columns

    @ViewBuilder
    private var contentColumn: some View {
        switch appModel.selectedSection ?? .worktrees {
        case .worktrees:
            WorktreesListView()
        case .mergeDashboard:
            MergeDashboardView()
        case .branchSync:
            BranchSyncView()
        case .mergeRequests:
            MergeRequestsListView()
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch appModel.selectedSection ?? .worktrees {
        case .worktrees:
            WorktreeDetailView()
        case .mergeDashboard:
            MergeDashboardDetailView()
        case .branchSync:
            BranchSyncDetailView()
        case .mergeRequests:
            MergeRequestDetailView()
        }
    }

    private func sectionBadgeText(for section: AppSection) -> String? {
        switch section {
        case .worktrees:
            let count = appModel.filteredWorktrees.filter { $0.kind == .worktree }.count
            return count > 0 ? "\(count)" : nil
        case .mergeDashboard:
            let count = appModel.mergeDashboardItems.filter { $0.kind != .mainRepo }.count
            return count > 0 ? "\(count)" : nil
        case .branchSync:
            if appModel.activeSyncSession?.hasActiveConflict == true {
                return "!"
            }
            return nil
        case .mergeRequests:
            let count = appModel.mergeRequests.count
            return count > 0 ? "\(count)" : nil
        }
    }
}

// MARK: - Centered Settings Modal Sheet

struct SettingsModalSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var appModel = appModel

        HStack(spacing: 0) {
            SettingsView(onClose: {
                dismiss()
            })
            .frame(minWidth: 780, maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            SettingsDetailView()
                .frame(width: 290)
        }
        .frame(minWidth: 1080, idealWidth: 1160, minHeight: 650, idealHeight: 710)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: Binding(
            get: { appModel.showingOnboardingSheet && appModel.showingSettingsSheet },
            set: { appModel.showingOnboardingSheet = $0 }
        )) {
            OnboardingSheetView()
        }
        .sheet(isPresented: Binding(
            get: { appModel.showingWorkspaceEditorSheet && appModel.showingSettingsSheet },
            set: { appModel.showingWorkspaceEditorSheet = $0 }
        )) {
            WorkspaceEditorSheetView(
                initialDraft: appModel.workspaceEditorDraft,
                isEditing: appModel.workspaceEditorDraft.map { draft in
                    appModel.workspaces.contains(where: { $0.id == draft.id })
                } ?? false
            )
        }
    }
}
