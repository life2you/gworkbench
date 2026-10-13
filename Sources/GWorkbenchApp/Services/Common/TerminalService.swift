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

    public func openDirectory(path: String, terminalName: String, bundleID: String? = nil) throws {
        let expandedPath = ProcessRunner.expandPath(path)
        let terminals = scanInstalledTerminals()

        let matched = terminals.first(where: {
            $0.name.caseInsensitiveCompare(terminalName) == .orderedSame ||
            $0.displayName.caseInsensitiveCompare(terminalName) == .orderedSame ||
            (!($0.bundleID.isEmpty) && $0.bundleID == bundleID)
        })

        if let matched, matched.isInstalled {
            do {
                try launchTerminal(terminal: matched, path: expandedPath)
                return
            } catch {
                // 如果特定参数启动失败，尝试降级为通用 open
            }
        }

        // 通用打开逻辑
        if let bundleID, !bundleID.isEmpty {
            do {
                _ = try ProcessRunner.runCommand("open", arguments: ["-b", bundleID, expandedPath])
                return
            } catch {}
        }

        if !terminalName.isEmpty && terminalName != "Terminal" {
            do {
                _ = try ProcessRunner.runCommand("open", arguments: ["-a", terminalName, expandedPath])
                return
            } catch {}
        }

        _ = try ProcessRunner.runCommand("open", arguments: ["-a", "Terminal", expandedPath])
    }

    public func openDirectoryWithHook(
        path: String,
        terminalName: String,
        bundleID: String? = nil,
        hookMode: String = "none",
        hookCommand: String = ""
    ) throws {
        try openDirectory(path: path, terminalName: terminalName, bundleID: bundleID)

        let trimmedCmd = hookCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        if hookMode == "command" && !trimmedCmd.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                try? self.runScriptInTerminal(command: trimmedCmd, path: path, terminalName: terminalName)
            }
        }
    }

    private func launchTerminal(terminal: InstalledTerminalApp, path: String) throws {
        switch terminal.name.lowercased() {
        case "alacritty":
            _ = try ProcessRunner.runCommand("open", arguments: ["-n", "-b", terminal.bundleID, "--args", "--working-directory", path])
        case "kitty":
            _ = try ProcessRunner.runCommand("open", arguments: ["-n", "-b", terminal.bundleID, "--args", "--directory", path])
        case "wezterm":
            _ = try ProcessRunner.runCommand("open", arguments: ["-n", "-b", terminal.bundleID, "--args", "start", "--cwd", path])
        default:
            _ = try ProcessRunner.runCommand("open", arguments: ["-b", terminal.bundleID, path])
        }
    }

    public func runScriptInTerminal(command: String, path: String, terminalName: String) throws {
        let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedCmd = command.replacingOccurrences(of: "\"", with: "\\\"")

        if terminalName.lowercased() == "iterm" {
            let scriptSource = """
            tell application "iTerm"
                activate
                try
                    tell current window
                        create tab with default profile
                        tell current session
                            write text "cd \\"\(escapedPath)\\" && \(escapedCmd)"
                        end tell
                    end tell
                on error
                    create window with default profile
                    tell current session of current window
                        write text "cd \\"\(escapedPath)\\" && \(escapedCmd)"
                    end tell
                end try
            end tell
            """
            if let script = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                if let error {
                    throw WorkbenchError.message("iTerm 执行脚本失败: \(error)")
                }
                return
            }
        }

        // 默认使用 Terminal 执行脚本
        let scriptSource = """
        tell application "Terminal"
            activate
            do script "cd \\"\(escapedPath)\\" && \(escapedCmd)"
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let error {
                throw WorkbenchError.message("终端执行脚本失败: \(error)")
            }
        }
    }
}
