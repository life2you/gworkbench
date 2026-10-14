import SwiftUI

struct BatchCreateMRSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var appModel = appModel

        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    mappingSelectionCard

                    if appModel.mrOperation.isRunning || appModel.mrOperation.errorMessage != nil {
                        InlineOperationView(state: appModel.mrOperation)
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }

            Divider()
            footerBar
        }
        .frame(minWidth: 640, idealWidth: 700, minHeight: 480, idealHeight: 540)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: "square.grid.3x1.folder.badge.plus")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("按环境映射批量创建 MR")
                    .font(.system(size: 14, weight: .semibold))

                HStack(spacing: 6) {
                    if let project = appModel.currentMergeProject {
                        Text(project.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        if project.platform != .local {
                            StatusPill(title: project.platform.badgeText, tint: project.platform.tintColor)
                        }
                    }
                }
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Mapping Selection Card

    private var mappingSelectionCard: some View {
        SectionCard(title: "环境分支合并映射选择") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("默认自动排除生产保护分支映射，仅勾选项将被批量推送到 GitLab 创建 MR。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("全选非保护") {
                        appModel.selectedBatchMRMappingIDs = Set(appModel.availableBatchMRMappings.map(\.id))
                    }
                    .controlSize(.small)

                    Button("清空") {
                        appModel.selectedBatchMRMappingIDs.removeAll()
                    }
                    .controlSize(.small)
                }

                if appModel.availableBatchMRMappings.isEmpty {
                    ContentUnavailableView("当前没有可批量创建的非保护分支映射", systemImage: "arrow.triangle.merge")
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 8) {
                        ForEach(appModel.availableBatchMRMappings, id: \.id) { mapping in
                            let isChecked = appModel.selectedBatchMRMappingIDs.contains(mapping.id)

                            Button {
                                if isChecked {
                                    appModel.selectedBatchMRMappingIDs.remove(mapping.id)
                                } else {
                                    appModel.selectedBatchMRMappingIDs.insert(mapping.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 14))
                                        .foregroundStyle(isChecked ? Color.accentColor : Color.secondary)

                                    HStack(spacing: 8) {
                                        Text(mapping.source)
                                            .font(.system(.body, design: .monospaced).weight(.medium))
                                            .foregroundStyle(.primary)

                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)

                                        Text(mapping.target)
                                            .font(.system(.body, design: .monospaced).weight(.semibold))
                                            .foregroundStyle(mapping.protectedTarget ? Color.orange : Color.primary)
                                    }

                                    Spacer()

                                    if mapping.protectedTarget {
                                        StatusPill(title: "受保护分支", tint: .orange, systemImage: "lock.fill")
                                    } else {
                                        StatusPill(title: "环境合流", tint: .green, systemImage: "checkmark")
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isChecked ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor).opacity(0.3))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isChecked ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.12), lineWidth: 0.5)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            Text("已勾选 \(appModel.selectedBatchMRMappingIDs.count) 组分支映射进行批量发起。")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()

            Button("取消") {
                dismiss()
            }
            .controlSize(.regular)

            Button {
                Task {
                    await appModel.createBatchMergeRequests()
                    if !appModel.showingBatchCreateMRSheet {
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if appModel.mrOperation.isRunning {
                        ProgressView().controlSize(.small)
                        Text("正在批量创建...")
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("批量创建选中 MR (\(appModel.selectedBatchMRMappingIDs.count))")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!appModel.canCreateSelectedBatchMRs || appModel.mrOperation.isRunning)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
