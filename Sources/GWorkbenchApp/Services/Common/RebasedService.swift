import Foundation
import AppKit

public final class RebasedService: Sendable {
    public static let shared = RebasedService()

    public let bundleID = "io.github.detachhead.rebased"
    public let defaultAppPath = "/Applications/Rebased.app"
    public let userAppPath = ("~/Applications/Rebased.app" as NSString).expandingTildeInPath

    public init() {}

    /// 检测 Rebased 是否已安装在系统中
    public var isInstalled: Bool {
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil {
            return true
        }
        if FileManager.default.fileExists(atPath: defaultAppPath) ||
           FileManager.default.fileExists(atPath: userAppPath) {
            return true
        }
        return false
    }

    /// 获取 Rebased 的 App 路径 URL
    public var appURL: URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url
        }
        if FileManager.default.fileExists(atPath: defaultAppPath) {
            return URL(fileURLWithPath: defaultAppPath)
        }
        if FileManager.default.fileExists(atPath: userAppPath) {
            return URL(fileURLWithPath: userAppPath)
        }
        return nil
    }

    /// 在 Rebased 中打开指定工程目录（自动激活并触发 Rebased 的冲突解决界面）
    public func openProject(path: String) throws {
        guard let url = appURL else {
            throw WorkbenchError.message("未检测到 Rebased 安装，请先安装 Rebased。")
        }
        let projectURL = URL(fileURLWithPath: path)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([projectURL], withApplicationAt: url, configuration: config) { _, error in
            if let error {
                print("Failed to open Rebased: \(error.localizedDescription)")
            }
        }
    }

    /// 通过 Homebrew 安装 Rebased Cask
    public func installViaBrew(onOutput: @escaping @Sendable (String) -> Void) async throws {
        let brewPath: String
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") {
            brewPath = "/opt/homebrew/bin/brew"
        } else if FileManager.default.fileExists(atPath: "/usr/local/bin/brew") {
            brewPath = "/usr/local/bin/brew"
        } else {
            brewPath = "brew"
        }

        onOutput("正在通过 Homebrew 安装 Rebased (detachhead/tap/rebased)...")
        let result = try await Task.detached(priority: .userInitiated) { () -> ShellResult in
            try ProcessRunner.runCommand(
                brewPath,
                arguments: ["install", "--cask", "detachhead/tap/rebased"]
            )
        }.value

        if result.status != 0 {
            let errorMsg = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
                ?? result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
                ?? "Homebrew 安装失败 (exit \(result.status))"
            throw WorkbenchError.message(errorMsg)
        }
        onOutput("Rebased 安装成功！")
    }
}
