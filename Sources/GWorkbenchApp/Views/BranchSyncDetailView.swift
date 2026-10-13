import SwiftUI
import AppKit

struct BranchSyncDetailView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if let project = appModel.currentLocalMergeProject {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        headerSection(project)

                        quickActionRow(project)

                        inspectorCard(title: "项目配置概览", systemImage: "info.circle") {
                            VStack(alignment: .leading, spacing: 8) {
                                inspectorRow(label: "项目名称", value: project.displayName)
                                inspectorRow(label: "物理路径", value: project.path, isMonospaced: true, canCopy: true)
                                if project.platform != .local {
                                    inspectorRow(label: "托管平台", value: project.platform.displayName)
                                }
                                if !project.currentBranch.isEmpty {
                                    inspectorRow(label: "当前分支", value: project.currentBranch, isMonospaced: true)
                                }
                                inspectorRow(label: "本地分支", value: "\(project.localBranches.count) 个")
                                inspectorRow(label: "中间段", value: appModel.localMergeContext?.config.mergeBranchMiddle ?? "-", isMonospaced: true)
                                inspectorRow(label: "环境分支", value: envBranchSummary)
                            }
                        }

                        inspectorCard(title: "本次执行计划", systemImage: "list.bullet.clipboard") {
                            VStack(alignment: .leading, spacing: 9) {
                                HStack(spacing: 8) {
                                    Text("模式:")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text(appModel.localOperationMode.rawValue)
                                        .font(.system(size: 11.5, weight: .semibold))
                                }

                                if appModel.localOperationMode.requiresSourceBranch {
                                    HStack(spacing: 8) {
                                        Text("源分支:")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        Text(appModel.localOperationSourceBranch.isEmpty ? "未选择" : appModel.localOperationSourceBranch)
                                            .font(.system(size: 11.5, design: .monospaced).weight(.medium))
                                            .foregroundStyle(appModel.localOperationSourceBranch.isEmpty ? .secondary : .primary)
                                    }
                                }

                                Divider()
                                    .opacity(0.5)

                                Text("预计执行流水线:")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)

                                if appModel.resolvedLocalOperationTargets.isEmpty {
                                    Text("尚未选定任何目标分支。")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                } else {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(Array(appModel.localOperationPreviewLines.enumerated()), id: \.offset) { index, line in
                                            if !line.isEmpty && !line.hasPrefix("项目:") && !line.hasPrefix("仓库路径:") && !line.hasPrefix("执行模式:") && !line.hasPrefix("即将执行:") {
                                                HStack(alignment: .top, spacing: 6) {
                                                    Image(systemName: "arrow.right.circle.fill")
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(Color.accentColor)
                                                        .padding(.top, 2)

                                                    Text(line)
                                                        .font(.system(size: 11, design: .monospaced))
                                                        .foregroundStyle(.primary)
                                                        .textSelection(.enabled)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        inspectorCard(title: "执行审计与结果", systemImage: "chart.bar.doc.horizontal") {
                            VStack(alignment: .leading, spacing: 9) {
                                HStack {
                                    if appModel.localOperation.isRunning {
                                        StatusPill(title: "正在执行中...", tint: .orange, systemImage: "hourglass")
                                    } else if let error = appModel.localOperation.errorMessage, !error.isEmpty {
                                        StatusPill(title: "执行发生错误", tint: .red, systemImage: "exclamationmark.triangle.fill")
                                    } else if appModel.localOperation.successMessage != nil {
                                        StatusPill(title: "执行成功", tint: .green, systemImage: "checkmark.circle.fill")
                                    } else {
                                        StatusPill(title: "待命", tint: .gray, systemImage: "clock")
                                    }

                                    Spacer()

                                    if !appModel.localOperation.logs.isEmpty {
                                        Button {
                                            appModel.copyLocalOperationLogs()
                                        } label: {
                                            Label("复制全部", systemImage: "doc.on.doc")
                                                .font(.system(size: 10.5))
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(Color.accentColor)
                                    }
                                }

                                if appModel.localOperation.logs.isEmpty {
                                    Text("执行完成后，这里将显示结构化审计记录。")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                } else {
                                    VStack(alignment: .leading, spacing: 5) {
                                        ForEach(Array(appModel.localOperation.logs.suffix(6).enumerated()), id: \.offset) { _, line in
                                            Text(line)
                                                .font(.system(size: 10.5, design: .monospaced))
                                                .foregroundStyle(line.contains("失败") || line.contains("错误") ? .red : .secondary)
                                                .lineLimit(2)
                                                .textSelection(.enabled)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView("未选择同步项目", systemImage: "arrow.triangle.branch")
            }
        }
    }

    // MARK: - Header Section

    private func headerSection(_ project: MergeProject) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("分支同步")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("/")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("本地项目")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(project.displayName)
                .font(.system(size: 16, weight: .semibold))
                .textSelection(.enabled)

            Text(appModel.localOperationMode.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                StatusPill(
                    title: appModel.localOperationMode.rawValue,
                    tint: .blue,
                    systemImage: appModel.localOperationMode.systemImage
                )

                StatusPill(
                    title: "\(appModel.resolvedLocalOperationTargets.count) 个目标",
                    tint: .purple,
                    systemImage: "arrow.triangle.branch"
                )

                if project.platform != .local {
                    StatusPill(
                        title: project.platform.badgeText,
                        tint: project.platform.tintColor,
                        systemImage: project.platform.icon
                    )
                }

                if !project.currentBranch.isEmpty {
                    StatusPill(
                        title: project.currentBranch,
                        tint: .green,
                        systemImage: "location.fill",
                        isMonospaced: true
                    )
                }
            }
            .padding(.top, 2)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Quick Actions

    private func quickActionRow(_ project: MergeProject) -> some View {
        HStack(spacing: 6) {
            Button {
                appModel.openProjectInIDE(project)
            } label: {
                Label(appModel.currentIDELabel, systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
            } label: {
                Label("访达", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                appModel.openProjectInTerminal(project)
            } label: {
                Label("终端", systemImage: "terminal")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                appModel.copyProjectPath(project)
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Inspector Components

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

    private var envBranchSummary: String {
        let envBranches = appModel.localMergeContext?.config.envBranches ?? []
        return envBranches.isEmpty ? "-" : envBranches.joined(separator: ", ")
    }
}
