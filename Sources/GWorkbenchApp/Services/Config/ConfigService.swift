import Foundation
import TOMLKit

struct MetadataEntry: Sendable {
    let projectPath: String
    let branch: String
    let description: String
}

private struct WorktreeMetadataStore: Decodable {
    let descriptions: [WorktreeDescription]

    enum CodingKeys: String, CodingKey {
        case descriptions
    }

    init(descriptions: [WorktreeDescription] = []) {
        self.descriptions = descriptions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.descriptions = try container.decodeIfPresent([WorktreeDescription].self, forKey: .descriptions) ?? []
    }
}

private struct WorktreeDescription: Decodable {
    let project_path: String
    let branch: String
    let description: String
}

private struct GWorkbenchTomlConfig: Decodable {
    struct Worktree: Decodable {
        let projects_root_dirs: [String]
        let worktrees_root_dir: String
        let metadata_path: String?
        let path_template: String?
        let ide_mode: String?
        let ide_command: String?
        let ide_label: String?
        let terminal_app: String?
        let terminal_bundle_id: String?
        let terminal_launch_hook_mode: String?
        let terminal_launch_command: String?
    }

    struct GitLab: Decodable {
        let host: String
        let token: String
    }

    struct GitHub: Decodable {
        let token: String?
    }

    struct AI: Decodable {
        let provider: String?
        let base_url: String?
        let api_key: String?
        let model: String?
        let custom_prompt: String?
    }

    struct Merge: Decodable {
        let root_dirs: [String]
        let merge_branch_middle: String
        let env_branches: [String]?
        let active_preset: String?
        let github_default_target_branch: String?
    }

    struct MergePolicy: Decodable {
        let protected_targets: [String]?
        let auto_merge_delay_seconds: Int?
        let auto_merge_retry_count: Int?
    }

    let worktree: Worktree
    let gitlab: GitLab
    let github: GitHub?
    let ai: AI?
    let merge: Merge
    let branch_map: [String: String]?
    let merge_policy: MergePolicy?
}

final class ConfigService: Sendable {
    init() {}

    func resolveConfigPath(appName: String, fileName: String) -> String {
        let environment = ProcessInfo.processInfo.environment
        if let xdgConfigHome = environment["XDG_CONFIG_HOME"], !xdgConfigHome.isEmpty {
            return URL(fileURLWithPath: xdgConfigHome)
                .appendingPathComponent(appName)
                .appendingPathComponent(fileName)
                .path
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".config")
            .appendingPathComponent(appName)
            .appendingPathComponent(fileName)
            .path
    }

    func loadTomlFile<T: Decodable>(path: String) throws -> T {
        guard FileManager.default.fileExists(atPath: path) else {
            throw WorkbenchError.message("配置文件不存在: \(path)")
        }
        let content = try String(contentsOfFile: path, encoding: .utf8)
        do {
            return try TOMLDecoder().decode(T.self, from: content)
        } catch {
            throw WorkbenchError.message("TOML 解析失败 (\(path)): \(error.localizedDescription)")
        }
    }

    func defaultWorkbenchConfig(configPath: String) -> GWorkbenchConfig {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let configDirectory = URL(fileURLWithPath: configPath).deletingLastPathComponent().path
        let metadataDefaultPath = (configDirectory as NSString).appendingPathComponent("worktree-metadata.toml")
        return GWorkbenchConfig(
            configPath: configPath,
            metadataPath: metadataDefaultPath,
            worktreeProjectsRootDirs: [],
            worktreesRootDir: (home as NSString).appendingPathComponent("worktrees"),
            worktreePathTemplate: "${rootDir}/${project}/${branch}",
            ideMode: "app",
            ideCommand: "open",
            ideLabel: "默认应用",
            terminalApp: "Terminal",
            terminalBundleID: "com.apple.Terminal",
            terminalLaunchHookMode: "none",
            terminalLaunchCommand: "git status",
            gitlabHost: "",
            gitlabToken: "",
            githubToken: "",
            aiProvider: "deepseek",
            aiBaseURL: "https://api.deepseek.com",
            aiAPIKey: "",
            aiModel: "deepseek-chat",
            aiCustomPrompt: "",
            activeWorkflowPreset: "env_flow",
            githubDefaultTargetBranch: "main",
            mergeRootDirs: [],
            mergeBranchMiddle: "feature",
            envBranches: ["dev", "test", "staging", "prod"],
            branchMap: [:],
            protectedTargets: ["main", "master"],
            autoMergeDelaySeconds: 5,
            autoMergeRetryCount: 3
        )
    }

