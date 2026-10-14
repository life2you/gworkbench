import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    @State private var isWorktreeGitLabExpanded: Bool = true
    @State private var isWorktreeGitHubExpanded: Bool = true
    @State private var isWorktreeLocalExpanded: Bool = true

    @State private var isSyncGitLabExpanded: Bool = true
    @State private var isSyncOtherExpanded: Bool = true

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
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

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List {
            Section("工作区") {
                ForEach(AppSection.allCases) { section in
                    SidebarRowButton(
                        title: section.title,
                        systemImage: section.icon,
                        badge: sectionBadge(for: section) == 0 ? nil : "\(sectionBadge(for: section))",
                        isSelected: appModel.selectedSection == section
                    ) {
                        appModel.selectedSection = section
                    }
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                }
            }

            if appModel.selectedSection == .worktrees {
                worktreesSidebarSection
            }

            if appModel.selectedSection == .branchSync {
                branchSyncSidebarSection
            }

            if appModel.selectedSection == .mergeRequests {
                mergeRequestsSidebarSection
            }
        }
        .navigationTitle("GWorkbench")
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 280)
    }

    @ViewBuilder
    private var worktreesSidebarSection: some View {
        let gitlabProjects = appModel.worktreeProjects.filter { $0.platform == .gitlab }
        if !gitlabProjects.isEmpty {
            collapsibleSection(
                title: "私有 GitLab",
                count: gitlabProjects.count,
                isExpanded: $isWorktreeGitLabExpanded
            ) {
                ForEach(gitlabProjects) { project in
                    let count = appModel.worktreeCountByProject[project.displayName, default: 0]
                    SidebarRowButton(
                        title: project.displayName,
                        systemImage: "folder",
                        badge: count > 0 ? "\(count)" : nil,
                        isSelected: appModel.selectedProjectID == project.id
                    ) {
                        appModel.selectProject(project.id)
                    }
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                }
            }
        }

        let githubProjects = appModel.worktreeProjects.filter { $0.platform == .github }
        if !githubProjects.isEmpty {
            collapsibleSection(
                title: "GitHub",
                count: githubProjects.count,
                isExpanded: $isWorktreeGitHubExpanded
            ) {
                ForEach(githubProjects) { project in
                    let count = appModel.worktreeCountByProject[project.displayName, default: 0]
                    SidebarRowButton(
                        title: project.displayName,
                        systemImage: "folder",
                        badge: count > 0 ? "\(count)" : nil,
                        isSelected: appModel.selectedProjectID == project.id
                    ) {
                        appModel.selectProject(project.id)
                    }
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                }
            }
        }

        let localProjects = appModel.worktreeProjects.filter { $0.platform == .local }
        if !localProjects.isEmpty {
            collapsibleSection(
                title: "本地仓库",
                count: localProjects.count,
                isExpanded: $isWorktreeLocalExpanded
            ) {
                ForEach(localProjects) { project in
                    let count = appModel.worktreeCountByProject[project.displayName, default: 0]
                    SidebarRowButton(
                        title: project.displayName,
                        systemImage: "folder",
                        badge: count > 0 ? "\(count)" : nil,
                        isSelected: appModel.selectedProjectID == project.id
                    ) {
                        appModel.selectProject(project.id)
                    }
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                }
            }
        }
    }

    @ViewBuilder
    private var branchSyncSidebarSection: some View {
        let gitlabMergeProjects = appModel.localMergeProjects.filter { $0.platform == .gitlab }
        if !gitlabMergeProjects.isEmpty {
            collapsibleSection(
                title: "私有 GitLab",
                count: gitlabMergeProjects.count,
                isExpanded: $isSyncGitLabExpanded
            ) {
                ForEach(gitlabMergeProjects) { project in
                    SidebarRowButton(
                        title: project.displayName,
                        systemImage: "folder",
                        badge: "\(project.localBranches.count)",
                        isSelected: appModel.selectedLocalProjectID == project.id
                    ) {
                        appModel.selectLocalProject(project.id)
                    }
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                }
            }
        }

        let otherMergeProjects = appModel.localMergeProjects.filter { $0.platform != .gitlab }
        if !otherMergeProjects.isEmpty {
            collapsibleSection(
                title: "其他项目",
                count: otherMergeProjects.count,
                isExpanded: $isSyncOtherExpanded
            ) {
                ForEach(otherMergeProjects) { project in
                    SidebarRowButton(
                        title: project.displayName,
                        systemImage: "folder",
                        badge: "\(project.localBranches.count)",
                        isSelected: appModel.selectedLocalProjectID == project.id
                    ) {
                        appModel.selectLocalProject(project.id)
                    }
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                }
            }
        }
    }

    @ViewBuilder
    private var mergeRequestsSidebarSection: some View {
        Section("筛选") {
            ForEach(MergeRequestFilter.allCases) { filter in
                SidebarRowButton(
                    title: filter.title,
                    badge: "\(appModel.mergeCountByFilter[filter, default: 0])",
                    isSelected: appModel.selectedMergeFilter == filter
                ) {
                    appModel.selectMergeFilter(filter)
                }
                .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
            }
        }
    }

    // MARK: - Content Column

    @ViewBuilder
    private var contentColumn: some View {
        Group {
            switch appModel.selectedSection ?? .worktrees {
            case .worktrees:
                WorktreesListView()
            case .branchSync:
                BranchSyncView()
            case .mergeRequests:
                MergeRequestsListView()
            case .settings:
                SettingsView()
            }
        }
        .navigationSplitViewColumnWidth(min: 650, ideal: 800, max: 1200)
    }

    // MARK: - Detail Column

    @ViewBuilder
    private var detailColumn: some View {
        Group {
            switch appModel.selectedSection ?? .worktrees {
            case .worktrees:
                WorktreeDetailView()
            case .branchSync:
                BranchSyncDetailView()
            case .mergeRequests:
                MergeRequestDetailView()
            case .settings:
                SettingsDetailView()
            }
        }
        .navigationSplitViewColumnWidth(min: 340, ideal: 380, max: 520)
    }

    private func collapsibleSection<Content: View>(
        title: String,
        count: Int,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Section {
            if isExpanded.wrappedValue {
                content()
            }
        } header: {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10, height: 10)

                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 2, trailing: 0))
        }
    }

    private func sectionBadge(for section: AppSection) -> Int {
        switch section {
        case .worktrees:
            return appModel.realWorktreesCount
        case .branchSync:
            return appModel.localMergeProjects.count
        case .mergeRequests:
            return appModel.mergeRequests.count
        case .settings:
            return 0
        }
    }
}
