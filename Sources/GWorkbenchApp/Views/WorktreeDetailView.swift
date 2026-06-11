import SwiftUI
import AppKit

struct WorktreeDetailView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        Group {
            if let item = appModel.selectedWorktree {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(item: item)

                        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                            DetailLabelRow(title: "项目", value: item.project)
                            DetailLabelRow(title: "路径", value: item.path)
                            DetailLabelRow(title: "上游分支", value: item.upstream)
                            DetailLabelRow(title: "当前提交", value: item.head)
                            DetailLabelRow(title: "创建信息", value: item.createdDetail)
                            DetailLabelRow(title: "磁盘占用", value: item.diskUsage)
                        }

                        actionSection(item: item)

                        SectionCard(title: "功能描述") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(item.kind == .mainRepo ? "主仓库默认不写功能描述。" : "给当前 worktree 补充一个功能描述，列表里会直接展示。")
                                    .foregroundStyle(.secondary)
                                TextField("例如：支付重试队列改造", text: $appModel.worktreeDescriptionDraft, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3, reservesSpace: true)
                                    .disabled(item.kind == .mainRepo)
                                HStack {
                                    Spacer()
                                    Button("清空") {
                                        appModel.worktreeDescriptionDraft = ""
                                    }
                                    .disabled(item.kind == .mainRepo || appModel.worktreeOperation.isRunning)
                                    Button("保存描述") {
                                        Task {
                                            await appModel.saveSelectedWorktreeDescription()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(item.kind == .mainRepo || appModel.worktreeOperation.isRunning)
                                }
                            }
                        }

                        if !item.commits.isEmpty {
                            SectionCard(title: "最近提交") {
                                Table(item.commits) {
                                    TableColumn("SHA") { commit in
                                        Text(commit.sha)
                                            .font(.system(.body, design: .monospaced))
                                    }
                                    TableColumn("提交说明") { commit in
                                        Text(commit.message)
                                    }
                                    TableColumn("作者") { commit in
                                        Text(commit.author)
                                    }
                                    TableColumn("时间") { commit in
                                        Text(commit.relativeTime)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(minHeight: 180)
                            }
                        }

                        SectionCard(title: "清理") {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("删除工作树目录，本地分支和远程分支默认保留，除非你主动勾选。")
                                    .foregroundStyle(.secondary)
                                Toggle("同时删除本地分支", isOn: bindableDeleteLocalBranch)
                                Toggle("同时删除远程分支", isOn: bindableDeleteRemoteBranch)
                                    .disabled(!item.canRemoveRemoteBranch)
                                HStack {
                                    Spacer()
                                    Button("删除工作树", role: .destructive) {
                                        Task {
                                            await appModel.removeSelectedWorktree()
                                        }
                                    }
                                    .disabled(item.kind == .mainRepo || appModel.worktreeOperation.isRunning)
                                }
                            }
                        }

                        SectionCard(title: "执行状态") {
                            InlineOperationView(state: appModel.worktreeOperation)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onAppear {
                    appModel.syncSelectedWorktreeDescriptionDraft()
                }
                .onChange(of: item.id) {
                    appModel.syncSelectedWorktreeDescriptionDraft()
                }
            } else {
                ContentUnavailableView("未选择工作树", systemImage: "folder")
            }
        }
    }

    private func header(item: WorktreeItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.kind == .mainRepo ? "主仓库 · \(item.project)" : "工作树 · \(item.project)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(item.branch)
                .font(.largeTitle.weight(.semibold))
            Text(item.summary)
                .font(.title3)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                StatusPill(title: item.kind.rawValue, tint: item.kind == .mainRepo ? .blue : .purple)
                StatusPill(title: item.updatedAt, tint: .gray)
            }
        }
    }

    private func actionSection(item: WorktreeItem) -> some View {
        SectionCard(title: "快捷操作") {
            HStack {
                Button("用 IDE 打开") {
                    appModel.openSelectedWorktreeInIDE()
                }
                    .buttonStyle(.borderedProminent)
                Button("在 Finder 中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                }
                Button("在终端打开") {
                    appModel.openSelectedWorktreeInTerminal()
                }
                Button("复制路径") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.path, forType: .string)
                }
            }
        }
    }

    private var bindableDeleteLocalBranch: Binding<Bool> {
        Binding(
            get: { appModel.deleteLocalBranchOnRemove },
            set: { appModel.deleteLocalBranchOnRemove = $0 }
        )
    }

    private var bindableDeleteRemoteBranch: Binding<Bool> {
        Binding(
            get: { appModel.deleteRemoteBranchOnRemove },
            set: { appModel.deleteRemoteBranchOnRemove = $0 }
        )
    }
}
