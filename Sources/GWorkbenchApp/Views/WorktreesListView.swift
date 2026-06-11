import SwiftUI

struct WorktreesListView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        VStack(spacing: 0) {
            header
            if appModel.worktreeProjects.isEmpty {
                ContentUnavailableView("未检测到 gwtm 项目", systemImage: "folder.badge.questionmark")
            } else {
                List(appModel.filteredWorktrees, selection: $appModel.selectedWorktreeID) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.branch)
                                .font(.headline)
                            Spacer()
                            Text(item.updatedAt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 8) {
                            StatusPill(
                                title: item.kind.rawValue,
                                tint: item.kind == .mainRepo ? .blue : .purple
                            )
                            Text(item.project)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(item.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 6)
                    .tag(item.id)
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $appModel.showingCreateWorktreeSheet) {
            CreateWorktreeSheetView()
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ViewThatFits(in: .horizontal) {
                wideHeader
                compactHeader
            }

            InlineOperationView(state: appModel.worktreeOperation)
        }
        .padding(20)
        .background(.bar)
    }

    private var wideHeader: some View {
        HStack(spacing: 12) {
            titleBlock
            Spacer()
            projectPicker
                .frame(width: 220)
            searchField
                .frame(width: 220)
            refreshButton
            createButton
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleBlock

            HStack(alignment: .center, spacing: 12) {
                projectPicker
                    .frame(minWidth: 220, maxWidth: 280)
                refreshButton
                createButton
            }

            searchField
                .frame(maxWidth: .infinity)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("工作树")
                .font(.title2.weight(.semibold))
            Text("创建、打开和清理本地工作树，保持开发上下文清晰。")
                .foregroundStyle(.secondary)
        }
    }

    private var projectPicker: some View {
        Picker("项目", selection: projectBinding) {
            ForEach(appModel.worktreeProjects) { project in
                Text(project.displayName).tag(Optional(project.id))
            }
        }
        .pickerStyle(.menu)
    }

    private var searchField: some View {
        TextField("筛选分支或描述", text: worktreeSearchBinding)
            .textFieldStyle(.roundedBorder)
    }

    private var refreshButton: some View {
        Button("刷新") {
            Task {
                await appModel.refreshWorktrees()
            }
        }
    }

    private var createButton: some View {
        Button("新建工作树") {
            appModel.prepareCreateWorktree()
        }
        .buttonStyle(.borderedProminent)
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
