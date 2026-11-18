import Foundation
import AppKit

public struct InstalledTerminalApp: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let displayName: String
    public let bundleID: String
    public let defaultPath: String
    public let appURL: URL?
    public let isInstalled: Bool

    public var locationDescription: String {
        if let path = appURL?.path {
            return path
        }
        return "未检测到安装"
    }
}

public final class TerminalService: Sendable {
    public static let shared = TerminalService()

    /// 知名预设终端库
    public static let supportedPresets: [(name: String, displayName: String, bundleID: String, defaultPath: String)] = [
        ("Otty", "Otty", "io.appmakes.otty", "/Applications/Otty.app"),
        ("Ghostty", "Ghostty", "com.mitchellh.ghostty", "/Applications/Ghostty.app"),
        ("Terminal", "Terminal (系统自带)", "com.apple.Terminal", "/System/Applications/Utilities/Terminal.app"),
        ("iTerm", "iTerm2", "com.googlecode.iterm2", "/Applications/iTerm.app"),
        ("Warp", "Warp", "dev.warp.Warp-Stable", "/Applications/Warp.app"),
        ("Alacritty", "Alacritty", "org.alacritty", "/Applications/Alacritty.app"),
        ("kitty", "Kitty", "net.kovidgoyal.kitty", "/Applications/kitty.app"),
        ("WezTerm", "WezTerm", "com.github.wez.wezterm", "/Applications/WezTerm.app"),
        ("Rio", "Rio", "com.raphaelamorim.rio", "/Applications/Rio.app"),
        ("Tabby", "Tabby", "org.tabby", "/Applications/Tabby.app"),
        ("Hyper", "Hyper", "co.zeit.hyper", "/Applications/Hyper.app")
    ]

    private let excludedBundlePrefixes: Set<String> = [
        "com.sublimetext.",
        "com.microsoft.VSCode",
        "com.apple.dt.Xcode",
        "com.jetbrains.",
        "com.google.Chrome",
        "com.apple.Console"
    ]

    public init() {}

