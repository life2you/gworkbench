import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    }
                }

                if appModel.selectedSection == .worktrees {
                    Section("项目") {
                        ForEach(appModel.worktreeProjects) { project in
                            SidebarRowButton(
                                title: project.displayName,
                                subtitle: "当前分支: \(project.currentBranch)",
                                badge: "\(appModel.worktreeCountByProject[project.displayName, default: 0])",
                                isSelected: appModel.selectedProjectID == project.id
                            ) {
                                appModel.selectProject(project.id)
                            }
                            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        }
                    }
                }

                if appModel.selectedSection == .branchSync {
                    Section("项目") {
                        ForEach(appModel.localMergeProjects) { project in
                            SidebarRowButton(
                                title: project.displayName,
                                subtitle: "当前分支: \(project.currentBranch)",
                                badge: "\(project.localBranches.count)",
                                isSelected: appModel.selectedLocalProjectID == project.id
                            ) {
                                appModel.selectLocalProject(project.id)
                            }
                            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        }
                    }
                }

                if appModel.selectedSection == .mergeRequests {
                    Section("筛选") {
                        ForEach(MergeRequestFilter.allCases) { filter in
                            SidebarRowButton(
                                title: filter.title,
                                badge: "\(appModel.mergeCountByFilter[filter, default: 0])",
                                isSelected: appModel.selectedMergeFilter == filter
                            ) {
                                appModel.selectMergeFilter(filter)
                            }
                            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        }
                    }
                }
            }
            .navigationTitle("GWorkbench")
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 280)
        } content: {
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
            .navigationSplitViewColumnWidth(min: 560, ideal: 700, max: 820)
        } detail: {
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
            .navigationSplitViewColumnWidth(min: 420, ideal: 520, max: 680)
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            await appModel.bootstrap()
        }
    }

    private func sectionBadge(for section: AppSection) -> Int {
        switch section {
        case .worktrees:
            return appModel.worktrees.count
        case .branchSync:
            return appModel.localMergeProjects.count
        case .mergeRequests:
            return appModel.mergeRequests.count
        case .settings:
            return 0
        }
    }
}