    func loadOrCreateWorkbenchConfig() throws -> GWorkbenchConfig {
        let configPath = resolveConfigPath(appName: "gworkbench", fileName: "config.toml")
        if FileManager.default.fileExists(atPath: configPath) {
            return try loadWorkbenchConfig()
        }
        let defaultConfig = defaultWorkbenchConfig(configPath: configPath)
        try saveWorkbenchConfig(defaultConfig)
        return defaultConfig
    }

    func loadWorkbenchConfig() throws -> GWorkbenchConfig {
        let configPath = resolveConfigPath(appName: "gworkbench", fileName: "config.toml")
        guard FileManager.default.fileExists(atPath: configPath) else {
            return try loadOrCreateWorkbenchConfig()
        }

        let config: GWorkbenchTomlConfig = try loadTomlFile(path: configPath)
        let configDirectory = URL(fileURLWithPath: configPath).deletingLastPathComponent()
        let metadataPath = ProcessRunner.expandPath(
            config.worktree.metadata_path
                ?? configDirectory.appendingPathComponent("worktree-metadata.toml").path
        )
        let envBranches = config.merge.env_branches ?? ["uat", "test", "stage", "pre_prod"]
        let mergeBranchMiddle = config.merge.merge_branch_middle
        let branchMap = config.branch_map ?? Dictionary(
            uniqueKeysWithValues: envBranches.map { ("\($0)_\(mergeBranchMiddle)_meger", $0) }
        )

        return GWorkbenchConfig(
            configPath: configPath,
            metadataPath: metadataPath,
            worktreeProjectsRootDirs: config.worktree.projects_root_dirs.map(ProcessRunner.expandPath),
            worktreesRootDir: ProcessRunner.expandPath(config.worktree.worktrees_root_dir),
            worktreePathTemplate: config.worktree.path_template ?? "${rootDir}/${project}/${branch}",
            ideMode: config.worktree.ide_mode ?? "app",
            ideCommand: config.worktree.ide_command ?? "open",
            ideLabel: config.worktree.ide_label ?? (config.worktree.ide_command ?? "默认应用"),
            terminalApp: config.worktree.terminal_app ?? "Terminal",
            terminalBundleID: config.worktree.terminal_bundle_id ?? "com.apple.Terminal",
            terminalLaunchHookMode: config.worktree.terminal_launch_hook_mode ?? "none",
            terminalLaunchCommand: config.worktree.terminal_launch_command ?? "git status",
            gitlabHost: config.gitlab.host,
            gitlabToken: config.gitlab.token,
            githubToken: config.github?.token ?? "",
            aiProvider: config.ai?.provider ?? "deepseek",
            aiBaseURL: config.ai?.base_url ?? "https://api.deepseek.com",
            aiAPIKey: config.ai?.api_key ?? "",
            aiModel: config.ai?.model ?? "deepseek-chat",
            aiCustomPrompt: config.ai?.custom_prompt ?? "",
            activeWorkflowPreset: config.merge.active_preset ?? "env_flow",
            githubDefaultTargetBranch: config.merge.github_default_target_branch ?? "main",
            mergeRootDirs: config.merge.root_dirs.map(ProcessRunner.expandPath),
            mergeBranchMiddle: mergeBranchMiddle,
            envBranches: envBranches,
            branchMap: branchMap,
            protectedTargets: config.merge_policy?.protected_targets ?? ["master", "main"],
            autoMergeDelaySeconds: config.merge_policy?.auto_merge_delay_seconds ?? 10,
            autoMergeRetryCount: config.merge_policy?.auto_merge_retry_count ?? 3
        )
    }

    func saveWorkbenchConfig(_ config: GWorkbenchConfig) throws {
        let configPath = resolveConfigPath(appName: "gworkbench", fileName: "config.toml")
        let normalized = normalizeWorkbenchConfig(config, configPath: configPath)
        let configURL = URL(fileURLWithPath: configPath)
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try serializeWorkbenchConfig(normalized).write(to: configURL, atomically: true, encoding: .utf8)
    }