    /// 动态全量扫描本地安装的终端应用（系统注册关联 + 知名预设库 + /Applications 本地文件扫描）
    public func scanInstalledTerminals() -> [InstalledTerminalApp] {
        var scannedMap: [String: InstalledTerminalApp] = [:]
        let ws = NSWorkspace.shared

        // 1. 先探测知名预设库
        for preset in Self.supportedPresets {
            var foundURL: URL? = nil

            if let url = ws.urlForApplication(withBundleIdentifier: preset.bundleID) {
                foundURL = url
            } else if FileManager.default.fileExists(atPath: preset.defaultPath) {
                foundURL = URL(fileURLWithPath: preset.defaultPath)
            } else {
                let userAppPath = ("~/Applications/" as NSString).expandingTildeInPath + "/" + (preset.defaultPath as NSString).lastPathComponent
                if FileManager.default.fileExists(atPath: userAppPath) {
                    foundURL = URL(fileURLWithPath: userAppPath)
                }
            }

            scannedMap[preset.bundleID] = InstalledTerminalApp(
                id: preset.name,
                name: preset.name,
                displayName: preset.displayName,
                bundleID: preset.bundleID,
                defaultPath: preset.defaultPath,
                appURL: foundURL,
                isInstalled: foundURL != nil
            )
        }

        // 2. 动态扫描常见应用目录 (/Applications, ~/Applications, /System/Applications/Utilities)
        let searchDirectories = [
            "/Applications",
            ("~/Applications" as NSString).expandingTildeInPath,
            "/System/Applications/Utilities"
        ]

        for dir in searchDirectories {
            guard let fileNames = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for fileName in fileNames where fileName.hasSuffix(".app") {
                let appPath = (dir as NSString).appendingPathComponent(fileName)
                let appURL = URL(fileURLWithPath: appPath)
                guard let bundle = Bundle(url: appURL),
                      let bundleID = bundle.bundleIdentifier else { continue }

                // 排除已知非终端的代码编辑器或浏览器
                if excludedBundlePrefixes.contains(where: { bundleID.hasPrefix($0) }) {
                    continue
                }

                let lowerName = fileName.lowercased()
                let isTerminalLike = lowerName.contains("otty")
                    || lowerName.contains("ghost")
                    || lowerName.contains("term")
                    || lowerName.contains("warp")
                    || lowerName.contains("kitty")
                    || lowerName.contains("alacritty")
                    || lowerName.contains("wezterm")
                    || lowerName.contains("pty")
                    || lowerName.contains("console")

                if isTerminalLike {
                    let appDisplayName = bundle.infoDictionary?["CFBundleDisplayName"] as? String
                        ?? bundle.infoDictionary?["CFBundleName"] as? String
                        ?? fileName.replacingOccurrences(of: ".app", with: "")

                    let nameKey = fileName.replacingOccurrences(of: ".app", with: "")

                    // 如果不在已有扫描列表中，或者更新其已安装路径
                    if let existing = scannedMap[bundleID] {
                        scannedMap[bundleID] = InstalledTerminalApp(
                            id: existing.id,
                            name: existing.name,
                            displayName: existing.displayName,
                            bundleID: bundleID,
                            defaultPath: appPath,
                            appURL: appURL,
                            isInstalled: true
                        )
                    } else {
                        scannedMap[bundleID] = InstalledTerminalApp(
                            id: nameKey,
                            name: nameKey,
                            displayName: appDisplayName,
                            bundleID: bundleID,
                            defaultPath: appPath,
                            appURL: appURL,
                            isInstalled: true
                        )
                    }
                }
            }
        }

        // 排序：已安装的置顶，且按名称排序；未安装的放在后面
        return scannedMap.values.sorted { lhs, rhs in
            if lhs.isInstalled != rhs.isInstalled {
                return lhs.isInstalled && !rhs.isInstalled
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    public enum TerminalKind: Sendable {
        case otty
        case iterm
        case appleTerminal
        case ghostty
        case kitty
        case wezterm
        case alacritty
        case generic
    }

    public func detectTerminalKind(terminalName: String, bundleID: String? = nil) -> TerminalKind {
        let lowerName = terminalName.lowercased()
        let lowerBundle = (bundleID ?? "").lowercased()

        if lowerBundle == "io.appmakes.otty" || lowerName == "otty" || lowerName.contains("otty") {
            return .otty
        }
        if lowerBundle.contains("iterm") || lowerName.contains("iterm") {
            return .iterm
        }
        if lowerBundle == "com.apple.terminal" || lowerName == "terminal" {
            return .appleTerminal
        }
        if lowerBundle.contains("ghostty") || lowerName.contains("ghostty") {
            return .ghostty
        }
        if lowerBundle.contains("kitty") || lowerName.contains("kitty") {
            return .kitty
        }
        if lowerBundle.contains("wezterm") || lowerName.contains("wezterm") {
            return .wezterm
        }
        if lowerBundle.contains("alacritty") || lowerName.contains("alacritty") {
            return .alacritty
        }
        return .generic
    }

    public func openDirectory(
        path: String,
        terminalName: String,
        bundleID: String? = nil,
        tabTitle: String? = nil
    ) throws {
        try openDirectoryWithHook(
            path: path,
            terminalName: terminalName,
            bundleID: bundleID,
            tabTitle: tabTitle,
            hookMode: "none",
            hookCommand: ""
        )
    }

    public func openDirectoryWithHook(
        path: String,
        terminalName: String,
        bundleID: String? = nil,
        tabTitle: String? = nil,
        hookMode: String = "none",
        hookCommand: String = ""
    ) throws {
        let expandedPath = ProcessRunner.expandPath(path)
        let trimmedCmd = (hookMode == "command") ? hookCommand.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let kind = detectTerminalKind(terminalName: terminalName, bundleID: bundleID)

        var launchedSuccessfully = false

        switch kind {
        case .otty:
            launchedSuccessfully = launchOtty(path: expandedPath, tabTitle: tabTitle, hookCommand: trimmedCmd.isEmpty ? nil : trimmedCmd)
        case .iterm:
            launchedSuccessfully = launchITerm(path: expandedPath, tabTitle: tabTitle, hookCommand: trimmedCmd.isEmpty ? nil : trimmedCmd)
        case .ghostty:
            launchedSuccessfully = launchGhostty(path: expandedPath, tabTitle: tabTitle, hookCommand: trimmedCmd.isEmpty ? nil : trimmedCmd)
        case .appleTerminal:
            launchedSuccessfully = launchAppleTerminal(path: expandedPath, tabTitle: tabTitle, hookCommand: trimmedCmd.isEmpty ? nil : trimmedCmd)
        default:
            break
        }

        if !launchedSuccessfully {
            // 通用降级启动（绝不误调系统自带 Terminal，除非用户选择的就是 Terminal）
            try fallbackLaunch(path: expandedPath, terminalName: terminalName, bundleID: bundleID, tabTitle: tabTitle)
        }
    }

    private func fallbackLaunch(path: String, terminalName: String, bundleID: String?, tabTitle: String?) throws {
        let terminals = scanInstalledTerminals()
        let matched = terminals.first(where: {
            $0.name.caseInsensitiveCompare(terminalName) == .orderedSame ||
            $0.displayName.caseInsensitiveCompare(terminalName) == .orderedSame ||
            (!($0.bundleID.isEmpty) && $0.bundleID == bundleID)
        })

        if let matched, matched.isInstalled {
            switch matched.name.lowercased() {
            case "alacritty":
                _ = try ProcessRunner.runCommand("open", arguments: ["-n", "-b", matched.bundleID, "--args", "--working-directory", path])
                return
            case "kitty":
                _ = try ProcessRunner.runCommand("open", arguments: ["-n", "-b", matched.bundleID, "--args", "--directory", path])
                return
            case "wezterm":
                _ = try ProcessRunner.runCommand("open", arguments: ["-n", "-b", matched.bundleID, "--args", "start", "--cwd", path])
                return
            case "ghostty":
                var args = ["-a", "Ghostty", path]
                if let title = tabTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                    args.append(contentsOf: ["--args", "--title=\(title)"])
                }
                _ = try ProcessRunner.runCommand("open", arguments: args)
                return
            default:
                _ = try ProcessRunner.runCommand("open", arguments: ["-b", matched.bundleID, path])
                return
            }
        }

        if let bundleID, !bundleID.isEmpty {
            _ = try ProcessRunner.runCommand("open", arguments: ["-b", bundleID, path])
            return
        }

        if !terminalName.isEmpty && terminalName != "Terminal" {
            _ = try ProcessRunner.runCommand("open", arguments: ["-a", terminalName, path])
            return
        }

        _ = try ProcessRunner.runCommand("open", arguments: ["-a", "Terminal", path])
    }

    // MARK: - Native AppleScript / Dedicated Launchers

    private func escapeAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func shellQuote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func buildShellCommand(path: String, tabTitle: String?, hookCommand: String?) -> String {
        var commands: [String] = ["cd \(shellQuote(path))"]
        if let title = tabTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            commands.append("printf '\\033]0;%s\\007' \(shellQuote(title))")
        }
        if let hook = hookCommand?.trimmingCharacters(in: .whitespacesAndNewlines), !hook.isEmpty {
            commands.append(hook)
        }
        return commands.joined(separator: " && ")
    }

    private func launchOtty(path: String, tabTitle: String?, hookCommand: String?) -> Bool {
        let cliCandidates = [
            "/Applications/Otty.app/Contents/MacOS/otty-cli",
            ProcessRunner.expandPath("~/Applications/Otty.app/Contents/MacOS/otty-cli")
        ]

        if let cliPath = cliCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            // 1. 优先尝试在已有 Otty 窗口中创建新 Tab（而不是弹出新窗口）
            var newTabArgs = ["tab", "new", "--cwd", path]
            if let title = tabTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                newTabArgs.append(contentsOf: ["--title", title])
            }

            if let result = try? ProcessRunner.runCommand(cliPath, arguments: newTabArgs), result.status == 0 {
                activateOttyApp()

                let createdTabID = parseOttyTabID(from: result.stdout)

                if let title = tabTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                    // 立即重命名以锁定 customTitle，防止被 zsh 初始化覆盖
                    applyOttyTabRename(cliPath: cliPath, tabID: createdTabID, title: title)

                    // 稍作延时再补充锁定一次（防止部分 shell 加载较慢时被 prompt 钩子异步覆盖）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        self.applyOttyTabRename(cliPath: cliPath, tabID: createdTabID, title: title)
                    }
                }

