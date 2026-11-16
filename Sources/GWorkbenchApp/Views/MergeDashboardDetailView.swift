import SwiftUI

struct MergeDashboardDetailView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if let dashItem = appModel.selectedDashboardItem,
               let worktree = appModel.selectedDashboardWorktree {
                WorktreeInspectorBody(
                    item: worktree,
                    focus: .dashboard,
                    dashboardItem: dashItem
                )
                .onAppear {
                    syncSelection(worktree: worktree)
                }
                .onChange(of: dashItem.id) { _, _ in
                    syncSelection(worktree: worktree)
                }
            } else {
                ContentUnavailableView(
                    "选择工作树查看详情",
                    systemImage: "chart.bar.xaxis",
                    description: Text("在看板中点击某个工作树查看其合入详情和分支信息")
                )
            }
        }
    }

    private func syncSelection(worktree: WorktreeItem) {
        if appModel.selectedWorktreeID != worktree.id {
            appModel.selectedWorktreeID = worktree.id
            appModel.syncSelectedWorktreeDetails()
        }
    }
}
