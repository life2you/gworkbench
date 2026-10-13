import SwiftUI
import AppKit

struct BranchSyncView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isConsoleExpanded: Bool = true
    @State private var consoleHeight: CGFloat = 160

    var body: some View {
        @Bindable var appModel = appModel

        VStack(spacing: 0) {
            toolbarHeader
            Divider()

            if appModel.localMergeProjects.isEmpty {
                ContentUnavailableView("未检测到本地项目", systemImage: "arrow.triangle.branch")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if appModel.localOperation.isRunning || appModel.localOperation.errorMessage != nil || appModel.localOperation.successMessage != nil {
                            InlineOperationView(state: appModel.localOperation)
                                .padding(12)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                                )
                        }

                        modeHeroCard

                        if appModel.localOperationMode.requiresSourceBranch {
                            sourceBranchCard
                        }

                        targetPipelineCard
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                consoleDrawer
                Divider()
                statusBar
            }
        }
    }

    // MARK: - Toolbar Header

    private var toolbarHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                if appModel.availablePlatforms.count > 2 {
                    platformMenu
                }

                Picker("项目", selection: localProjectBinding) {
                    ForEach(appModel.filteredLocalMergeProjects) { project in
                        Text("\(project.platform == .github ? "🐙 " : (project.platform == .gitlab ? "🦊 " : ""))\(project.displayName)").tag(Optional(project.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 150, maxWidth: 200)
            }

            Divider()
                .frame(height: 18)
                .padding(.horizontal, 2)

            Picker("执行模式", selection: localOperationModeBinding) {
                ForEach(LocalBranchOperationMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 380)

            Spacer(minLength: 8)

            Button {
                Task {
                    await appModel.refreshLocalMergeProjects()
                }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .help("重新读取本地项目分支与环境配置")

            Button {
                Task {
                    await appModel.executeLocalOperation()
                }
            } label: {
                HStack(spacing: 5) {
                    if appModel.localOperation.isRunning {
                        ProgressView()
                            .controlSize(.small)
                        Text("执行中...")
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("开始执行")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!appModel.canExecuteLocalOperation || appModel.localOperation.isRunning)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Mode Hero Card

    private var modeHeroCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
                Image(systemName: appModel.localOperationMode.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(appModel.localOperationMode.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                    StatusPill(title: appModel.localOperationMode.id, tint: .blue)
                }
                Text(appModel.localOperationMode.detailedDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
        )
    }

    // MARK: - Source Branch Card

    private var sourceBranchCard: some View {
        SectionCard(title: "源分支 (Source Branch)") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("筛选或搜索本地源分支...", text: localBranchSearchBinding)
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                        if !appModel.localBranchSearchText.isEmpty {
                            Button {
                                appModel.localBranchSearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                    if let current = appModel.currentLocalMergeProject?.currentBranch, !current.isEmpty {
                        Button {
                            appModel.selectCurrentHeadAsLocalSourceBranch()
                        } label: {
                            Label("选中当前 HEAD (\(current))", systemImage: "location.fill")
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                    }
                }

                // 快速分支胶囊列表
                if !appModel.filteredLocalBranches.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("候选分支")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(appModel.filteredLocalBranches.prefix(12)), id: \.self) { branch in
                                    let isSelected = appModel.localOperationSourceBranch == branch
                                    let isCurrentHead = appModel.currentLocalMergeProject?.currentBranch == branch

                                    Button {
                                        appModel.localOperationSourceBranch = branch
                                    } label: {
                                        HStack(spacing: 5) {
                                            if isCurrentHead {
                                                Circle()
                                                    .fill(Color.green)
                                                    .frame(width: 6, height: 6)
                                            }
                                            Text(branch)
                                                .font(.system(size: 11, design: .monospaced))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(isSelected ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor).opacity(0.6))
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1 : 0.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                if appModel.filteredLocalBranches.isEmpty {
                    Text("当前项目没有匹配的本地分支。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("源分支精确选择", selection: localOperationSourceBranchBinding) {
                        ForEach(appModel.filteredLocalBranches, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Target Pipeline Flow Card

    private var targetPipelineCard: some View {
        SectionCard(title: "目标分支流向 (Target Flow)") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(targetPipelineHeaderSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if appModel.localOperationMode == .mergeCustom {
                        HStack(spacing: 10) {
                            Button("全选") {
                                appModel.selectAllLocalCustomTargets()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.accentColor)

                            Text("•")
                                .foregroundStyle(.tertiary)

                            Button("全不选") {
                                appModel.deselectAllLocalCustomTargets()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                        }
                    }

                    Text("已选 \(appModel.resolvedLocalOperationTargets.count) 个目标")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if appModel.localTargetOptions.isEmpty {
                    Text("当前项目尚未配置可用的环境合并映射。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(appModel.localTargetOptions) { option in
                            targetPipelineRow(for: option)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func targetPipelineRow(for option: LocalBranchTargetOption) -> some View {
        let isSelected = isTargetSelected(option.targetBranch)

        Button {
            handleTargetSelection(option.targetBranch)
        } label: {
            HStack(spacing: 12) {
                // 左侧选择指示器
                Group {
                    switch appModel.localOperationMode {
                    case .syncEnvironments, .mergeAll:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                    case .mergeCustom:
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    }
                }
                .font(.system(size: 14))

                // 流向拓扑：[环境分支] -> [目标分支]
                HStack(spacing: 8) {
                    StatusPill(title: option.envBranch, tint: .purple)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text(option.targetBranch)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                // 状态指示
                StatusPill(
                    title: isSelected ? "就绪" : "已跳过",
                    tint: isSelected ? .green : .gray,
                    systemImage: isSelected ? "checkmark" : "minus"
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor).opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.12), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var targetPipelineHeaderSubtitle: String {
        switch appModel.localOperationMode {
        case .syncEnvironments:
            return "将依次拉取环境最新提交，再同步推送至对应合并分支。"
        case .mergeAll:
            return "将把当前源分支依次合并到下列全部目标分支并推送。"
        case .mergeCustom:
            return "点击勾选本次要参与合并的目标分支（支持单个或多个）。"
        }
    }

    private func isTargetSelected(_ target: String) -> Bool {
        switch appModel.localOperationMode {
        case .syncEnvironments, .mergeAll:
            return true
        case .mergeCustom:
            return appModel.localOperationCustomTargets.contains(target)
        }
    }

    private func handleTargetSelection(_ target: String) {
        switch appModel.localOperationMode {
        case .syncEnvironments, .mergeAll:
            break
        case .mergeCustom:
            appModel.toggleCustomLocalTarget(target)
        }
    }

    // MARK: - Console Drawer

    private var consoleDrawer: some View {
        VStack(spacing: 0) {
            // 控制台标题栏
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isConsoleExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isConsoleExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Image(systemName: "terminal.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)

                Text("执行控制台")
                    .font(.system(size: 11.5, weight: .semibold))

                Text("|")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 10))

                Text(appModel.localOperation.detail.isEmpty ? "就绪待命" : appModel.localOperation.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        appModel.copyLocalOperationLogs()
                    } label: {
                        Text("复制日志")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)

                    Button {
                        appModel.clearLocalOperationLogs()
                    } label: {
                        Text("清空")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Color(NSColor.windowBackgroundColor))

            if isConsoleExpanded {
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            if appModel.localOperation.logs.isEmpty {
                                Text("等待执行... 开始执行后将实时输出 Git 命令与操作日志。")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(8)
                            } else {
                                ForEach(Array(appModel.localOperation.logs.enumerated()), id: \.offset) { index, line in
                                    Text(line)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(logColor(for: line))
                                        .textSelection(.enabled)
                                        .id(index)
                                }
                                .padding(8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(NSColor.textBackgroundColor).opacity(0.3))
                    .onChange(of: appModel.localOperation.logs.count) { _, newCount in
                        if newCount > 0 {
                            proxy.scrollTo(newCount - 1, anchor: .bottom)
                        }
                    }
                }
                .frame(height: consoleHeight)
            }
        }
    }

    private func logColor(for line: String) -> Color {
        if line.contains("失败") || line.contains("错误") || line.contains("Error") {
            return .red
        } else if line.contains("成功") || line.contains("完成") {
            return .green
        } else if line.contains("开始执行") || line.contains("检出") || line.contains("push") {
            return .accentColor
        }
        return .primary
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                Circle()
                    .fill(appModel.localOperation.isRunning ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text(appModel.localOperation.isRunning ? "执行中" : "就绪")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text("•")
                .foregroundStyle(.tertiary)

            if appModel.localOperationMode.requiresSourceBranch {
                HStack(spacing: 4) {
                    Text("源分支:")
                        .foregroundStyle(.tertiary)
                    Text(appModel.localOperationSourceBranch.isEmpty ? "未选择" : appModel.localOperationSourceBranch)
                        .font(.system(size: 10.5, design: .monospaced).weight(.medium))
                }
                Text("•")
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 4) {
                Text("待同步目标:")
                    .foregroundStyle(.tertiary)
                Text("\(appModel.resolvedLocalOperationTargets.count) 个")
                    .font(.system(size: 10.5, weight: .medium))
            }

            Spacer()

            Text("GWorkbench • Git Engine")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Bindings

    private var platformMenu: some View {
        Menu {
            ForEach(appModel.availablePlatforms) { p in
                Button {
                    appModel.selectedPlatformFilter = p
                } label: {
                    HStack {
                        Text(p.displayName)
                        if appModel.selectedPlatformFilter == p {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: appModel.selectedPlatformFilter.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(appModel.selectedPlatformFilter.tintColor)
                Text(appModel.selectedPlatformFilter.shortName)
                    .font(.system(size: 11.5, weight: .medium))
            }
        }
        .menuStyle(.borderedButton)
        .controlSize(.small)
        .fixedSize()
    }

    private var localOperationModeBinding: Binding<LocalBranchOperationMode> {
        Binding(
            get: { appModel.localOperationMode },
            set: { appModel.setLocalOperationMode($0) }
        )
    }

    private var localBranchSearchBinding: Binding<String> {
        Binding(
            get: { appModel.localBranchSearchText },
            set: { appModel.localBranchSearchText = $0 }
        )
    }

    private var localOperationSourceBranchBinding: Binding<String> {
        Binding(
            get: { appModel.localOperationSourceBranch },
            set: { appModel.localOperationSourceBranch = $0 }
        )
    }

    private var platformFilterBinding: Binding<RepositoryPlatform> {
        Binding(
            get: { appModel.selectedPlatformFilter },
            set: { appModel.selectedPlatformFilter = $0 }
        )
    }

    private var localProjectBinding: Binding<String?> {
        Binding(
            get: { appModel.selectedLocalProjectID },
            set: { if let value = $0 { appModel.selectLocalProject(value) } }
        )
    }
}
