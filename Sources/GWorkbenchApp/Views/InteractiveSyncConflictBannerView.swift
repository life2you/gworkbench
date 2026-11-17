import SwiftUI
import AppKit

struct InteractiveSyncConflictBannerView: View {
    @Environment(AppModel.self) private var appModel
    let session: ActiveSyncSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 标题行
            HStack(alignment: .top) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("合并冲突暂停中")
                                .font(.headline)
                                .foregroundStyle(.red)

                            if let current = session.currentTarget {
                                Text("(\(session.currentTargetIndex + 1)/\(session.targets.count): \(current.targetBranch))")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("源分支 \(session.currentTarget?.sourceBranch ?? "") 合并至 \(session.currentTarget?.targetBranch ?? "") 发生冲突，已挂起流水线。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }

                Spacer()

                // 右侧目标状态小进度
                HStack(spacing: 6) {
                    ForEach(session.targets) { item in
                        Circle()
                            .fill(item.status.tintColor)
                            .frame(width: 8, height: 8)
                            .help("\(item.targetBranch): \(item.status.displayLabel)")
                    }
                }
            }

            Divider()

            // 冲突文件与当前解决状态
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(statusSectionTitle)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle(
                        "冲突解决后自动完成 Merge Commit 并推送",
                        isOn: Binding(
                            get: { session.autoCommitWhenResolved },
                            set: { appModel.setAutoCommitWhenResolved($0) }
                        )
                    )
                    .toggleStyle(.checkbox)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help("在 Rebased 中解决全部冲突并点 Accept and Finish 后，自动完成 git commit --no-edit 与 push 并进入下一个分支")

                    Button {
                        appModel.refreshActiveConflictFiles()
                    } label: {
                        Label("刷新状态", systemImage: "arrow.clockwise")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                }

                statusDetailBanner

                if !session.activeConflictFiles.isEmpty {
                    let markerFreeSet = Set(session.markerFreeConflictFiles)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(session.activeConflictFiles, id: \.self) { file in
                            let isMarkerFree = markerFreeSet.contains(file)
                            HStack(spacing: 8) {
                                Text(isMarkerFree ? "已解" : "UU")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background((isMarkerFree ? Color.green : Color.red).opacity(0.15))
                                    .foregroundStyle(isMarkerFree ? .green : .red)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Text(file)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()

                                if isMarkerFree {
                                    Text("已清冲突标记 · 待暂存")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // 操作按钮行
            HStack(spacing: 12) {
                // 全部中止
                Button(role: .destructive) {
                    Task {
                        await appModel.abortAllSyncSession()
                    }
                } label: {
                    Text("全部中止 (Abort All)")
                }
                .disabled(session.isAutoCommittingConflict)
                .help("取消当前及后续所有合并，将工程安全回退到初始分支")

                Spacer()

                // 跳过当前分支（用户不解决当前分支）
                Button {
                    Task {
                        await appModel.skipCurrentTargetAndContinue()
                    }
                } label: {
                    Label("跳过当前分支，继续下一个 ⏩", systemImage: "forward.fill")
                }
                .disabled(session.isAutoCommittingConflict)
                .help("放弃合入当前分支（保持该环境原状），继续同步流水线中的下一个目标分支")

                if case .abortedExternally = session.conflictPhase {
                    Button {
                        Task {
                            await appModel.retryCurrentTargetMerge()
                        }
                    } label: {
                        Label("重新合并当前分支", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("重新执行 git merge 并在冲突时调起 Rebased")
                } else {
                    // 调起 Rebased
                    Button {
                        appModel.handleConflictEncountered(projectPath: session.projectPath)
                    } label: {
                        Label("在 Rebased 中解决", systemImage: "arrow.triangle.merge")
                    }
                    .disabled(session.isAutoCommittingConflict)
                    .help("在 Rebased 3-Way 视窗中可视化解决冲突")

                    // 完成解决继续
                    Button {
                        Task {
                            await appModel.resolveAndContinueCurrentTarget()
                        }
                    } label: {
                        if session.isAutoCommittingConflict {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("正在自动提交并推送...")
                            }
                        } else {
                            Label(primaryContinueTitle, systemImage: "checkmark")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!session.canCommitAndContinue || session.isAutoCommittingConflict)
                    .help(primaryContinueHelp)
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1.5)
        )
        .onAppear {
            appModel.refreshActiveConflictFiles()
        }
    }

    private var statusSectionTitle: String {
        switch session.conflictPhase {
        case .readyToCommit:
            return "所有冲突已解决并暂存，准备完成 Merge Commit："
        case .committedExternally:
            return "检测到合并已在外部（Rebased）完成提交："
        case .abortedExternally:
            return "检测到合并已在外部被中止："
        case .awaitingResolution, .none:
            return "冲突文件 (\(session.activeConflictFiles.count) 个未完成):"
        }
    }

    @ViewBuilder
    private var statusDetailBanner: some View {
        switch session.conflictPhase {
        case .readyToCommit:
            HStack(spacing: 8) {
                if session.isAutoCommittingConflict {
                    ProgressView()
                        .controlSize(.small)
                    Text("冲突已解决并暂存，正在自动执行 Merge Commit、推送并进入下一个分支…")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("所有冲突已解决并暂存！可点击右下方「\(primaryContinueTitle)」提交标准 Merge Commit 并继续。")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))

        case .committedExternally:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("检测到合并提交已在外部分支完成，点击「\(primaryContinueTitle)」将同步推送并进入下一目标。")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))

        case .abortedExternally:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("检测到当前合并现场已在外部（如 Rebased 的 Abort Merge）被取消。你可以点击「重新合并当前分支」或「跳过当前分支」。")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))

        case .awaitingResolution:
            if session.allConflictFilesMarkerFree {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("所有冲突文件的冲突标记均已清理！在 Rebased 点击 Accept and Finish 后会自动提交，也可直接点击右下方「\(primaryContinueTitle)」。")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

        case .none:
            EmptyView()
        }
    }

    private var primaryContinueTitle: String {
        switch session.conflictPhase {
        case .committedExternally:
            return "同步推送并继续 🟢"
        case .awaitingResolution where session.allConflictFilesMarkerFree:
            return "暂存并完成合并 🟢"
        default:
            return "完成合并提交并继续 🟢"
        }
    }

    private var primaryContinueHelp: String {
        switch session.conflictPhase {
        case .readyToCommit:
            return "提交当前 Merge Commit 并推送到远程，流转至下一分支"
        case .committedExternally:
            return "推送已完成的合并提交到远程，并流转至下一分支"
        case .awaitingResolution where session.allConflictFilesMarkerFree:
            return "自动 git add 已解决的冲突文件，完成 Merge Commit 并推送到远程"
        default:
            return "请先在 Rebased 中解决冲突并点击 Accept and Finish"
        }
    }

    private var borderColor: Color {
        switch session.conflictPhase {
        case .readyToCommit, .committedExternally:
            return Color.green.opacity(0.45)
        case .abortedExternally:
            return Color.orange.opacity(0.5)
        default:
            return Color.red.opacity(0.4)
        }
    }
}
