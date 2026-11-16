import SwiftUI

struct WorktreeDetailView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if let item = appModel.selectedWorktree {
                WorktreeInspectorBody(item: item, focus: .worktree)
            } else {
                ContentUnavailableView("未选择工作树", systemImage: "folder")
            }
        }
    }
}
