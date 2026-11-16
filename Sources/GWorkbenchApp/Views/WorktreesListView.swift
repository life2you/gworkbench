import SwiftUI
import AppKit

struct WorktreesListView: View {
    @Environment(AppModel.self) private var appModel
    @State private var itemToDelete: WorktreeItem?
    @State private var showingDeleteAlert = false

    var body: some View {
        @Bindable var appModel = appModel

        VStack(spacing: 0) {
            toolbarHeader
            Divider()

            if appModel.worktreeProjects.isEmpty {
                ContentUnavailableView("未检测到本地项目", systemImage: "folder.badge.questionmark")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appModel.sortedWorktrees.isEmpty {
                ContentUnavailableView("暂无匹配工作树", systemImage: "point.3.connected.trianglepath.dotted", description: Text("可尝试切换分类标签或清空筛选搜索词"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                worktreesTable
            }

            ResizeHandleView()
            WorktreeConsolePanelView()
            Divider()
            ProStatusBarView()
        }
        .task {
            if appModel.selectedWorktree != nil && appModel.selectedWorktreeFileChanges.isEmpty {
                appModel.syncSelectedWorktreeDetails()
            }
        }
        .sheet(isPresented: $appModel.showingCreateWorktreeSheet) {
            CreateWorktreeSheetView()
        }
        .confirmationDialog(
            "删除工作树",
            isPresented: $showingDeleteAlert,
            titleVisibility: .visible,
            presenting: itemToDelete
        ) { item in
            Button("仅删除工作树目录", role: .destructive) {
                Task {
                    await appModel.removeWorktree(item, deleteLocalBranch: false, deleteRemoteBranch: false)
                }
            }
            if item.canRemoveRemoteBranch {
                Button("删除工作树及本地和远程分支", role: .destructive) {
                    Task {
                        await appModel.removeWorktree(item, deleteLocalBranch: true, deleteRemoteBranch: true)
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: { item in
            Text("确定删除分支「\(item.branch)」的工作树目录？\n路径：\(item.path)")
        }
    }

    // MARK: - Toolbar Header

    private var toolbarHeader: some View {
        HStack(spacing: 10) {
            // 工作树分支状态分类分段控制器
            Picker("工作树分类", selection: categoryBinding) {
                ForEach(WorktreeCategoryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 240)

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("筛选分支或描述...", text: worktreeSearchBinding)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !appModel.worktreeSearchText.isEmpty {
                    Button {
                        appModel.worktreeSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .frame(width: 220)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.25))
    }

    // MARK: - Worktrees Table

    private var worktreesTable: some View {
        @Bindable var appModel = appModel

        return Table(appModel.sortedWorktrees, selection: $appModel.selectedWorktreeID, sortOrder: $appModel.sortOrder) {
            TableColumn("分支", value: \.branch) { item in
                HStack(spacing: 6) {
                    Image(systemName: item.kind == .mainRepo ? "shippingbox.fill" : "arrow.triangle.branch")
                        .foregroundStyle(item.kind == .mainRepo ? Color.blue : Color.purple)
                        .font(.system(size: 11))
                    Text(item.branch)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .lineLimit(1)
                }
            }
            .width(min: 130, ideal: 180, max: 260)

            TableColumn("类别", value: \.kind.rawValue) { item in
                StatusPill(
                    title: item.kind.rawValue,
                    tint: item.kind == .mainRepo ? .blue : .purple
                )
            }
            .width(min: 65, ideal: 75, max: 90)

            TableColumn("状态", value: \.dirtySummary) { item in
                StatusPill(
                    title: item.dirtySummary,
                    tint: item.isDirty ? .orange : .green,
                    systemImage: item.isDirty ? "pencil.circle.fill" : "checkmark.circle.fill"
                )
            }
            .width(min: 80, ideal: 95, max: 120)

            TableColumn("上游追踪", value: \.upstream) { item in
                Text(item.upstream)
                    .font(.caption)
                    .foregroundStyle(item.upstream == "未配置" ? .secondary : .primary)
                    .lineLimit(1)
            }
            .width(min: 90, ideal: 120, max: 160)

            TableColumn("物理路径", value: \.path) { item in
                Text(item.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 140, ideal: 200)

            TableColumn("更新时间", value: \.updatedAt) { item in
                Text(item.updatedAt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 70, ideal: 90, max: 120)

            TableColumn("磁盘占用", value: \.diskUsage) { item in
                Text(item.diskUsage)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 60, ideal: 75, max: 95)

            TableColumn("最新提交", value: \.head) { item in
                Text(item.head)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .width(min: 130, ideal: 200)
        }
        .contextMenu(forSelectionType: WorktreeItem.ID.self) { selection in
            if let id = selection.first, let item = appModel.worktrees.first(where: { $0.id == id }) {
                worktreeContextMenu(for: item)
            }
        } primaryAction: { selection in
            if let id = selection.first, let item = appModel.worktrees.first(where: { $0.id == id }) {
                appModel.openWorktreeInIDE(item)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func worktreeContextMenu(for item: WorktreeItem) -> some View {
        IDEOpenContextMenuContent(
            profiles: appModel.configuredIDEProfiles,
            defaultProfile: appModel.defaultIDEProfile,
            onOpen: { ide in
                appModel.selectedWorktreeID = item.id
                appModel.openWorktreeInIDE(item, ide: ide)
            }
        )

        Button {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
        } label: {
            Label("在 Finder 中显示", systemImage: "folder")
        }

        Button {
            appModel.selectedWorktreeID = item.id
            appModel.openWorktreeInTerminal(item)
        } label: {
            Label("在终端打开", systemImage: "terminal")
        }

        Divider()

        Button {
            appModel.copyWorktreePath(item)
        } label: {
            Label("复制物理路径", systemImage: "doc.on.doc")
        }

        Button {
            appModel.copyWorktreeBranch(item)
        } label: {
            Label("复制分支名", systemImage: "arrow.triangle.branch")
        }

        Divider()

        Button(role: .destructive) {
            itemToDelete = item
            showingDeleteAlert = true
        } label: {
            Label("删除工作树", systemImage: "trash")
        }
        .disabled(item.kind == .mainRepo)
    }

    // MARK: - Bindings

    private var categoryBinding: Binding<WorktreeCategoryFilter> {
        Binding(
            get: { appModel.selectedWorktreeCategory },
            set: { appModel.selectedWorktreeCategory = $0 }
        )
    }

    private var platformFilterBinding: Binding<RepositoryPlatform> {
        Binding(
            get: { appModel.selectedPlatformFilter },
            set: { appModel.selectedPlatformFilter = $0 }
        )
    }

    private var projectBinding: Binding<String?> {
        Binding(
            get: { appModel.selectedProjectID },
            set: { if let value = $0 { appModel.selectProject(value) } }
        )
    }

    private var worktreeSearchBinding: Binding<String> {
        Binding(
            get: { appModel.worktreeSearchText },
            set: { appModel.worktreeSearchText = $0 }
        )
    }
}
