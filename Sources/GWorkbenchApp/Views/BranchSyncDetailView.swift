import SwiftUI
import AppKit

struct BranchSyncDetailView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if let project = appModel.currentLocalMergeProject {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        InspectorHeaderView(
                            title: "同步流水线",
                            subtitleItems: [project.displayName, appModel.activePlatform.shortName],
                            trailingPill: queueStatusPill
                        )

                        projectSummaryCard(project)

                        pipelineStepsCard

                        actionsSection(project)

                        executionSummaryCard
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView("未选择同步项目", systemImage: "arrow.triangle.branch")
            }
        }
    }

    // MARK: - Status Pill

    private var queueStatusPill: StatusPill {
        if appModel.localOperation.isRunning {
            return StatusPill(title: "执行中", tint: .blue)
        }
        if appModel.localOperation.errorMessage != nil {
            return StatusPill(title: "需要关注", tint: .orange)
        }
        if let session = appModel.activeSyncSession,
           !session.targets.isEmpty,
           session.targets.allSatisfy({
               if case .success = $0.status { return true }
               return false
           }) {
            return StatusPill(title: "全部成功", tint: .green)
        }
        let count = appModel.resolvedLocalOperationTargets.count
        return StatusPill(
            title: count > 0 ? "就绪 · \(count) 个目标" : "未选目标",
            tint: count > 0 ? .teal : .gray
        )
    }

    // MARK: - Card 1: 仓库信息

    private func projectSummaryCard(_ project: MergeProject) -> some View {
        InspectorCard(title: "仓库信息") {
            VStack(alignment: .leading, spacing: 7) {
                InspectorKeyValueRow(label: "路径", value: project.path, isMonospaced: true, canCopy: true)
                if !project.currentBranch.isEmpty {
                    InspectorKeyValueRow(label: "当前分支", value: project.currentBranch, isMonospaced: true)
                }
                InspectorKeyValueRow(label: "本地分支", value: "\(project.localBranches.count) 个")
                InspectorKeyValueRow(label: "同步模式", value: appModel.localOperationMode.rawValue)
            }
        }
    }

    // MARK: - Card 2: 目标队列

    private var pipelineStepsCard: some View {
        let targetCount = appModel.activeSyncSession?.targets.count ?? appModel.resolvedLocalOperationTargets.count

        return InspectorCard(
            title: "目标队列",
            trailing: {
                if targetCount > 0 {
                    StatusPill(title: "\(targetCount) 个分支", tint: .secondary)
                }
            }
        ) {
            if let session = appModel.activeSyncSession {
                VStack(spacing: 6) {
                    ForEach(session.targets) { item in
                        stepRow(
                            icon: pipelineIcon(for: item.status),
                            iconColor: item.status.tintColor,
                            target: item.targetBranch,
                            pillTitle: item.status.displayLabel,
                            pillTint: item.status.tintColor
                        )
                    }
                }
            } else if !appModel.resolvedLocalOperationTargets.isEmpty {
                VStack(spacing: 6) {
                    ForEach(appModel.resolvedLocalOperationTargets, id: \.self) { target in
                        stepRow(
                            icon: "hourglass",
                            iconColor: .secondary,
                            target: target,
                            pillTitle: "等待中",
                            pillTint: .gray
                        )
                    }
                }
            } else {
                Text("请在左侧选择至少一个目标分支以预览同步流水线。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stepRow(
        icon: String,
        iconColor: Color,
        target: String,
        pillTitle: String,
        pillTint: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11.5))
                .foregroundStyle(iconColor)
            Text(target)
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .lineLimit(1)
            Spacer()
            StatusPill(title: pillTitle, tint: pillTint)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(pillTint == .gray ? Color.secondary.opacity(0.14) : pillTint.opacity(0.32), lineWidth: 0.75)
        )
    }

    // MARK: - Actions Section

    private func actionsSection(_ project: MergeProject) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            InspectorActionGroupLabel(title: "同步与打开")

            Button {
                Task {
                    await appModel.executeLocalOperation()
                }
            } label: {
                Label(
                    appModel.localOperation.isRunning ? "正在执行同步..." : "开始执行同步",
                    systemImage: appModel.localOperation.isRunning ? "arrow.triangle.2.circlepath" : "play.fill"
                )
            }
            .buttonStyle(InspectorActionButtonStyle(tone: .primary))
            .disabled(!appModel.canExecuteLocalOperation)

            HStack(spacing: 8) {
                IDEOpenSplitButton(
                    profiles: appModel.configuredIDEProfiles,
                    defaultProfile: appModel.defaultIDEProfile,
                    tone: .secondary,
                    onOpen: { ide in
                        appModel.openProjectInIDE(project, ide: ide)
                    },
                    onManageIDEs: {
                        appModel.showingSettingsSheet = true
                    }
                )

                Button {
                    appModel.openProjectInTerminal(project)
                } label: {
                    Label("终端打开", systemImage: "terminal")
                }
                .buttonStyle(InspectorActionButtonStyle(tone: .secondary))
            }

            HStack(spacing: 8) {
                Button {
                    appModel.openProjectInRebased(project)
                } label: {
                    Label("Rebased", systemImage: "arrow.triangle.merge")
                }
                .buttonStyle(InspectorActionButtonStyle(tone: .secondary))

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
                } label: {
                    Label("在访达显示", systemImage: "folder")
                }
                .buttonStyle(InspectorActionButtonStyle(tone: .secondary))
            }

            InspectorActionGroupLabel(title: "流程流转")

            Button {
                appModel.selectedSection = .mergeDashboard
            } label: {
                Label("前往看板检查合入", systemImage: "chart.bar.xaxis")
            }
            .buttonStyle(InspectorActionButtonStyle(tone: .accent(.teal)))

            if appModel.activePlatform != .local {
                Button {
                    let sourceBranch = appModel.localOperationSourceBranch.trimmedNonEmpty ?? project.currentBranch
                    appModel.openCreateMR(forBranch: sourceBranch, projectPath: project.path)
                } label: {
                    Label("为此项目创建 \(appModel.requestShortLabel)", systemImage: "arrow.triangle.pull")
                }
                .buttonStyle(InspectorActionButtonStyle(tone: .accent(.purple)))
            }
        }
    }

    // MARK: - Card 3: 最近运行摘要

    private var executionSummaryCard: some View {
        InspectorCard(
            title: "最近运行摘要",
            trailing: {
                if !appModel.localOperation.logs.isEmpty {
                    Button {
                        appModel.copyLocalOperationLogs()
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                            .font(.system(size: 10.5))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
        ) {
            if appModel.localOperation.logs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    if appModel.localOperationMode.requiresSourceBranch, !appModel.localOperationSourceBranch.isEmpty {
                        Text("> source: \(appModel.localOperationSourceBranch)")
                    }
                    Text("> 等待确认开始（完整输出见左下控制台）")
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(appModel.localOperation.logs.suffix(5).enumerated()), id: \.offset) { _, line in
                        Text("> \(line)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(
                                line.contains("冲突") || line.contains("CONFLICT") ? Color.orange :
                                (line.contains("失败") || line.contains("错误") ? Color.red : Color.secondary)
                            )
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func pipelineIcon(for status: SyncTargetStatus) -> String {
        switch status {
        case .pending: return "hourglass"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark.square.fill"
        case .skippedDueToConflict: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.octagon.fill"
        }
    }
}