                if let hook = hookCommand?.trimmingCharacters(in: .whitespacesAndNewlines), !hook.isEmpty {
                    var sendArgs = ["pane", "send-text", "--submit=now"]
                    if let tabID = createdTabID, !tabID.isEmpty {
                        sendArgs.append(contentsOf: ["--pane", tabID])
                    }
                    sendArgs.append("\(hook)\n")
                    _ = try? ProcessRunner.runCommand(cliPath, arguments: sendArgs)
                }
                return true
            }

            // 2. 如果当前无运行窗口，则启动新窗口
            var openArgs = ["open", path]
            if let title = tabTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                openArgs.append(contentsOf: ["--title", title])
            }
            if let result = try? ProcessRunner.runCommand(cliPath, arguments: openArgs), result.status == 0 {
                activateOttyApp()
                if let title = tabTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        _ = try? ProcessRunner.runCommand(cliPath, arguments: ["tab", "rename", title])
                    }
                }
                if let hook = hookCommand?.trimmingCharacters(in: .whitespacesAndNewlines), !hook.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        _ = try? ProcessRunner.runCommand(cliPath, arguments: ["pane", "send-text", "--submit=now", "\(hook)\n"])
                    }
                }
                return true
            }
        }

        // 3. 降级使用 AppleScript
        return launchOttyViaAppleScript(path: path, tabTitle: tabTitle, hookCommand: hookCommand)
    }

    private func parseOttyTabID(from jsonOutput: String) -> String? {
        guard let data = jsonOutput.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else {
            return nil
        }
        return id
    }

    private func applyOttyTabRename(cliPath: String, tabID: String?, title: String) {
        var renameArgs = ["tab", "rename"]
        if let id = tabID, !id.isEmpty {
            renameArgs.append(contentsOf: ["--tab", id])
        }
        renameArgs.append(title)
        _ = try? ProcessRunner.runCommand(cliPath, arguments: renameArgs)
    }

    private func executeAppleScript(_ source: String) -> Bool {
        let result = try? ProcessRunner.runCommand("osascript", arguments: ["-e", source])
        return result?.status == 0
    }

    private func executeAppleScriptThrowing(_ source: String, errorPrefix: String) throws {
        do {
            let result = try ProcessRunner.runCommand("osascript", arguments: ["-e", source])
            if result.status != 0 {
                let msg = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                throw WorkbenchError.message("\(errorPrefix): \(msg.isEmpty ? "状态码 \(result.status)" : msg)")
            }
        } catch {
            throw WorkbenchError.message("\(errorPrefix): \(error.localizedDescription)")
        }
    }

    private func activateOttyApp() {
        _ = executeAppleScript("tell application \"Otty\" to activate")
    }

    private func launchOttyViaAppleScript(path: String, tabTitle: String?, hookCommand: String?) -> Bool {
        let fullCmd = buildShellCommand(path: path, tabTitle: tabTitle, hookCommand: hookCommand)
        let escapedCmd = escapeAppleScript(fullCmd)
        let escapedTitle = escapeAppleScript(tabTitle ?? "")
        let titleClause = (tabTitle?.isEmpty == false) ? "\n        set custom title of t to \"\(escapedTitle)\"" : ""

        let scriptSource = """
        tell application "Otty"
            activate
            set t to do script "\(escapedCmd)"\(titleClause)
        end tell
        """

        return executeAppleScript(scriptSource)
    }

    private func launchITerm(path: String, tabTitle: String?, hookCommand: String?) -> Bool {
        let fullCmd = buildShellCommand(path: path, tabTitle: tabTitle, hookCommand: hookCommand)
        let escapedCmd = escapeAppleScript(fullCmd)
        let escapedTitle = escapeAppleScript(tabTitle ?? "")
        let titleClause = (tabTitle?.isEmpty == false) ? "\n                    set name to \"\(escapedTitle)\"" : ""
        let titleClauseWindow = (tabTitle?.isEmpty == false) ? "\n                set name to \"\(escapedTitle)\"" : ""

        let scriptSource = """
        tell application "iTerm"
            activate
            try
                tell current window
                    create tab with default profile
                    tell current session\(titleClause)
                        write text "\(escapedCmd)"
                    end tell
                end tell
            on error
                create window with default profile
                tell current session of current window\(titleClauseWindow)
                    write text "\(escapedCmd)"
                end tell
            end try
        end tell
        """

        return executeAppleScript(scriptSource)
    }

    private func launchGhostty(path: String, tabTitle: String?, hookCommand: String?) -> Bool {
        let safePath = escapeAppleScript(path)
        let safeTitle = escapeAppleScript(tabTitle ?? "")

        var scriptLines: [String] = [
            "tell application \"Ghostty\"",
            "    activate",
            "    set cfg to new surface configuration",
            "    set initial working directory of cfg to \"\(safePath)\""
        ]

        scriptLines.append(contentsOf: [
            "    if (count of windows) > 0 then",
            "        set targetTab to new tab in front window with configuration cfg",
            "    else",
            "        set targetWin to new window with configuration cfg",
            "        set targetTab to selected tab of targetWin",
            "    end if",
            "    set targetTerm to focused terminal of targetTab"
        ])

        if !safeTitle.isEmpty {
            scriptLines.append("    perform action \"set_tab_title:\(safeTitle)\" on targetTerm")
        }

        if let hook = hookCommand?.trimmingCharacters(in: .whitespacesAndNewlines), !hook.isEmpty {
            let safeHook = escapeAppleScript(hook)
            scriptLines.append("    input text \"\(safeHook)\" to targetTerm")
            scriptLines.append("    send key \"enter\" to targetTerm")
        }

        scriptLines.append("end tell")

        let source = scriptLines.joined(separator: "\n")
        if executeAppleScript(source) {
            return true
        }

        // 备用降级方案：如果 AppleScript 失败，尝试 open 命令直接打开目标目录
        var openArgs = ["-a", "Ghostty", path]
        if let title = tabTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            openArgs.append(contentsOf: ["--args", "--title=\(title)"])
        }
        if let openRes = try? ProcessRunner.runCommand("open", arguments: openArgs), openRes.status == 0 {
            return true
        }

        return false
    }

    private func launchAppleTerminal(path: String, tabTitle: String?, hookCommand: String?) -> Bool {
        let fullCmd = buildShellCommand(path: path, tabTitle: tabTitle, hookCommand: hookCommand)
        let escapedCmd = escapeAppleScript(fullCmd)
        let escapedTitle = escapeAppleScript(tabTitle ?? "")
        let titleClause = (tabTitle?.isEmpty == false) ? "\n        set custom title of selected tab of front window to \"\(escapedTitle)\"" : ""

        let scriptSource = """
        tell application "Terminal"
            activate
            do script "\(escapedCmd)"\(titleClause)
        end tell
        """

        return executeAppleScript(scriptSource)
    }

    public func runScriptInTerminal(
        command: String,
        path: String,
        terminalName: String,
        tabTitle: String? = nil
    ) throws {
        let expandedPath = ProcessRunner.expandPath(path)
        let fullCmd = buildShellCommand(path: expandedPath, tabTitle: tabTitle, hookCommand: command.isEmpty ? nil : command)
        let escapedCmd = escapeAppleScript(fullCmd)
        let escapedTitle = escapeAppleScript(tabTitle ?? "")
        let kind = detectTerminalKind(terminalName: terminalName)

        switch kind {
        case .otty:
            let titleClause = (tabTitle?.isEmpty == false) ? "\n            set custom title of t to \"\(escapedTitle)\"" : ""
            let scriptSource = """
            tell application "Otty"
                activate
                if (count of windows) > 0 then
                    set t to do script "\(escapedCmd)" in front window
                else
                    set t to do script "\(escapedCmd)"
                end if\(titleClause)
            end tell
            """
            try executeAppleScriptThrowing(scriptSource, errorPrefix: "Otty 执行脚本失败")
        case .iterm:
            let titleClause = (tabTitle?.isEmpty == false) ? "\n                        set name to \"\(escapedTitle)\"" : ""
            let titleClauseWindow = (tabTitle?.isEmpty == false) ? "\n                    set name to \"\(escapedTitle)\"" : ""
            let scriptSource = """
            tell application "iTerm"
                activate
                try
                    tell current window
                        create tab with default profile
                        tell current session\(titleClause)
                            write text "\(escapedCmd)"
                        end tell
                    end tell
                on error
                    create window with default profile
                    tell current session of current window\(titleClauseWindow)
                        write text "\(escapedCmd)"
                    end tell
                end try
            end tell
            """
            try executeAppleScriptThrowing(scriptSource, errorPrefix: "iTerm 执行脚本失败")
        case .ghostty:
            let escapedAppleScriptCmd = escapeAppleScript(command)
            let titleClause = (tabTitle?.isEmpty == false) ? "\n                perform action \"set_tab_title:\(escapedTitle)\" on targetTerm" : ""
            let scriptSource = """
            tell application "Ghostty"
                activate
                if (count of windows) > 0 then
                    set targetTerm to focused terminal of selected tab of front window\(titleClause)
                    input text "\(escapedAppleScriptCmd)" to targetTerm
                    send key "enter" to targetTerm
                end if
            end tell
            """
            try executeAppleScriptThrowing(scriptSource, errorPrefix: "Ghostty 执行脚本失败")
        case .appleTerminal:
            let titleClause = (tabTitle?.isEmpty == false) ? "\n        set custom title of selected tab of front window to \"\(escapedTitle)\"" : ""
            let scriptSource = """
            tell application "Terminal"
                activate
                do script "\(escapedCmd)"\(titleClause)
            end tell
            """
            try executeAppleScriptThrowing(scriptSource, errorPrefix: "终端执行脚本失败")
        default:
            break
        }
    }
}
