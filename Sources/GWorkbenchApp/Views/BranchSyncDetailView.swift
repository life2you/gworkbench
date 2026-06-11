import SwiftUI

struct BranchSyncDetailView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if let project = appModel.currentLocalMergeProject {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(project)

                        SectionCard(title: "项目概览") {
                            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                                DetailLabelRow(title: "项目", value: project.displayName)
                                DetailLabelRow(title: "仓库路径", value: project.path)
                                DetailLabelRow(title: "本地分支数", value: "\(project.localBranches.count)")
                                DetailLabelRow(title: "merge 中间段", value: appModel.localMergeContext?.config.mergeBranchMiddle ?? "-")
                                DetailLabelRow(title: "环境分支", value: envBranchSummary)
                            }
                        }

                        SectionCard(title: "本次计划") {
                            VStack(alignment: .leading, spacing: 10) {
                                DetailLabelRow(title: "模式", value: appModel.localOperationMode.rawValue)
                                if appModel.localOperationMode.requiresSourceBranch {
                                    DetailLabelRow(
                                        title: "源分支",
                                        value: appModel.localOperationSourceBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                            ? "未选择"
                                            : appModel.localOperationSourceBranch
                                    )
                                }
                                DetailLabelRow(title: "目标分支", value: targetSummary)
                            }
                        }

                        SectionCard(title: "执行预览") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(appModel.localOperationPreviewLines.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(.subheadline, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                            }
                        }

                        SectionCard(title: "最近结果") {
                            if appModel.localOperation.logs.isEmpty {
                                Text("执行完成后，这里会显示完整结果。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(appModel.localOperation.logs.enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(.system(.subheadline, design: .monospaced))
                                            .foregroundStyle(line.hasPrefix("失败:") ? .red : .primary)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView("未选择同步项目", systemImage: "arrow.triangle.branch")
            }
        }
    }

    private func header(_ project: MergeProject) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分支同步")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(project.displayName)
                .font(.largeTitle.weight(.semibold))
            Text(appModel.localOperationMode.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                StatusPill(title: appModel.localOperationMode.rawValue, tint: .blue)
                StatusPill(title: "\(appModel.resolvedLocalOperationTargets.count) 个目标", tint: .purple)
            }
        }
    }

    private var envBranchSummary: String {
        let envBranches = appModel.localMergeContext?.config.envBranches ?? []
        return envBranches.isEmpty ? "-" : envBranches.joined(separator: ", ")
    }

    private var targetSummary: String {
        let targets = appModel.resolvedLocalOperationTargets
        return targets.isEmpty ? "未选择" : targets.joined(separator: ", ")
    }
}