    func normalizeWorkbenchConfig(_ config: GWorkbenchConfig, configPath: String) -> GWorkbenchConfig {
        let configDirectory = URL(fileURLWithPath: configPath).deletingLastPathComponent()
        let metadataDefaultPath = configDirectory.appendingPathComponent("worktree-metadata.toml").path
        return GWorkbenchConfig(
            configPath: configPath,
            metadataPath: ProcessRunner.expandPath(config.metadataPath.trimmedNonEmpty ?? metadataDefaultPath),
            worktreeProjectsRootDirs: dedupe(config.worktreeProjectsRootDirs.map(ProcessRunner.expandPath).filterNonEmpty()),
            worktreesRootDir: ProcessRunner.expandPath(config.worktreesRootDir),
            worktreePathTemplate: config.worktreePathTemplate.trimmedNonEmpty ?? "${rootDir}/${project}/${branch}",
            ideMode: config.ideMode.trimmedNonEmpty ?? "app",
            ideCommand: config.ideCommand.trimmedNonEmpty ?? "open",
            ideLabel: config.ideLabel.trimmedNonEmpty ?? (config.ideCommand.trimmedNonEmpty ?? "默认应用"),
            terminalApp: config.terminalApp.trimmedNonEmpty ?? "Terminal",
            terminalBundleID: config.terminalBundleID.trimmedNonEmpty ?? "com.apple.Terminal",
            terminalLaunchHookMode: config.terminalLaunchHookMode.trimmedNonEmpty ?? "none",
            terminalLaunchCommand: config.terminalLaunchCommand.trimmedNonEmpty ?? "git status",
            gitlabHost: normalizedGitLabHost(config.gitlabHost),
            gitlabToken: config.gitlabToken.trimmingCharacters(in: .whitespacesAndNewlines),
            githubToken: config.githubToken.trimmingCharacters(in: .whitespacesAndNewlines),
            aiProvider: config.aiProvider.trimmedNonEmpty ?? "deepseek",
            aiBaseURL: config.aiBaseURL.trimmedNonEmpty ?? "https://api.deepseek.com",
            aiAPIKey: config.aiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
            aiModel: config.aiModel.trimmedNonEmpty ?? "deepseek-chat",
            aiCustomPrompt: config.aiCustomPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            activeWorkflowPreset: config.activeWorkflowPreset.trimmedNonEmpty ?? "env_flow",
            githubDefaultTargetBranch: config.githubDefaultTargetBranch.trimmedNonEmpty ?? "main",
            mergeRootDirs: dedupe(config.mergeRootDirs.map(ProcessRunner.expandPath).filterNonEmpty()),
            mergeBranchMiddle: config.mergeBranchMiddle.trimmedNonEmpty ?? "henry",
            envBranches: dedupe(config.envBranches.filterNonEmpty()),
            branchMap: config.branchMap
                .filter { !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            protectedTargets: dedupe(config.protectedTargets.filterNonEmpty()),
            autoMergeDelaySeconds: max(config.autoMergeDelaySeconds, 0),
            autoMergeRetryCount: max(config.autoMergeRetryCount, 0)
        )
    }

    func serializeWorkbenchConfig(_ config: GWorkbenchConfig) -> String {
        let branchMapLines = config.branchMap
            .sorted { lhs, rhs in
                if lhs.key != rhs.key {
                    return lhs.key < rhs.key
                }
                return lhs.value < rhs.value
            }
            .map { "\($0.key) = \"\(escapeTomlString($0.value))\"" }

        let lines: [String] = [
            "[worktree]",
            "projects_root_dirs = \(tomlArray(config.worktreeProjectsRootDirs))",
            "worktrees_root_dir = \"\(escapeTomlString(config.worktreesRootDir))\"",
            "path_template = \"\(escapeTomlString(config.worktreePathTemplate))\"",
            "metadata_path = \"\(escapeTomlString(config.metadataPath))\"",
            "ide_mode = \"\(escapeTomlString(config.ideMode))\"",
            "ide_command = \"\(escapeTomlString(config.ideCommand))\"",
            "ide_label = \"\(escapeTomlString(config.ideLabel))\"",
            "terminal_app = \"\(escapeTomlString(config.terminalApp))\"",
            "terminal_bundle_id = \"\(escapeTomlString(config.terminalBundleID))\"",
            "terminal_launch_hook_mode = \"\(escapeTomlString(config.terminalLaunchHookMode))\"",
            "terminal_launch_command = \"\(escapeTomlString(config.terminalLaunchCommand))\"",
            "",
            "[gitlab]",
            "host = \"\(escapeTomlString(config.gitlabHost))\"",
            "token = \"\(escapeTomlString(config.gitlabToken))\"",
            "",
            "[github]",
            "token = \"\(escapeTomlString(config.githubToken))\"",
            "",
            "[ai]",
            "provider = \"\(escapeTomlString(config.aiProvider))\"",
            "base_url = \"\(escapeTomlString(config.aiBaseURL))\"",
            "api_key = \"\(escapeTomlString(config.aiAPIKey))\"",
            "model = \"\(escapeTomlString(config.aiModel))\"",
            "custom_prompt = \"\(escapeTomlString(config.aiCustomPrompt))\"",
            "",
            "[merge]",
            "active_preset = \"\(escapeTomlString(config.activeWorkflowPreset))\"",
            "github_default_target_branch = \"\(escapeTomlString(config.githubDefaultTargetBranch))\"",
            "root_dirs = \(tomlArray(config.mergeRootDirs))",
            "merge_branch_middle = \"\(escapeTomlString(config.mergeBranchMiddle))\"",
            "env_branches = \(tomlArray(config.envBranches))",
            "",
            "[branch_map]",
            branchMapLines.isEmpty ? "# source_branch = \"target_branch\"" : branchMapLines.joined(separator: "\n"),
            "",
            "[merge_policy]",
            "protected_targets = \(tomlArray(config.protectedTargets))",
            "auto_merge_delay_seconds = \(config.autoMergeDelaySeconds)",
            "auto_merge_retry_count = \(config.autoMergeRetryCount)",
            ""
        ]
        return lines.joined(separator: "\n")
    }

    func loadWorktreeMetadataMap(metadataPath: String) throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: metadataPath) else {
            return [:]
        }
        let metadata: WorktreeMetadataStore = try loadTomlFile(path: metadataPath)
        return Dictionary(
            uniqueKeysWithValues: metadata.descriptions.map {
                ("\(ProcessRunner.normalizePath($0.project_path))#\($0.branch)", $0.description)
            }
        )
    }

    func saveWorktreeDescription(
        metadataPath: String,
        projectPath: String,
        branch: String,
        description: String
    ) throws {
        let normalizedProjectPath = ProcessRunner.normalizePath(projectPath)
        var entries = try loadMetadataEntries(metadataPath: metadataPath)
        entries.removeAll { $0.projectPath == normalizedProjectPath && $0.branch == branch }
        entries.append(.init(projectPath: normalizedProjectPath, branch: branch, description: description))
        try writeMetadataEntries(entries, metadataPath: metadataPath)
    }

    func clearWorktreeDescription(
        metadataPath: String,
        projectPath: String,
        branch: String
    ) throws {
        let normalizedProjectPath = ProcessRunner.normalizePath(projectPath)
        var entries = try loadMetadataEntries(metadataPath: metadataPath)
        entries.removeAll { $0.projectPath == normalizedProjectPath && $0.branch == branch }
        try writeMetadataEntries(entries, metadataPath: metadataPath)
    }

    func loadMetadataEntries(metadataPath: String) throws -> [MetadataEntry] {
        guard FileManager.default.fileExists(atPath: metadataPath) else {
            return []
        }
        let metadata: WorktreeMetadataStore = try loadTomlFile(path: metadataPath)
        return metadata.descriptions.map {
            MetadataEntry(
                projectPath: ProcessRunner.normalizePath($0.project_path),
                branch: $0.branch,
                description: $0.description
            )
        }
    }

    func writeMetadataEntries(_ entries: [MetadataEntry], metadataPath: String) throws {
        let sortedEntries = entries.sorted {
            if $0.projectPath != $1.projectPath {
                return $0.projectPath < $1.projectPath
            }
            return $0.branch < $1.branch
        }

        let lines = sortedEntries.flatMap { entry in
            [
                "[[descriptions]]",
                "project_path = \"\(escapeTomlString(entry.projectPath))\"",
                "branch = \"\(escapeTomlString(entry.branch))\"",
                "description = \"\(escapeTomlString(entry.description))\"",
                ""
            ]
        }

        let metadataURL = URL(fileURLWithPath: metadataPath)
        try FileManager.default.createDirectory(at: metadataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try lines.joined(separator: "\n").write(to: metadataURL, atomically: true, encoding: .utf8)
    }

    func escapeTomlString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    func tomlArray(_ values: [String]) -> String {
        let items = values.map { "\"\(escapeTomlString($0))\"" }.joined(separator: ", ")
        return "[\(items)]"
    }

    func dedupe(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
