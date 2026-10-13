import SwiftUI
import AppKit

struct WorktreeDetailView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        Group {
            if let item = appModel.selectedWorktree {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        headerSection(item: item)

                        quickActionRow(item: item)

                        inspectorCard(title: "属性概览", systemImage: "info.circle") {
                            VStack(alignment: .leading, spacing: 8) {
                                inspectorRow(label: "项目", value: item.project)
                                inspectorRow(label: "物理路径", value: item.path, isMonospaced: true, canCopy: true)
                                if item.platform != .local {
                                    inspectorRow(label: "托管平台", value: item.platform.displayName)
                                }
                                inspectorRow(label: "上游分支", value: item.upstream, isMonospaced: true)
                                inspectorRow(label: "最新提交", value: item.head, isMonospaced: true)
                                inspectorRow(label: "磁盘占用", value: item.diskUsage, isMonospaced: true)
                                inspectorRow(label: "创建类型", value: item.createdDetail)
                            }
                        }

                        inspectorCard(title: "功能描述与备忘", systemImage: "note.text") {
                            VStack(alignment: .leading, spacing: 8) {
                                if item.kind == .mainRepo {
                                    Text("主仓库为生产基准，不建议记录局部开发备忘。")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                } else {
                                    TextField("记录该工作树的任务背景或备忘（自动关联元数据）...", text: $appModel.worktreeDescriptionDraft, axis: .vertical)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(3, reservesSpace: true)
                                        .font(.system(size: 12))

                                    HStack {
                                        Spacer()
                                        if !appModel.worktreeDescriptionDraft.isEmpty {
                                            Button("清空") {
                                                appModel.worktreeDescriptionDraft = ""
                                            }
                                            .controlSize(.small)
                                            .buttonStyle(.plain)
                                            .foregroundStyle(.secondary)
                                        }
                                        Button("保存描述") {
                                            Task {
                                                await appModel.saveSelectedWorktreeDescription()
                                            }
                                        }
                                        .controlSize(.small)
                                        .buttonStyle(.borderedProminent)
                                        .disabled(appModel.worktreeOperation.isRunning)
                                    }
                                }
                            }
                        }

                        if !item.commits.isEmpty {
                            inspectorCard(title: "最近提交历史", systemImage: "clock.arrow.circlepath") {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(item.commits.prefix(5))) { commit in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(commit.message)
                                                .font(.system(size: 12, weight: .medium))
                                                .lineLimit(2)
                                            HStack(spacing: 6) {
                                                Text(commit.sha)
                                                    .font(.system(size: 10.5, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                Text("•")
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(.tertiary)
                                                Text(commit.author)
                                                    .font(.system(size: 10.5))
                                                    .foregroundStyle(.secondary)
                                                Spacer()
                                                Text(commit.relativeTime)
                                                    .font(.system(size: 10.5))
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                        if commit.id != item.commits.prefix(5).last?.id {
                                            Divider()
                                                .opacity(0.5)
                                        }
                                    }
                                }
                            }
                        }

                        if item.kind != .mainRepo {
                            inspectorCard(title: "空间清理", systemImage: "trash") {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("删除本地工作树目录。未勾选时将保留本地和远程 Git 分支。")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)

                                    Toggle("同时删除本地 Git 分支", isOn: bindableDeleteLocalBranch)
                                        .font(.system(size: 11.5))
                                    Toggle("同时删除远程跟踪分支", isOn: bindableDeleteRemoteBranch)
                                        .font(.system(size: 11.5))
                                        .disabled(!item.canRemoveRemoteBranch)

                                    HStack {
                                        Spacer()
                                        Button("删除此工作树", role: .destructive) {
                                            Task {
                                                await appModel.removeSelectedWorktree()
                                            }
                                        }
                                        .controlSize(.small)
                                        .buttonStyle(.bordered)
                                        .disabled(appModel.worktreeOperation.isRunning)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(item.id)
            } else {
                ContentUnavailableView("未选择工作树", systemImage: "folder")
            }
        }
    }

    private func headerSection(item: WorktreeItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(item.project)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("/")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(item.kind.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(item.branch)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .textSelection(.enabled)

            if !item.summary.isEmpty && item.summary != "主仓库" && item.summary != "未填写功能描述" {
                Text(item.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                StatusPill(
                    title: item.kind.rawValue,
                    tint: item.kind == .mainRepo ? .blue : .purple,
                    systemImage: item.kind == .mainRepo ? "house.fill" : "point.3.connected.trianglepath.dotted"
                )

                if item.platform != .local {
                    StatusPill(
                        title: item.platform.badgeText,
                        tint: item.platform.tintColor,
                        systemImage: item.platform.icon
                    )
                }

                StatusPill(
                    title: item.dirtySummary,
                    tint: item.isDirty ? .orange : .green,
                    systemImage: item.isDirty ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                    isMonospaced: true
                )

                StatusPill(
                    title: item.diskUsage,
                    tint: .gray,
                    systemImage: "internaldrive",
                    isMonospaced: true
                )
            }
            .padding(.top, 2)
        }
        .padding(.bottom, 2)
    }

    private func quickActionRow(item: WorktreeItem) -> some View {
        HStack(spacing: 6) {
            Button {
                appModel.openWorktreeInIDE(item)
            } label: {
                Label(appModel.currentIDELabel, systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            } label: {
                Label("访达", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                appModel.openWorktreeInTerminal(item)
            } label: {
                Label("终端", systemImage: "terminal")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                appModel.copyWorktreePath(item)
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func inspectorRow(label: String, value: String, isMonospaced: Bool = false, canCopy: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)

            Text(value)
                .font(isMonospaced ? .system(size: 11.5, design: .monospaced) : .system(size: 11.5))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if canCopy {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("复制")
            }
        }
    }

    private func inspectorCard<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            content()
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
        )
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
