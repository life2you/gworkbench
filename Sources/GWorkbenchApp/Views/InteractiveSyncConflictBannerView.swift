import SwiftUI
import AppKit

struct InteractiveSyncConflictBannerView: View {
    @Environment(AppModel.self) private var appModel
    let session: ActiveSyncSession

    @State private var timer: Timer? = nil

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

            // 冲突文件列表
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("冲突文件 (\(session.activeConflictFiles.count) 个未解决):")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        appModel.refreshActiveConflictFiles()
                    } label: {
                        Label("刷新状态", systemImage: "arrow.clockwise")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                }

                if session.activeConflictFiles.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("所有冲突已解决并暂存！可点击右下方「完成解决并继续」提交并进入下一个分支。")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(session.activeConflictFiles, id: \.self) { file in
                            HStack(spacing: 8) {
                                Text("UU")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.15))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Text(file)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // 操作按钮行：三岔路口
            HStack(spacing: 12) {
                // 全部中止
                Button(role: .destructive) {
                    Task {
                        await appModel.abortAllSyncSession()
                    }
                } label: {
                    Text("全部中止 (Abort All)")
                }
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
                .help("放弃合入当前分支（保持该环境原状），继续同步流水线中的下一个目标分支")

                // 调起 Rebased
                Button {
                    appModel.handleConflictEncountered(projectPath: session.projectPath)
                } label: {
                    Label("在 Rebased 中解决", systemImage: "arrow.triangle.merge")
                }
                .help("在 Rebased 3-Way 视窗中可视化解决冲突")

                // 完成解决继续
                Button {
                    Task {
                        await appModel.resolveAndContinueCurrentTarget()
                    }
                } label: {
                    Label("已完成解决，继续提交 🟢", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!session.activeConflictFiles.isEmpty)
                .help(session.activeConflictFiles.isEmpty ? "提交当前解决结果并推送到远程，流转至下一分支" : "尚有未解决冲突文件")
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.4), lineWidth: 1.5)
        )
        .onAppear {
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }

    private func startPolling() {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                appModel.refreshActiveConflictFiles()
            }
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
