import SwiftUI
import AppKit

struct SidebarRowButton: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var badge: String?
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13))
                        .frame(width: 16)
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if let badge, !badge.isEmpty {
                    CountBadge(value: badge)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PlatformBadge: View {
    let platform: RepositoryPlatform

    var body: some View {
        HStack(spacing: 2) {
            Text(platform.shortName)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(platform.tintColor.opacity(0.15))
        .foregroundStyle(platform.tintColor)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

struct CountBadge: View {
    let value: String

    var body: some View {
        Text(value)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
    }
}

struct StatusPill: View {
    let title: String
    let tint: Color
    var systemImage: String? = nil
    var isMonospaced: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(title)
                .font(isMonospaced ? .system(size: 11, weight: .medium, design: .monospaced) : .system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12))
        .foregroundStyle(tint)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(tint.opacity(0.25), lineWidth: 0.5)
        )
    }
}

struct InlineOperationView: View {
    let state: OperationState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(state.title)
                    .font(.subheadline.weight(.semibold))
                if state.isRunning {
                    ProgressView(value: state.fractionCompleted)
                        .frame(width: 120)
                } else if state.errorMessage != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                } else if state.successMessage != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Text(state.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let errorMessage = state.errorMessage, !errorMessage.isEmpty, errorMessage != state.detail {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else if let successMessage = state.successMessage, !successMessage.isEmpty {
                Text(successMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if !state.logs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(state.logs.suffix(5).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DetailLabelRow: View {
    let title: String
    let value: String

    var body: some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ResizeUpDownCursorView: NSViewRepresentable {
    func makeNSView(context: Context) -> TrackingNSView {
        TrackingNSView()
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {}

    final class TrackingNSView: NSView {
        override func resetCursorRects() {
            discardCursorRects()
            addCursorRect(bounds, cursor: .resizeUpDown)
        }
    }
}

struct ResizeHandleView: View {
    @Environment(AppModel.self) private var appModel
    @State private var startHeight: CGFloat = 220
    @State private var isDragging: Bool = false
    @State private var isHovering: Bool = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(NSColor.separatorColor).opacity(isDragging || isHovering ? 0.8 : 0.35))
                .frame(height: 1)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(isDragging ? Color.accentColor : (isHovering ? Color.secondary : Color.secondary.opacity(0.35)))
                .frame(width: 38, height: 3)
        }
        .frame(height: 7)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.01))
        .contentShape(Rectangle())
        .overlay(ResizeUpDownCursorView())
        .onHover { isHovering = $0 }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        startHeight = appModel.consolePanelHeight
                    }
                    let newHeight = startHeight - value.translation.height
                    appModel.consolePanelHeight = min(max(newHeight, 150), 450)
                    if appModel.isConsoleCollapsed {
                        appModel.isConsoleCollapsed = false
                    }
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
}

struct WorktreeConsolePanelView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isMaximized: Bool = false
    @State private var preMaximizeHeight: CGFloat = 220

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            if !appModel.isConsoleCollapsed {
                Divider()
                activeTabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: appModel.isConsoleCollapsed ? 32 : appModel.consolePanelHeight)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    appModel.isConsoleCollapsed.toggle()
                }
            } label: {
                Image(systemName: appModel.isConsoleCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .help(appModel.isConsoleCollapsed ? "展开控制台" : "折叠控制台")

            HStack(spacing: 2) {
                ForEach(WorkbenchConsoleTab.allCases) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(2)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if let branch = currentTargetBranch {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 9))
                    Text(branch)
                        .font(.system(size: 10, design: .monospaced))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.secondary)
            }

            if appModel.isLoadingConsoleDetails {
                ProgressView()
                    .controlSize(.mini)
            }

            Spacer()

            if appModel.activeConsoleTab == .logs && !appModel.worktreeOperation.logs.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        appModel.worktreeOperation.logs.joined(separator: "\n"),
                        forType: .string
                    )
                } label: {
                    Label("复制日志", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("复制所有控制台输出")

                Button {
                    appModel.clearWorktreeLogs()
                } label: {
                    Label("清空", systemImage: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("清空控制台日志")
            }

            Button {
                appModel.syncSelectedWorktreeDetails()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("刷新当前工作树状态与改动")

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isMaximized {
                        appModel.consolePanelHeight = preMaximizeHeight
                        isMaximized = false
                    } else {
                        preMaximizeHeight = appModel.consolePanelHeight
                        appModel.consolePanelHeight = 450
                        isMaximized = true
                    }
                    if appModel.isConsoleCollapsed {
                        appModel.isConsoleCollapsed = false
                    }
                }
            } label: {
                Image(systemName: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(isMaximized ? "还原面板高度" : "最大化面板高度 (450pt)")
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var currentTargetBranch: String? {
        if let selected = appModel.selectedWorktree {
            return selected.branch
        }
        return appModel.currentWorktreeProject?.currentBranch
    }

    private func tabButton(for tab: WorkbenchConsoleTab) -> some View {
        let isSelected = appModel.activeConsoleTab == tab

        return Button {
            appModel.activeConsoleTab = tab
            if appModel.isConsoleCollapsed {
                appModel.isConsoleCollapsed = false
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10))

                Text(tab.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))

                tabBadge(for: tab)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(isSelected ? Color(NSColor.controlBackgroundColor) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .shadow(color: isSelected ? Color.black.opacity(0.08) : Color.clear, radius: 1, y: 0.5)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tabBadge(for tab: WorkbenchConsoleTab) -> some View {
        switch tab {
        case .changes:
            let count = appModel.selectedWorktreeFileChanges.count
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
        case .syncRadar:
            if let ab = appModel.selectedWorktreeAheadBehind, (ab.ahead > 0 || ab.behind > 0) {
                HStack(spacing: 2) {
                    if ab.ahead > 0 {
                        Text("↑\(ab.ahead)")
                    }
                    if ab.behind > 0 {
                        Text("↓\(ab.behind)")
                    }
                }
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.blue)
                .clipShape(Capsule())
            }
        case .logs:
            if appModel.worktreeOperation.isRunning {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 5, height: 5)
            } else if appModel.worktreeOperation.errorMessage != nil {
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
            }
        case .quickScripts:
            EmptyView()
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var activeTabContent: some View {
        switch appModel.activeConsoleTab {
        case .changes:
            ConsoleChangesTabView()
        case .syncRadar:
            ConsoleSyncRadarTabView()
        case .logs:
            ConsoleLogsTabView()
        case .quickScripts:
            ConsoleQuickScriptsTabView()
        }
    }
}

// MARK: - Tab 1: 改动文件

struct ConsoleChangesTabView: View {
    @Environment(AppModel.self) private var appModel
    @State private var hoveredPath: String? = nil

    var body: some View {
        if appModel.selectedWorktree == nil {
            ContentUnavailableView("未选择工作树", systemImage: "folder.badge.questionmark", description: Text("在上方表格中选择工作树后查看文件改动"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if appModel.selectedWorktreeFileChanges.isEmpty {
            if appModel.isLoadingConsoleDetails {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在检查工作树改动...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                cleanStateView
            }
        } else {
            changesListView
        }
    }

    private var cleanStateView: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)
            Text("工作区纯净")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            Text("当前工作树没有未提交的代码改动或未跟踪文件")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var changesListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("改动清单 (共 \(appModel.selectedWorktreeFileChanges.count) 个文件)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if let item = appModel.selectedWorktree {
                    if appModel.configuredIDEProfiles.count > 1 {
                        HStack(spacing: 6) {
                            Button {
                                appModel.openWorktreeInIDE(item)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.up.forward.app")
                                    Text("在 \(appModel.defaultIDEProfile.effectiveLabel) 中打开整个工作树")
                                }
                                .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)

                            Menu {
                                ForEach(appModel.configuredIDEProfiles) { ide in
                                    Button {
                                        appModel.openWorktreeInIDE(item, ide: ide)
                                    } label: {
                                        if ide.id == appModel.defaultIDEProfile.id {
                                            Label("\(ide.effectiveLabel)（默认）", systemImage: "star.fill")
                                        } else {
                                            Label(ide.effectiveLabel, systemImage: "macwindow")
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            .help("选择其他已配置的编辑器打开工作树")
                        }
                    } else {
                        Button {
                            appModel.openWorktreeInIDE(item)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.up.forward.app")
                                Text("在 IDE 中打开整个工作树")
                            }
                            .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            ScrollView(.vertical) {
                LazyVStack(spacing: 1) {
                    ForEach(appModel.selectedWorktreeFileChanges) { change in
                        fileRow(for: change)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func fileRow(for change: WorktreeFileChange) -> some View {
        let isHovered = hoveredPath == change.path

        return HStack(spacing: 8) {
            badgeView(for: change)

            Text(change.path)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(change.primaryBadgeCode == "D" ? .secondary : .primary)

            Spacer()

            Text(change.statusSummary)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Button {
                    appModel.openFileInIDE(path: change.path)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .help("在 IDE 中打开此文件")

                Button {
                    appModel.copyFilePath(change.path, relative: true)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("复制相对路径")
            }
            .opacity(isHovered ? 1.0 : 0.0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isHovered ? Color.secondary.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onHover { isHover in
            if isHover {
                hoveredPath = change.path
            } else if hoveredPath == change.path {
                hoveredPath = nil
            }
        }
        .onTapGesture(count: 2) {
            appModel.openFileInIDE(path: change.path)
        }
        .contextMenu {
            IDEOpenContextMenuContent(
                profiles: appModel.configuredIDEProfiles,
                defaultProfile: appModel.defaultIDEProfile,
                onOpen: { ide in
                    appModel.openFileInIDE(path: change.path, ide: ide)
                }
            )
            Button("复制相对路径") {
                appModel.copyFilePath(change.path, relative: true)
            }
            Button("复制完整物理路径") {
                appModel.copyFilePath(change.path, relative: false)
            }
            if let item = appModel.selectedWorktree {
                Button("在 Finder 中显示") {
                    let fullURL = URL(fileURLWithPath: item.path).appendingPathComponent(change.path)
                    NSWorkspace.shared.activateFileViewerSelecting([fullURL])
                }
            }
        }
    }

    private func badgeView(for change: WorktreeFileChange) -> some View {
        let code = change.primaryBadgeCode
        let tint: Color
        let bg: Color
        switch code {
        case "M":
            tint = .orange
            bg = Color.orange.opacity(0.18)
        case "A":
            tint = .green
            bg = Color.green.opacity(0.18)
        case "D":
            tint = .red
            bg = Color.red.opacity(0.18)
        case "??":
            tint = .purple
            bg = Color.purple.opacity(0.18)
        case "UU":
            tint = .red
            bg = Color.red.opacity(0.28)
        default:
            tint = .secondary
            bg = Color.secondary.opacity(0.14)
        }

        return Text(code)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(tint)
            .frame(minWidth: 22, minHeight: 16)
            .padding(.horizontal, 3)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Tab 2: 分支同步雷达

struct ConsoleSyncRadarTabView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        if let item = appModel.selectedWorktree {
            radarContent(for: item)
        } else {
            ContentUnavailableView("未选择工作树", systemImage: "arrow.triangle.branch", description: Text("在上方表格中选择工作树以查看分支同步雷达"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func radarContent(for item: WorktreeItem) -> some View {
        let aheadCount = appModel.selectedWorktreeAheadBehind?.ahead ?? 0
        let behindCount = appModel.selectedWorktreeAheadBehind?.behind ?? 0
        let isRunning = appModel.worktreeOperation.isRunning

        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(item.kind == .mainRepo ? Color.blue : Color.purple)
                    Text(item.branch)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                HStack(spacing: 4) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(item.upstream == "未配置" ? Color.orange : Color.blue)
                    Text(item.upstream == "未配置" ? "未配置跟踪上游" : item.upstream)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(item.upstream == "未配置" ? .secondary : .primary)
                }

                Spacer()

                StatusPill(
                    title: item.dirtySummary,
                    tint: item.isDirty ? .orange : .green,
                    systemImage: item.isDirty ? "pencil.circle.fill" : "checkmark.circle.fill"
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(aheadCount > 0 ? Color.orange : Color.secondary)
                        Text("待推送提交 (Ahead)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(aheadCount)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(aheadCount > 0 ? Color.orange : Color.secondary)
                    }
                    Text(aheadCount > 0 ? "本地有 \(aheadCount) 个提交尚未推送至远端" : "本地提交已全部推送到远程")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(aheadCount > 0 ? Color.orange.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(behindCount > 0 ? Color.blue : Color.secondary)
                        Text("待拉取提交 (Behind)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(behindCount)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(behindCount > 0 ? Color.blue : Color.secondary)
                    }
                    Text(behindCount > 0 ? "远程有 \(behindCount) 个提交待拉取到本地" : "本地分支已是最新，无待拉取提交")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(behindCount > 0 ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1)
                )
            }

            HStack(spacing: 8) {
                Button {
                    Task {
                        await appModel.fetchSelectedWorktree()
                    }
                } label: {
                    Label("Git Fetch", systemImage: "arrow.clockwise")
                }
                .disabled(isRunning)

                Button {
                    Task {
                        await appModel.pullSelectedWorktree()
                    }
                } label: {
                    Label("Git Pull", systemImage: "arrow.down")
                }
                .disabled(isRunning)

                Button {
                    Task {
                        await appModel.pushSelectedWorktree()
                    }
                } label: {
                    Label("Git Push", systemImage: "arrow.up")
                }
                .disabled(isRunning)

                if isRunning {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text(appModel.worktreeOperation.title)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("更新于: \(item.updatedAt)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 2)

            Spacer()
        }
        .padding(10)
    }
}

// MARK: - Tab 3: 执行日志

struct ConsoleLogsTabView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 3) {
                    if appModel.worktreeOperation.logs.isEmpty {
                        Text("控制台就绪，暂无输出日志。在表格中快捷操作或新建工作树将在此打印输出。")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color(white: 0.55))
                            .padding(.top, 6)
                    } else {
                        ForEach(Array(appModel.worktreeOperation.logs.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(color(for: line))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(red: 0.08, green: 0.09, blue: 0.11))
            .onChange(of: appModel.worktreeOperation.logs.count) {
                if let lastIndex = appModel.worktreeOperation.logs.indices.last {
                    withAnimation {
                        proxy.scrollTo(lastIndex, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func color(for log: String) -> Color {
        if log.contains("失败") || log.contains("错误") || log.contains("fatal") || log.contains("error") || log.contains("Error") {
            return Color(red: 1.0, green: 0.45, blue: 0.45)
        }
        if log.contains("成功") || log.contains("已创建") || log.contains("完成") || log.contains("就绪") {
            return Color(red: 0.4, green: 0.85, blue: 0.55)
        }
        if log.hasPrefix("项目:") || log.hasPrefix("分支:") || log.hasPrefix("路径:") {
            return Color(red: 0.45, green: 0.75, blue: 1.0)
        }
        return Color(white: 0.86)
    }
}

// MARK: - Tab 4: 快捷脚本

struct ConsoleQuickScriptsTabView: View {
    @Environment(AppModel.self) private var appModel

    struct ScriptEntry: Identifiable, Sendable {
        let id: String
        let title: String
        let description: String
        let commandMaker: @Sendable (String) -> String
    }

    private let scripts: [ScriptEntry] = [
        ScriptEntry(
            id: "cd",
            title: "进入工作树目录",
            description: "在终端定位切换到工作树物理根目录",
            commandMaker: { path in "cd \"\(path)\"" }
        ),
        ScriptEntry(
            id: "status",
            title: "简短状态检查",
            description: "紧凑展示当前工作树与暂存区改动",
            commandMaker: { _ in "git status -s" }
        ),
        ScriptEntry(
            id: "log",
            title: "最近提交记录",
            description: "查看最新的 5 条提交历史",
            commandMaker: { _ in "git log -n 5 --oneline" }
        ),
        ScriptEntry(
            id: "diff",
            title: "查看工作区差异",
            description: "对比所有尚未暂存的代码修改",
            commandMaker: { _ in "git diff" }
        ),
        ScriptEntry(
            id: "diffCached",
            title: "查看暂存区差异",
            description: "查看已 git add 准备提交的代码改动",
            commandMaker: { _ in "git diff --cached" }
        ),
        ScriptEntry(
            id: "branchVv",
            title: "分支与跟踪详情",
            description: "查看本地分支与远程分支对应及提交状态",
            commandMaker: { _ in "git branch -vv" }
        ),
        ScriptEntry(
            id: "stash",
            title: "暂存当前工作区",
            description: "快速暂存所有修改，使工作区恢复纯净",
            commandMaker: { _ in "git stash" }
        ),
        ScriptEntry(
            id: "stashPop",
            title: "恢复最近暂存",
            description: "重新应用最近一次 stash 的修改",
            commandMaker: { _ in "git stash pop" }
        )
    ]

    var body: some View {
        if let item = appModel.selectedWorktree {
            ScrollView(.vertical) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(scripts) { script in
                        scriptCard(for: script, item: item)
                    }
                }
                .padding(10)
            }
        } else {
            ContentUnavailableView("未选择工作树", systemImage: "applescript", description: Text("在上方表格中选择工作树后可执行快捷脚本"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func scriptCard(for script: ScriptEntry, item: WorktreeItem) -> some View {
        let command = script.commandMaker(item.path)

        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(script.title)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text(script.description)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack {
                Text(command)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    appModel.appendWorktreeLog("已复制命令: \(command)")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("复制命令")

                Button {
                    appModel.runScriptInTerminal(command: command)
                } label: {
                    Image(systemName: "terminal")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("在终端中执行")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Legacy Drawer Compatibility

struct GitConsoleDrawerView: View {
    @Environment(AppModel.self) private var appModel
    @Binding var isExpanded: Bool

    var body: some View {
        WorktreeConsolePanelView()
    }
}


struct ProStatusBarView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appModel.currentWorktreeProject != nil ? Color.green : Color.orange)
                .frame(width: 6, height: 6)

            if let project = appModel.currentWorktreeProject {
                Text(project.displayName)
                    .font(.system(size: 11, weight: .medium))
            } else {
                Text("无项目")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            dividerDot

            HStack(spacing: 3) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 9))
                Text(appModel.gitVersion.isEmpty ? "Git" : appModel.gitVersion)
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)

            dividerDot

            HStack(spacing: 3) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 9))
                Text(appModel.currentIDELabel)
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 9))
                Text("\(appModel.currentProjectWorktreeCount) 个工作树")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)

            dividerDot

            HStack(spacing: 3) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 9))
                Text(appModel.currentProjectTotalDiskUsage)
                    .font(.system(size: 11, design: .monospaced))
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(height: 24)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.secondary.opacity(0.2)),
            alignment: .top
        )
    }

    private var dividerDot: some View {
        Text("•")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Unified Inspector Design System

enum InspectorButtonTone {
    case primary
    case secondary
    case accent(Color)
    case destructive
}

struct InspectorActionButtonStyle: ButtonStyle {
    var tone: InspectorButtonTone = .secondary
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        InspectorActionButtonBody(
            configuration: configuration,
            tone: tone,
            compact: compact
        )
    }
}

private struct InspectorActionButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let tone: InspectorButtonTone
    let compact: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering: Bool = false

    var body: some View {
        configuration.label
            .font(.system(size: compact ? 11.5 : 12, weight: fontWeight))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 26 : 30)
            .padding(.horizontal, 10)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(borderColor, lineWidth: 0.85)
            )
            .scaleEffect(configuration.isPressed && isEnabled ? 0.985 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .onHover { hovering in
                isHovering = hovering
            }
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var fontWeight: Font.Weight {
        switch tone {
        case .primary: return .semibold
        case .accent, .destructive, .secondary: return .medium
        }
    }

    private var foregroundColor: Color {
        switch tone {
        case .primary:
            return .white
        case .secondary:
            return .primary
        case .accent(let color):
            return color
        case .destructive:
            return Color(red: 1.0, green: 0.45, blue: 0.45)
        }
    }

    private var backgroundColor: Color {
        let activeHover = isHovering && isEnabled
        let pressed = configuration.isPressed && isEnabled
        switch tone {
        case .primary:
            if pressed { return Color.accentColor.opacity(0.82) }
            return Color.accentColor.opacity(activeHover ? 1.0 : 0.9)
        case .secondary:
            if pressed { return Color(NSColor.controlBackgroundColor).opacity(0.98) }
            return Color(NSColor.controlBackgroundColor).opacity(activeHover ? 0.95 : 0.72)
        case .accent(let color):
            if pressed { return color.opacity(0.26) }
            return color.opacity(activeHover ? 0.20 : 0.13)
        case .destructive:
            if pressed { return Color.red.opacity(0.26) }
            return Color.red.opacity(activeHover ? 0.20 : 0.12)
        }
    }

    private var borderColor: Color {
        let activeHover = isHovering && isEnabled
        switch tone {
        case .primary:
            return Color.white.opacity(activeHover ? 0.28 : 0.16)
        case .secondary:
            return Color.secondary.opacity(activeHover ? 0.36 : 0.22)
        case .accent(let color):
            return color.opacity(activeHover ? 0.56 : 0.36)
        case .destructive:
            return Color.red.opacity(activeHover ? 0.56 : 0.34)
        }
    }
}

struct IDEOpenSplitButton: View {
    let profiles: [IDEProfile]
    let defaultProfile: IDEProfile
    var tone: InspectorButtonTone = .secondary
    let onOpen: (IDEProfile) -> Void
    var onManageIDEs: (() -> Void)? = nil

    @State private var isHoveringMain: Bool = false

    private var mainFontWeight: Font.Weight {
        switch tone {
        case .primary: return .semibold
        default: return .medium
        }
    }

    var body: some View {
        if profiles.count <= 1 {
            Button {
                onOpen(defaultProfile)
            } label: {
                Label("IDE 中打开", systemImage: "macwindow")
            }
            .buttonStyle(InspectorActionButtonStyle(tone: tone))
            .help("使用 \(defaultProfile.effectiveLabel) 打开")
        } else {
            HStack(spacing: 0) {
                Button {
                    onOpen(defaultProfile)
                } label: {
                    Label(defaultProfile.effectiveLabel, systemImage: "macwindow")
                        .font(.system(size: 12, weight: mainFontWeight))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isHoveringMain = $0 }
                .help("使用默认编辑器 \(defaultProfile.effectiveLabel) 打开")

                Rectangle()
                    .fill(dividerColor)
                    .frame(width: 0.85, height: 18)

                Menu {
                    Section("选择已配置的编辑器") {
                        ForEach(profiles) { ide in
                            Button {
                                onOpen(ide)
                            } label: {
                                if ide.id == defaultProfile.id {
                                    Label("\(ide.effectiveLabel)（默认）", systemImage: "star.fill")
                                } else {
                                    Label(ide.effectiveLabel, systemImage: "macwindow")
                                }
                            }
                        }
                    }

                    if let onManageIDEs {
                        Divider()
                        Button {
                            onManageIDEs()
                        } label: {
                            Label("管理 IDE 编辑器…", systemImage: "slider.horizontal.3")
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9.5, weight: .semibold))
                        .frame(width: 24, height: 30)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("选择其他已配置的编辑器打开")
            }
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(borderColor, lineWidth: 0.85)
            )
            .animation(.easeOut(duration: 0.12), value: isHoveringMain)
        }
    }

    private var foregroundColor: Color {
        switch tone {
        case .primary: return .white
        case .secondary: return .primary
        case .accent(let color): return color
        case .destructive: return Color(red: 1.0, green: 0.45, blue: 0.45)
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .primary:
            return Color.accentColor.opacity(isHoveringMain ? 1.0 : 0.9)
        case .secondary:
            return Color(NSColor.controlBackgroundColor).opacity(isHoveringMain ? 0.95 : 0.72)
        case .accent(let color):
            return color.opacity(isHoveringMain ? 0.20 : 0.13)
        case .destructive:
            return Color.red.opacity(isHoveringMain ? 0.20 : 0.12)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .primary: return Color.white.opacity(isHoveringMain ? 0.28 : 0.16)
        case .secondary: return Color.secondary.opacity(isHoveringMain ? 0.36 : 0.22)
        case .accent(let color): return color.opacity(isHoveringMain ? 0.56 : 0.36)
        case .destructive: return Color.red.opacity(isHoveringMain ? 0.56 : 0.34)
        }
    }

    private var dividerColor: Color {
        switch tone {
        case .primary: return Color.white.opacity(0.28)
        default: return Color.secondary.opacity(0.28)
        }
    }
}

struct IDEOpenContextMenuContent: View {
    let profiles: [IDEProfile]
    let defaultProfile: IDEProfile
    let onOpen: (IDEProfile) -> Void

    var body: some View {
        if profiles.count <= 1 {
            Button {
                onOpen(defaultProfile)
            } label: {
                Label("在 \(defaultProfile.effectiveLabel) 中打开", systemImage: "arrow.up.forward.app")
            }
        } else {
            Menu {
                ForEach(profiles) { ide in
                    Button {
                        onOpen(ide)
                    } label: {
                        if ide.id == defaultProfile.id {
                            Label("\(ide.effectiveLabel)（默认）", systemImage: "star.fill")
                        } else {
                            Label(ide.effectiveLabel, systemImage: "macwindow")
                        }
                    }
                }
            } label: {
                Label("在 IDE 中打开", systemImage: "arrow.up.forward.app")
            }
        }
    }
}

struct InspectorHeaderView: View {
    let title: String
    let subtitleItems: [String]
    var monospacedTitle: Bool = false
    var trailingPill: StatusPill? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(monospacedTitle
                          ? .system(size: 16, weight: .bold, design: .monospaced)
                          : .system(size: 16, weight: .bold))
                    .lineLimit(2)
                    .textSelection(.enabled)

                if !subtitleItems.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(Array(subtitleItems.enumerated()), id: \.offset) { index, item in
                            if index > 0 {
                                Text("·")
                                    .foregroundStyle(.tertiary)
                            }
                            Text(item)
                        }
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            if let trailingPill {
                trailingPill
            }
        }
        .padding(.bottom, 2)
    }
}

struct InspectorCard<Trailing: View, Content: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing
    @ViewBuilder let content: Content

    init(
        title: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                trailing
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 0.75)
        )
    }
}

struct InspectorKeyValueRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    var canCopy: Bool = false
    var lineLimit: Int? = 2

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)

            Text(value)
                .font(isMonospaced ? .system(size: 11, design: .monospaced) : .system(size: 11.5))
                .foregroundStyle(.primary)
                .lineLimit(lineLimit)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .trailing)

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
}

struct InspectorActionGroupLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(.top, 2)
    }
}

enum WorktreeInspectorFocus {
    case dashboard
    case worktree
}

struct WorktreeInspectorBody: View {
    @Environment(AppModel.self) private var appModel

    let item: WorktreeItem
    let focus: WorktreeInspectorFocus
    var dashboardItem: MergeDashboardItem? = nil

    @State private var showingDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                InspectorHeaderView(
                    title: item.branch,
                    subtitleItems: [item.project, item.kind.rawValue],
                    monospacedTitle: true,
                    trailingPill: StatusPill(
                        title: item.dirtySummary,
                        tint: item.isDirty ? .orange : .green
                    )
                )

                basicInfoCard

                if focus == .dashboard {
                    baselineCheckCard
                }

                if item.kind != .mainRepo {
                    descriptionCard
                }

                if focus == .worktree {
                    baselineCheckCard
                }

                actionsSection

                if !item.commits.isEmpty {
                    recentCommitsCard
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .id("\(focus)-\(item.id)")
        .confirmationDialog(
            "移除工作树",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("移除此工作树", role: .destructive) {
                Task {
                    appModel.selectedWorktreeID = item.id
                    await appModel.removeWorktree(
                        item,
                        deleteLocalBranch: appModel.deleteLocalBranchOnRemove,
                        deleteRemoteBranch: appModel.deleteRemoteBranchOnRemove
                    )
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定移除「\(item.branch)」？\n路径：\(item.path)")
        }
    }

    private var basicInfoCard: some View {
        InspectorCard(title: "基本信息") {
            VStack(alignment: .leading, spacing: 7) {
                InspectorKeyValueRow(label: "路径", value: item.path, isMonospaced: true, canCopy: true)
                InspectorKeyValueRow(label: "占用空间", value: item.diskUsage, isMonospaced: true)
                InspectorKeyValueRow(label: "最近提交", value: item.commits.first?.relativeTime ?? item.updatedAt)
            }
        }
    }

    private var descriptionCard: some View {
        @Bindable var appModel = appModel

        return InspectorCard(title: "工作树备注") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("填写工作树用途或任务说明...", text: $appModel.worktreeDescriptionDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11.5))
                    .onSubmit {
                        Task {
                            appModel.selectedWorktreeID = item.id
                            await appModel.saveSelectedWorktreeDescription()
                        }
                    }

                HStack {
                    Spacer()
                    if !appModel.worktreeDescriptionDraft.isEmpty {
                        Button("清空") {
                            appModel.worktreeDescriptionDraft = ""
                        }
                        .controlSize(.mini)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    Button("保存备注") {
                        Task {
                            appModel.selectedWorktreeID = item.id
                            await appModel.saveSelectedWorktreeDescription()
                        }
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    .disabled(appModel.worktreeOperation.isRunning)
                }
            }
        }
    }

    @ViewBuilder
    private var baselineCheckCard: some View {
        let entries: [(target: String, merged: Bool)] = {
            if let dashboardItem {
                return dashboardItem.mergeTargets.map { target in
                    (target: target, merged: dashboardItem.mergeStatus[target] == true)
                }
            }
            return appModel.worktreeBaselineStatus(for: item)
        }()

        InspectorCard(title: "基线合入检查") {
            if item.kind == .mainRepo {
                Text("主仓库为基准目录")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else if entries.isEmpty {
                Text("尚未配置检测基线")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entries, id: \.target) { entry in
                        HStack {
                            Text(entry.target)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(.primary)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: entry.merged ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 11))
                                Text(entry.merged ? "已合入" : "未合入")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(entry.merged ? Color.green : Color.secondary)
                        }
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            InspectorActionGroupLabel(title: "打开与 Git 同步")

            HStack(spacing: 8) {
                IDEOpenSplitButton(
                    profiles: appModel.configuredIDEProfiles,
                    defaultProfile: appModel.defaultIDEProfile,
                    tone: .primary,
                    onOpen: { ide in
                        appModel.openWorktreeInIDE(item, ide: ide)
                    },
                    onManageIDEs: {
                        appModel.showingSettingsSheet = true
                    }
                )

                Button {
                    appModel.openWorktreeInTerminal(item)
                } label: {
                    Label("终端打开", systemImage: "terminal")
                }
                .buttonStyle(InspectorActionButtonStyle(tone: .secondary))
            }

            HStack(spacing: 8) {
                Button {
                    Task {
                        appModel.selectedWorktreeID = item.id
                        await appModel.pullSelectedWorktree()
                    }
                } label: {
                    Label("Pull", systemImage: "arrow.down")
                }
                .buttonStyle(InspectorActionButtonStyle(tone: .secondary))
                .disabled(appModel.worktreeOperation.isRunning)

                Button {
                    Task {
                        appModel.selectedWorktreeID = item.id
                        await appModel.pushSelectedWorktree()
                    }
                } label: {
                    Label("Push", systemImage: "arrow.up")
                }
                .buttonStyle(InspectorActionButtonStyle(tone: .secondary))
                .disabled(appModel.worktreeOperation.isRunning)
            }

            HStack(spacing: 8) {
                Button {
                    appModel.openWorktreeInRebased(item)
                } label: {
                    Label("Rebased", systemImage: "arrow.triangle.merge")
                }
                .buttonStyle(InspectorActionButtonStyle(tone: .secondary))

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                } label: {
                    Label("在访达显示", systemImage: "folder")
                }
                .buttonStyle(InspectorActionButtonStyle(tone: .secondary))
            }

            if item.kind != .mainRepo {
                InspectorActionGroupLabel(title: "流程流转")

                Button {
                    appModel.openBranchSync(forBranch: item.branch, projectPath: appModel.currentWorktreeProject?.path)
                } label: {
                    Label("一键前往分支同步", systemImage: "arrow.triangle.branch")
                }
                .buttonStyle(InspectorActionButtonStyle(tone: .accent(.teal)))

                if item.platform != .local {
                    Button {
                        appModel.prepareCreateMergeRequest(fromWorktree: item)
                    } label: {
                        Label("为此分支创建 \(appModel.requestShortLabel)", systemImage: "arrow.triangle.pull")
                    }
                    .buttonStyle(InspectorActionButtonStyle(tone: .accent(.purple)))
                }

                InspectorActionGroupLabel(title: "清理工作树")

                HStack(spacing: 12) {
                    Toggle("删除本地分支", isOn: bindableDeleteLocalBranch)
                        .font(.system(size: 11))
                    Toggle("删除远程分支", isOn: bindableDeleteRemoteBranch)
                        .font(.system(size: 11))
                        .disabled(!item.canRemoveRemoteBranch)
                }
                .foregroundStyle(.secondary)
                .padding(.vertical, 2)

                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label("移除此工作树", systemImage: "trash")
                }
                .buttonStyle(InspectorActionButtonStyle(tone: .destructive))
                .disabled(appModel.worktreeOperation.isRunning)
            }
        }
    }

    private var recentCommitsCard: some View {
        InspectorCard(title: "最近提交") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(item.commits.prefix(4))) { commit in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(commit.message)
                            .font(.system(size: 11.5, weight: .medium))
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            Text(commit.sha)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text("·")
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
                    if commit.id != item.commits.prefix(4).last?.id {
                        Divider().opacity(0.4)
                    }
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

// MARK: - Branch Architecture & Tag Flow Editor

struct BranchFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0 && currentX + size.width > maxWidth {
                maxRowWidth = max(maxRowWidth, currentX - horizontalSpacing)
                currentX = 0
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }
            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
        maxRowWidth = max(maxRowWidth, currentX > 0 ? currentX - horizontalSpacing : 0)
        return CGSize(
            width: proposal.width ?? maxRowWidth,
            height: currentY + rowHeight
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > bounds.minX && currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct BranchTagListEditor: View {
    @Binding var branches: [String]
    let defaultTint: Color
    var placeholder: String = "输入分支名后回车添加"
    var suggestions: [String] = []
    var minimumCount: Int = 0
    var badgeProvider: ((String) -> (label: String, tint: Color)?)? = nil

    @State private var inputText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if branches.isEmpty {
                Text("暂未配置分支，可在下方输入或点击推荐标签快速添加")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 2)
            } else {
                BranchFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(branches, id: \.self) { branch in
                        let badge = badgeProvider?(branch)
                        let chipTint = badge?.tint ?? defaultTint

                        HStack(spacing: 5) {
                            Circle()
                                .fill(chipTint)
                                .frame(width: 5.5, height: 5.5)

                            Text(branch)
                                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(.primary)

                            if let badge {
                                Text(badge.label)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(chipTint)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(chipTint.opacity(0.14))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }

                            if branches.count > minimumCount {
                                Button {
                                    removeBranch(branch)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("移除 \(branch)")
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(chipTint.opacity(0.11))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(chipTint.opacity(0.32), lineWidth: 0.7)
                        )
                    }
                }
            }

            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField(placeholder, text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5, design: .monospaced))
                        .onSubmit {
                            addFromInput()
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .frame(minWidth: 150, maxWidth: 200)
                .background(Color(NSColor.textBackgroundColor).opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.6)
                )

                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("添加") {
                        addFromInput()
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                }

                let remainingSuggestions = suggestions.filter { !branches.contains($0) }
                if !remainingSuggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(remainingSuggestions, id: \.self) { candidate in
                                Button {
                                    appendBranch(candidate)
                                } label: {
                                    Text("+ \(candidate)")
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.secondary.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                .buttonStyle(.plain)
                                .help("快速添加 \(candidate)")
                            }
                        }
                    }
                }
            }
        }
    }

    private func addFromInput() {
        let items = inputText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !items.isEmpty else { return }
        for item in items {
            appendBranch(item)
        }
        inputText = ""
    }

    private func appendBranch(_ branch: String) {
        let trimmed = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !branches.contains(trimmed) else { return }
        branches.append(trimmed)
    }

    private func removeBranch(_ branch: String) {
        guard branches.count > minimumCount else { return }
        branches.removeAll { $0 == branch }
    }
}

struct BranchArchitectureEditorView: View {
    @Binding var draft: WorkspaceProfileDraft

    private var mainlineBinding: Binding<[String]> {
        Binding(
            get: { draft.mainlineBranchList },
            set: { draft.mainlineBranchList = $0 }
        )
    }

    private var protectedEnvBinding: Binding<[String]> {
        Binding(
            get: { draft.protectedEnvBranchList },
            set: { draft.protectedEnvBranchList = $0 }
        )
    }

    private var baselineBinding: Binding<[String]> {
        Binding(
            get: { draft.dashboardBaselineList },
            set: { draft.dashboardBaselineList = $0 }
        )
    }

    private var effectiveMiddle: String {
        let trimmed = draft.mergeBranchMiddle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "sync" : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. 主干分支（生产环境）
            tierBlock(
                icon: "crown.fill",
                iconTint: .orange,
                title: "主干分支（生产环境）",
                badgeTitle: "PROD · 默认合入目标",
                badgeTint: .orange,
                description: "运行生产环境的正式分支（可留空不配置）；若已配置，同步环境分支或合并完成后会自动切换回主干分支，未配置则停留在当前分支。"
            ) {
                BranchTagListEditor(
                    branches: mainlineBinding,
                    defaultTint: .orange,
                    placeholder: "添加生产分支，回车确认（可留空）",
                    suggestions: draft.platform == .github ? ["main", "master", "prod"] : ["master", "main", "prod"],
                    minimumCount: 0
                )
            }

            // 2. 保护分支（非生产环境）
            tierBlock(
                icon: "shield.lefthalf.filled",
                iconTint: .teal,
                title: "保护分支（非生产环境）",
                badgeTitle: "NON-PROD · 集成流转",
                badgeTint: .teal,
                description: "用于联调、测试、预发的非生产保护分支（不直接推送），特性分支通过集成分支同步合入。"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    BranchTagListEditor(
                        branches: protectedEnvBinding,
                        defaultTint: .teal,
                        placeholder: "添加保护分支，回车确认",
                        suggestions: ["dev", "test", "stage", "uat", "staging"],
                        minimumCount: 0
                    )

                    if draft.platform == .gitlab || !draft.protectedEnvBranchList.isEmpty {
                        integrationSuffixBar
                    }
                }
            }

            // 3. 看板合入检查基线
            tierBlock(
                icon: "checkmark.shield",
                iconTint: .blue,
                title: "看板合入检查基线",
                badgeTitle: nil,
                badgeTint: .blue,
                description: "在「看板」和「空间清理」中校验特性分支是否已合入下列基准分支。",
                headerAction: {
                    Button {
                        syncBaselinesFromTopology()
                    } label: {
                        Label("同步主干 + 保护分支", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                }
            ) {
                BranchTagListEditor(
                    branches: baselineBinding,
                    defaultTint: .blue,
                    placeholder: "添加检查基线分支",
                    suggestions: suggestedBaselines,
                    minimumCount: 0,
                    badgeProvider: { branch in
                        if draft.mainlineBranchList.contains(branch) {
                            return ("生产", .orange)
                        }
                        if draft.protectedEnvBranchList.contains(branch) {
                            return ("保护", .teal)
                        }
                        return nil
                    }
                )
            }
        }
    }

    private var suggestedBaselines: [String] {
        var seen = Set<String>()
        return (draft.mainlineBranchList + draft.protectedEnvBranchList).filter {
            !$0.isEmpty && seen.insert($0).inserted
        }
    }

    private var integrationSuffixBar: some View {
        let envs = draft.protectedEnvBranchList
        let previewPairs = envs.prefix(3).map { "\($0)_\(effectiveMiddle) → \($0)" }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("集成分支后缀")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("sync", text: $draft.mergeBranchMiddle)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11.5, design: .monospaced))
                    .frame(minWidth: 110, maxWidth: 170)

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text("流转:")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                    Text("特性")
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.tertiary)
                    Text("<保护>_\(effectiveMiddle)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(Color.teal)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.tertiary)
                    Text("保护分支")
                        .foregroundStyle(Color.teal)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.tertiary)
                    Text(draft.mainlineBranchList.first ?? "未配置主干")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(draft.mainlineBranchList.isEmpty ? Color.secondary : Color.orange)
                }
                .font(.system(size: 10.5))
                .lineLimit(1)
            }

            if !previewPairs.isEmpty {
                BranchFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                    Text("映射示例:")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 2)
                    ForEach(previewPairs, id: \.self) { pair in
                        Text(pair)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    if envs.count > 3 {
                        Text("+\(envs.count - 3)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 2)
                    }
                    Text("映射表 \(draft.branchMappings.count) 条")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                    Button("同步到映射表") {
                        draft.branchMappings = draft.buildRecommendedBranchMappings()
                    }
                    .controlSize(.mini)
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 0.6)
        )
    }

    private func syncBaselinesFromTopology() {
        var seen = Set<String>()
        let merged = (draft.mainlineBranchList + draft.protectedEnvBranchList).filter {
            !$0.isEmpty && seen.insert($0).inserted
        }
        if !merged.isEmpty {
            draft.dashboardBaselineList = merged
        }
    }

    private func tierBlock<HeaderAction: View, Content: View>(
        icon: String,
        iconTint: Color,
        title: String,
        badgeTitle: String?,
        badgeTint: Color,
        description: String,
        @ViewBuilder headerAction: () -> HeaderAction = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11.5))
                    .foregroundStyle(iconTint)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                if let badgeTitle {
                    StatusPill(title: badgeTitle, tint: badgeTint)
                }

                Spacer()
                headerAction()
            }

            Text(description)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)

            content()
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(iconTint.opacity(0.18), lineWidth: 0.75)
        )
    }
}


