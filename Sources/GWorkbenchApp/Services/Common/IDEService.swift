import Foundation
import AppKit

public struct InstalledIDEApp: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let displayName: String
    public let bundleID: String
    public let defaultAppName: String
    public let appURL: URL?
    public let isInstalled: Bool

    public var locationDescription: String {
        if let path = appURL?.path {
            return path
        }
        return "未检测到安装"
    }
}

public final class IDEService: Sendable {
    public static let shared = IDEService()

    public static let supportedPresets: [(name: String, displayName: String, bundleID: String, defaultAppName: String)] = [
        ("Cursor", "Cursor", "com.todesktop.230313mzl4w4u92", "Cursor"),
        ("Visual Studio Code", "VS Code", "com.microsoft.VSCode", "Visual Studio Code"),
        ("Zed", "Zed", "dev.zed.Zed", "Zed"),
        ("IntelliJ IDEA", "IntelliJ IDEA", "com.jetbrains.intellij", "IntelliJ IDEA"),
        ("Xcode", "Xcode", "com.apple.dt.Xcode", "Xcode"),
        ("Windsurf", "Windsurf", "com.exafunction.windsurf", "Windsurf"),
        ("Trae", "Trae", "com.trae.app", "Trae"),
        ("WebStorm", "WebStorm", "com.jetbrains.WebStorm", "WebStorm"),
        ("PyCharm", "PyCharm", "com.jetbrains.PyCharm", "PyCharm"),
        ("GoLand", "GoLand", "com.jetbrains.goland", "GoLand"),
        ("Sublime Text", "Sublime Text", "com.sublimetext.4", "Sublime Text"),
        ("Fleet", "Fleet", "Fleet", "Fleet"),
        ("Android Studio", "Android Studio", "com.google.android.studio", "Android Studio")
    ]

    public init() {}

    /// 动态全量扫描本地安装的 IDE / 编辑器
    public func scanInstalledIDEs() -> [InstalledIDEApp] {
        var scannedMap: [String: InstalledIDEApp] = [:]
        let ws = NSWorkspace.shared

        for preset in Self.supportedPresets {
            var foundURL: URL? = nil

            if let url = ws.urlForApplication(withBundleIdentifier: preset.bundleID) {
                foundURL = url
            } else {
                let defaultPaths = [
                    "/Applications/\(preset.defaultAppName).app",
                    ("~/Applications/\(preset.defaultAppName).app" as NSString).expandingTildeInPath
                ]
                for path in defaultPaths {
                    if FileManager.default.fileExists(atPath: path) {
                        foundURL = URL(fileURLWithPath: path)
                        break
                    }
                }
            }

            scannedMap[preset.name] = InstalledIDEApp(
                id: preset.name,
                name: preset.name,
                displayName: preset.displayName,
                bundleID: preset.bundleID,
                defaultAppName: preset.defaultAppName,
                appURL: foundURL,
                isInstalled: foundURL != nil
            )
        }

        // 排序：已安装的置顶，且按名称排序；未安装的放在后面
        return scannedMap.values.sorted { lhs, rhs in
            if lhs.isInstalled != rhs.isInstalled {
                return lhs.isInstalled && !rhs.isInstalled
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    public func openDirectory(path: String, ideMode: String, ideCommand: String) throws {
        let expandedPath = ProcessRunner.expandPath(path)
        let trimmedCommand = ideCommand.trimmingCharacters(in: .whitespacesAndNewlines)

        switch ideMode {
        case "app":
            if !trimmedCommand.isEmpty, trimmedCommand != "open" {
                _ = try ProcessRunner.runCommand("open", arguments: ["-a", trimmedCommand, expandedPath])
                return
            }
            _ = try ProcessRunner.runCommand("open", arguments: [expandedPath])
        case "custom":
            if trimmedCommand.isEmpty || trimmedCommand == "open" {
                _ = try ProcessRunner.runCommand("open", arguments: [expandedPath])
                return
            }
            let quotedPath = "'\(expandedPath.replacingOccurrences(of: "'", with: "'\\''"))'"
            let shellCommand = trimmedCommand.contains("{path}")
                ? trimmedCommand.replacingOccurrences(of: "{path}", with: quotedPath)
                : "\(trimmedCommand) \(quotedPath)"
            _ = try ProcessRunner.runCommand("/bin/zsh", arguments: ["-lc", shellCommand])
        case "system":
            _ = try ProcessRunner.runCommand("open", arguments: [expandedPath])
        default:
            if !trimmedCommand.isEmpty, trimmedCommand != "open" {
                _ = try ProcessRunner.runCommand("open", arguments: ["-a", trimmedCommand, expandedPath])
            } else {
                _ = try ProcessRunner.runCommand("open", arguments: [expandedPath])
            }
        }
    }
}
