import SwiftUI

struct CreateMRSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var sourceBranchSearchText = ""
    @State private var targetBranchSearchText = ""

    var body: some View {
        @Bindable var appModel = appModel

        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 常用映射快速点选
                    if !appModel.availableMRMappings.isEmpty {
                        quickMappingsCard
                    }

                    // 来源分支与目标分支流向卡片
                    branchFlowCard

                    if isSelectedTargetProtected {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.orange)
                            Text("目标分支「\(appModel.createMRDraft.targetBranch)」为受保护分支，合并策略更谨慎。")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

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
        .frame(minWidth: 620, idealWidth: 660, minHeight: 460, idealHeight: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            syncBranchSelections()
        }
        .onChange(of: sourceBranchSearchText) { _, _ in
            syncSourceBranchSelection()
        }
        .onChange(of: targetBranchSearchText) { _, _ in
            syncTargetBranchSelection()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: "arrow.triangle.merge")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("新建合并请求 (Merge Request)")
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

    // MARK: - Quick Mappings Card

    private var quickMappingsCard: some View {
        SectionCard(title: "常用环境分支映射快捷填入") {
            VStack(alignment: .leading, spacing: 8) {
                Text("点击可直接一键将来源分支与目标分支同时填入下方表单:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(appModel.availableMRMappings) { mapping in
                            let isCurrent = appModel.createMRDraft.sourceBranch == mapping.source && appModel.createMRDraft.targetBranch == mapping.target

                            Button {
                                appModel.createMRDraft.sourceBranch = mapping.source
                                appModel.createMRDraft.targetBranch = mapping.target
                            } label: {
                                HStack(spacing: 5) {
                                    Text(mapping.source)
                                        .font(.system(size: 10.5, design: .monospaced))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                    Text(mapping.target)
                                        .font(.system(size: 10.5, design: .monospaced).weight(.medium))

                                    if mapping.protectedTarget {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(Color.orange)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isCurrent ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor))
                                .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(isCurrent ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isCurrent ? 1 : 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Branch Flow Card

    private var branchFlowCard: some View {
        @Bindable var appModel = appModel

        return SectionCard(title: "合并分支流向 (Branch Flow)") {
            VStack(alignment: .leading, spacing: 14) {
                // 来源分支
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("来源分支 (Source Branch)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("将以此分支为基础发起合入")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("快速过滤远程 origin 分支...", text: $sourceBranchSearchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5, design: .monospaced))

                        if !sourceBranchSearchText.isEmpty {
                            Button {
                                sourceBranchSearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                    Picker("来源分支", selection: $appModel.createMRDraft.sourceBranch) {
                        ForEach(filteredSourceBranchOptions, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                Divider().opacity(0.4)

                // 目标分支
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("目标分支 (Target Branch)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("代码最终合并的目标基线")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("快速过滤目标分支...", text: $targetBranchSearchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5, design: .monospaced))

                        if !targetBranchSearchText.isEmpty {
                            Button {
                                targetBranchSearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                    Picker("目标分支", selection: $appModel.createMRDraft.targetBranch) {
                        ForEach(filteredTargetBranchOptions, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            Text("将在 GitLab 上创建新合并请求，审批与合流操作在列表中进行。")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()

            Button("取消") {
                dismiss()
            }
            .controlSize(.regular)

            Button {
                Task {
                    await appModel.createMergeRequest()
                    if !appModel.showingCreateMRSheet {
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if appModel.mrOperation.isRunning {
                        ProgressView().controlSize(.small)
                        Text("正在创建...")
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("创建合并请求")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(appModel.createMRDraft.sourceBranch.isEmpty || appModel.createMRDraft.targetBranch.isEmpty || appModel.mrOperation.isRunning)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Helpers

    private var isSelectedTargetProtected: Bool {
        let target = appModel.createMRDraft.targetBranch
        return appModel.availableMRMappings.first(where: { $0.target == target })?.protectedTarget ?? false
    }

    private var sourceBranchOptions: [String] {
        appModel.availableMRSourceBranches
    }

    private var filteredSourceBranchOptions: [String] {
        filterBranches(sourceBranchOptions, query: sourceBranchSearchText)
    }

    private var targetBranchOptions: [String] {
        appModel.availableMRTargetBranches
    }

    private var filteredTargetBranchOptions: [String] {
        filterBranches(targetBranchOptions, query: targetBranchSearchText)
    }

    private func filterBranches(_ branches: [String], query: String) -> [String] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return branches
        }
        return branches.filter { $0.localizedCaseInsensitiveContains(normalizedQuery) }
    }

    private func syncBranchSelections() {
        syncSourceBranchSelection()
        syncTargetBranchSelection()
    }

    private func syncSourceBranchSelection() {
        if filteredSourceBranchOptions.contains(appModel.createMRDraft.sourceBranch) {
            return
        }
        appModel.createMRDraft.sourceBranch = filteredSourceBranchOptions.first ?? ""
    }

    private func syncTargetBranchSelection() {
        if filteredTargetBranchOptions.contains(appModel.createMRDraft.targetBranch) {
            return
        }
        appModel.createMRDraft.targetBranch = filteredTargetBranchOptions.first ?? ""
    }
}
