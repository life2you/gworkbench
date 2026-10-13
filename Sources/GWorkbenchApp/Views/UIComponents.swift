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
            Button("在 IDE 中打开") {
                appModel.openFileInIDE(path: change.path)
            }
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
