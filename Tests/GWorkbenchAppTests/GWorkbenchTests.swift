import Foundation
import Testing
@testable import GWorkbenchApp

@Suite("GWorkbench Core Tests")
struct GWorkbenchTests {
    @Test("RepositoryPlatform detects GitHub, GitLab, custom host, and local")
    func platformDetection() {
        #expect(RepositoryPlatform.detect(remoteURL: "git@github.com:life2you/gworkbench.git") == .github)
        #expect(RepositoryPlatform.detect(remoteURL: "https://github.com/life2you/gworkbench") == .github)
        #expect(RepositoryPlatform.detect(remoteURL: "git@gitlab.com:team/app.git") == .gitlab)
        #expect(RepositoryPlatform.detect(remoteURL: "https://gitlab.internal.company.com/core/api.git") == .gitlab)
        #expect(RepositoryPlatform.detect(remoteURL: "https://git.corp.example.com/team/repo.git", gitlabHost: "https://git.corp.example.com") == .gitlab)
        #expect(RepositoryPlatform.detect(remoteURL: nil) == .local)
        #expect(RepositoryPlatform.detect(remoteURL: "") == .local)
    }

    @Test("GitHubProvider parses owner/repo slug and resolves Enterprise host URLs")
    func githubSlugParsing() {
        #expect(GitHubProvider.parseRepoSlug(from: "git@github.com:life2you/gworkbench.git") == "life2you/gworkbench")
        #expect(GitHubProvider.parseRepoSlug(from: "https://github.com/life2you/gworkbench.git") == "life2you/gworkbench")
        #expect(GitHubProvider.parseRepoSlug(from: "https://github.com/life2you/gworkbench/") == "life2you/gworkbench")
        #expect(GitHubProvider.parseRepoSlug(from: "ssh://git@github.com/org/repo.git") == "org/repo")
        #expect(GitHubProvider.parseRepoSlug(from: nil) == nil)

        #expect(GitHubProvider.apiBaseURL(from: "") == "https://api.github.com")
        #expect(GitHubProvider.apiBaseURL(from: "https://github.com") == "https://api.github.com")
        #expect(GitHubProvider.apiBaseURL(from: "https://github.company.com/") == "https://github.company.com/api/v3")
        #expect(GitHubProvider.apiBaseURL(from: "github.company.com/api/v3") == "https://github.company.com/api/v3")
        #expect(GitHubProvider.cliHostname(from: "https://github.com") == nil)
        #expect(GitHubProvider.cliHostname(from: "https://github.company.com") == "github.company.com")
    }

    @Test("Default config contains no personal hardcoding and round-trips through TOML")
    func configDefaultAndRoundTrip() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let service = ConfigService()
        let configPath = tempDir.appendingPathComponent("config.toml").path
        let defaults = service.defaultWorkbenchConfig(configPath: configPath)

        #expect(defaults.gitlabHost.isEmpty)
        #expect(defaults.mergeBranchMiddle == "feature")
        #expect(!defaults.mergeBranchMiddle.contains("henry"))
        #expect(defaults.githubDashboardBaselines == ["main"])
        #expect(defaults.gitlabDashboardBaselines == ["master", "stage", "test", "uat"])

        let workspaces = [
            WorkspaceProfile(
                id: "ws-gh",
                name: "个人 GitHub",
                platform: .github,
                projectsRootDirs: ["/tmp/projects"],
                worktreesRootDir: "",
                host: "https://github.company.com",
                token: "ghp_test",
                defaultTargetBranch: "main",
                dashboardBaselines: ["main", "develop"],
                envBranches: [],
                mergeBranchMiddle: "",
                branchMap: [:]
            ),
            WorkspaceProfile(
                id: "ws-gl",
                name: "公司 GitLab",
                platform: .gitlab,
                projectsRootDirs: ["/tmp/work"],
                worktreesRootDir: "",
                host: "https://gitlab.example.com",
                token: "tok",
                defaultTargetBranch: "master",
                dashboardBaselines: ["master", "staging"],
                envBranches: ["dev", "staging"],
                mergeBranchMiddle: "sync",
                branchMap: ["dev_sync": "dev"]
            )
        ]

        var modified = defaults
        modified = GWorkbenchConfig(
            configPath: defaults.configPath,
            metadataPath: defaults.metadataPath,
            worktreeProjectsRootDirs: ["/tmp/projects"],
            worktreesRootDir: defaults.worktreesRootDir,
            worktreePathTemplate: defaults.worktreePathTemplate,
            ideMode: "app",
            ideCommand: "Cursor",
            ideLabel: "Cursor",
            ideProfiles: [
                IDEProfile(id: "ide-cursor", label: "Cursor", mode: "app", command: "Cursor"),
                IDEProfile(id: "ide-idea", label: "IntelliJ IDEA", mode: "app", command: "IntelliJ IDEA"),
                IDEProfile(id: "ide-vscode", label: "VS Code CLI", mode: "custom", command: "code")
            ],
            defaultIDEProfileID: "ide-idea",
            terminalApp: defaults.terminalApp,
            terminalBundleID: defaults.terminalBundleID,
            terminalLaunchHookMode: defaults.terminalLaunchHookMode,
            terminalLaunchCommand: defaults.terminalLaunchCommand,
            gitlabHost: "https://gitlab.example.com",
            gitlabToken: "tok",
            githubHost: "https://github.company.com",
            githubToken: "ghp_test",
            aiProvider: defaults.aiProvider,
            aiBaseURL: defaults.aiBaseURL,
            aiAPIKey: defaults.aiAPIKey,
            aiModel: defaults.aiModel,
            aiCustomPrompt: defaults.aiCustomPrompt,
            activeWorkflowPreset: "github",
            activePlatform: "github",
            activeWorkspaceID: "ws-gl",
            workspaces: workspaces,
            githubDefaultTargetBranch: "main",
            githubDashboardBaselines: ["main", "develop"],
            gitlabDashboardBaselines: ["master", "staging"],
            mergeRootDirs: ["/tmp/projects"],
            mergeBranchMiddle: "sync",
            envBranches: ["dev", "staging"],
            branchMap: ["dev_sync": "dev"],
            protectedTargets: ["main", "master"],
            autoMergeDelaySeconds: 5,
            autoMergeRetryCount: 2,
            syncIDEConfigs: true,
            ideConfigSyncItems: defaults.ideConfigSyncItems
        )

        let normalized = service.normalizeWorkbenchConfig(modified, configPath: configPath)
        let tomlText = service.serializeWorkbenchConfig(normalized)
        try tomlText.write(toFile: configPath, atomically: true, encoding: .utf8)
        let readBack = try String(contentsOfFile: configPath, encoding: .utf8)
        #expect(readBack.contains("[app]"))
        #expect(readBack.contains("[[workspaces]]"))
        #expect(readBack.contains("[[ide_profiles]]"))
        #expect(readBack.contains("active_workspace_id = \"ws-gl\""))
        #expect(!readBack.contains("[gitlab]"))
        #expect(!readBack.contains("[github]"))
        #expect(!readBack.contains("[merge]"))
        #expect(!readBack.contains("[branch_map]"))
        #expect(!readBack.contains("default_target_branch"))

        let reloaded = try service.loadWorkbenchConfig(at: configPath)
        #expect(reloaded.activeWorkspaceID == "ws-gl")
        #expect(reloaded.workspaces.count == 2)
        #expect(reloaded.workspaces[0].name == "个人 GitHub")
        #expect(reloaded.workspaces[0].effectiveDashboardBaselines == ["main", "develop"])
        #expect(reloaded.workspaces[1].effectiveDashboardBaselines == ["master", "staging"])
        #expect(reloaded.effectiveIDEProfiles.count == 3)
        #expect(reloaded.defaultIDEProfile.id == "ide-idea")
        #expect(reloaded.defaultIDEProfile.effectiveLabel == "IntelliJ IDEA")
        #expect(reloaded.ideCommand == "IntelliJ IDEA")
        #expect(reloaded.workspaces[0].host == "https://github.company.com")
        #expect(reloaded.workspaces[1].branchMap["dev_sync"] == "dev")

        // 验证老版本扁平 config.toml 依然可以无缝迁移
        let legacyToml = """
        [worktree]
        projects_root_dirs = ["/tmp/legacy-gl"]
        worktrees_root_dir = "/tmp/wt"
        ide_mode = "app"
        ide_command = "Cursor"
        ide_label = "Cursor"

        [gitlab]
        host = "https://git.legacy.internal"
        token = "glpat-legacy"

        [merge]
        root_dirs = ["/tmp/legacy-gl"]
        merge_branch_middle = "sync"
        env_branches = ["dev", "test"]
        gitlab_dashboard_baselines = ["master", "test"]

        [branch_map]
        dev_sync = "dev"
        """
        let legacyPath = tempDir.appendingPathComponent("legacy-config.toml").path
        try legacyToml.write(toFile: legacyPath, atomically: true, encoding: .utf8)
        let migrated = try service.loadWorkbenchConfig(at: legacyPath)
        #expect(migrated.workspaces.count == 1)
        #expect(migrated.workspaces[0].platform == .gitlab)
        #expect(migrated.workspaces[0].host == "https://git.legacy.internal")
        #expect(migrated.workspaces[0].branchMap["dev_sync"] == "dev")
        #expect(migrated.defaultIDEProfile.command == "Cursor")
    }

    @Test("BranchSyncService generates clean sync branch names and respects legacy branchMap")
    func branchSyncNaming() {
        #expect(BranchSyncService.mergeBranchName(envBranch: "staging", middle: "sync", projectName: "demo") == "staging_sync")
        #expect(BranchSyncService.mergeBranchName(envBranch: "dev", middle: "PROJECT_NAME", projectName: "app") == "dev_app")

        let service = BranchSyncService()
        let config = MergeWorkflowConfig(
            configPath: "",
            host: "",
            token: "",
            rootDirs: [],
            mergeBranchMiddle: "sync",
            envBranches: ["dev", "staging"],
            branchMap: ["dev_sync": "dev", "staging_sync": "staging"],
            protectedTargets: ["main"],
            autoMergeDelaySeconds: 0,
            autoMergeRetryCount: 0
        )
        let mappings = service.effectiveMRBranchMappings(config: config)
        #expect(mappings.count == 2)
        #expect(mappings.contains(where: { $0.source == "dev_sync" && $0.target == "dev" }))
    }

    @Test("WorktreeSweeperItem evaluates dynamic baselines for GitHub and GitLab")
    func sweeperDynamicBaselines() {
        let item = WorktreeItem(
            id: "1",
            project: "demo",
            projectName: "demo",
            projectPath: "/tmp/demo",
            branch: "feat/login",
            summary: "feat",
            updatedAt: "今天",
            kind: .worktree,
            path: "/tmp/wt-feat",
            upstream: "origin/feat/login",
            head: "abc",
            createdDetail: "",
            diskUsage: "10 MB",
            canRemoveRemoteBranch: true,
            commits: [],
            isDirty: false,
            dirtySummary: "干净",
            platform: .github
        )

        let ghSweeper = WorktreeSweeperItem(
            id: "1",
            worktree: item,
            statusType: .fullyMerged,
            statusTitle: "已全部合入 (1/1)",
            statusDescription: "已合并到 main",
            isProtected: false,
            isRecommended: true,
            diskUsageFormatted: "10 MB",
            approxSizeMB: 10,
            mergeTargets: ["main"],
            mergeStatus: ["main": true]
        )
        #expect(ghSweeper.isFullyMerged == true)
        #expect(ghSweeper.mergedCount == 1)
        #expect(ghSweeper.totalMergeTargets == 1)

        let glSweeper = WorktreeSweeperItem(
            id: "2",
            worktree: item,
            statusType: .partiallyMerged(mergedCount: 1),
            statusTitle: "仅合入 1/2",
            statusDescription: "部分合并",
            isProtected: false,
            isRecommended: false,
            diskUsageFormatted: "10 MB",
            approxSizeMB: 10,
            mergeTargets: ["master", "stage"],
            mergeStatus: ["master": false, "stage": true]
        )
        #expect(glSweeper.isFullyMerged == false)
        #expect(glSweeper.mergedCount == 1)
        #expect(WorktreeSweeperAnalyzer.sortScore(ghSweeper) > WorktreeSweeperAnalyzer.sortScore(glSweeper))
        #expect(WorktreeSweeperAnalyzer.parseDiskUsageToMB("1.5 GB") == 1536)
    }

    @Test("WorktreeService syncs .vscode, .env.local, and .idea files into new worktree")
    func ideConfigSync() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let src = root.appendingPathComponent("src", isDirectory: true)
        let dst = root.appendingPathComponent("dst", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: src.appendingPathComponent(".vscode", isDirectory: true), withIntermediateDirectories: true)
        try fm.createDirectory(at: src.appendingPathComponent(".idea", isDirectory: true), withIntermediateDirectories: true)
        try fm.createDirectory(at: dst, withIntermediateDirectories: true)

        try "{\"editor.tabSize\": 2}".write(to: src.appendingPathComponent(".vscode/settings.json"), atomically: true, encoding: .utf8)
        try "PORT=3000".write(to: src.appendingPathComponent(".env.local"), atomically: true, encoding: .utf8)
        try "<project/>".write(to: src.appendingPathComponent(".idea/misc.xml"), atomically: true, encoding: .utf8)

        let service = WorktreeService()
        let logs = service.syncIDEConfigs(
            items: [".vscode/settings.json", ".env.local", "misc.xml"],
            sourceProjectPath: src.path,
            targetPath: dst.path
        )

        #expect(fm.fileExists(atPath: dst.appendingPathComponent(".vscode/settings.json").path))
        #expect(fm.fileExists(atPath: dst.appendingPathComponent(".env.local").path))
        #expect(fm.fileExists(atPath: dst.appendingPathComponent(".idea/misc.xml").path))
        #expect(logs.joined(separator: "\n").contains("已同步 IDE 配置 3 项"))
    }

    @Test("GitCliService scanProjectPlaceholders discovers git repos and HEAD branch without spawning processes")
    func fastPlaceholderScan() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let repoA = root.appendingPathComponent("alpha-repo", isDirectory: true)
        let gitA = repoA.appendingPathComponent(".git", isDirectory: true)
        try fm.createDirectory(at: gitA, withIntermediateDirectories: true)
        try "ref: refs/heads/feat/fast-switch\n".write(to: gitA.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)

        let nonRepo = root.appendingPathComponent("notes-folder", isDirectory: true)
        try fm.createDirectory(at: nonRepo, withIntermediateDirectories: true)

        let placeholders = GitCliService().scanProjectPlaceholders(rootDirs: [root.path], forcedPlatform: .gitlab)
        #expect(placeholders.count == 1)
        #expect(placeholders[0].displayName == "alpha-repo")
        #expect(placeholders[0].currentBranch == "feat/fast-switch")
        #expect(placeholders[0].platform == .gitlab)
    }

    @Test("WorkspaceProfile separates production mainline branches from non-prod protected branches")
    func mainlineAndProtectedBranchesSeparation() throws {
        var draft = WorkspaceProfileDraft(
            name: "Company GitLab",
            platform: .gitlab,
            defaultTargetBranch: "master",
            mainlineBranchesText: "master, prod",
            dashboardBaselinesText: "master, prod, stage, test",
            envBranchesText: "dev, test, stage",
            mergeBranchMiddle: "sync"
        )
        #expect(draft.mainlineBranchList == ["master", "prod"])
        #expect(draft.protectedEnvBranchList == ["dev", "test", "stage"])

        let profile = draft.toWorkspaceProfile()
        #expect(profile.effectiveMainlineBranches == ["master", "prod"])
        #expect(profile.effectiveProtectedBranches == ["dev", "test", "stage"])
        #expect(profile.allProtectedMergeTargets == ["master", "prod", "dev", "test", "stage"])
        #expect(profile.defaultTargetBranch == "master")

        draft.mainlineBranchList = ["main", "prod"]
        #expect(draft.defaultTargetBranch == "main")

        let envDraft = WorkspaceProfileDraft(
            name: "GitLab",
            platform: .gitlab,
            defaultTargetBranch: "master",
            mainlineBranchesText: "master",
            dashboardBaselinesText: "master, stage, test, uat",
            envBranchesText: "test, stage, uat",
            mergeBranchMiddle: "henry_meger"
        )
        let mappings = envDraft.buildRecommendedBranchMappings()
        #expect(mappings.map { "\($0.source)->\($0.target)" } == [
            "uat->master",
            "uat_henry_meger->uat",
            "stage_henry_meger->stage",
            "test_henry_meger->test"
        ])

        var cfg = ConfigService().defaultWorkbenchConfig(configPath: "/tmp/test.toml")
        cfg = GWorkbenchConfig(
            configPath: cfg.configPath,
            metadataPath: cfg.metadataPath,
            worktreeProjectsRootDirs: cfg.worktreeProjectsRootDirs,
            worktreesRootDir: cfg.worktreesRootDir,
            worktreePathTemplate: cfg.worktreePathTemplate,
            ideMode: cfg.ideMode,
            ideCommand: cfg.ideCommand,
            ideLabel: cfg.ideLabel,
            terminalApp: cfg.terminalApp,
            terminalBundleID: cfg.terminalBundleID,
            terminalLaunchHookMode: cfg.terminalLaunchHookMode,
            terminalLaunchCommand: cfg.terminalLaunchCommand,
            gitlabHost: cfg.gitlabHost,
            gitlabToken: cfg.gitlabToken,
            githubHost: cfg.githubHost,
            githubToken: cfg.githubToken,
            aiProvider: cfg.aiProvider,
            aiBaseURL: cfg.aiBaseURL,
            aiAPIKey: cfg.aiAPIKey,
            aiModel: cfg.aiModel,
            aiCustomPrompt: cfg.aiCustomPrompt,
            activeWorkflowPreset: cfg.activeWorkflowPreset,
            activePlatform: "GitLab",
            activeWorkspaceID: envDraft.id,
            workspaces: [envDraft.toWorkspaceProfile()],
            githubDefaultTargetBranch: cfg.githubDefaultTargetBranch,
            githubDashboardBaselines: cfg.githubDashboardBaselines,
            gitlabDashboardBaselines: cfg.gitlabDashboardBaselines,
            mergeRootDirs: cfg.mergeRootDirs,
            mergeBranchMiddle: "sync",
            envBranches: ["dev", "staging"],
            branchMap: [:],
            protectedTargets: ["main"],
            autoMergeDelaySeconds: 5,
            autoMergeRetryCount: 2,
            syncIDEConfigs: cfg.syncIDEConfigs,
            ideConfigSyncItems: cfg.ideConfigSyncItems
        )
        let mergeCfg = cfg.asMergeWorkflowConfig(for: envDraft.toWorkspaceProfile())
        #expect(mergeCfg.protectedTargets == ["main", "master"])
        #expect(!mergeCfg.protectedTargets.contains("test"))

        // 验证主干分支允许置空（未配置主干分支），且持久化往返不会强行补回默认值
        var noMainlineDraft = envDraft
        noMainlineDraft.mainlineBranchList = []
        let noMainlineProfile = noMainlineDraft.toWorkspaceProfile()
        #expect(noMainlineProfile.configuredMainlineBranches.isEmpty)
        #expect(noMainlineProfile.primaryMainlineBranch == nil)

        let configService = ConfigService()
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("toml")
        defer { try? FileManager.default.removeItem(at: tempFile) }
        var noMainlineCfg = cfg
        noMainlineCfg = GWorkbenchConfig(
            configPath: tempFile.path,
            metadataPath: cfg.metadataPath,
            worktreeProjectsRootDirs: cfg.worktreeProjectsRootDirs,
            worktreesRootDir: cfg.worktreesRootDir,
            worktreePathTemplate: cfg.worktreePathTemplate,
            ideMode: cfg.ideMode,
            ideCommand: cfg.ideCommand,
            ideLabel: cfg.ideLabel,
            terminalApp: cfg.terminalApp,
            terminalBundleID: cfg.terminalBundleID,
            terminalLaunchHookMode: cfg.terminalLaunchHookMode,
            terminalLaunchCommand: cfg.terminalLaunchCommand,
            gitlabHost: cfg.gitlabHost,
            gitlabToken: cfg.gitlabToken,
            githubHost: cfg.githubHost,
            githubToken: cfg.githubToken,
            aiProvider: cfg.aiProvider,
            aiBaseURL: cfg.aiBaseURL,
            aiAPIKey: cfg.aiAPIKey,
            aiModel: cfg.aiModel,
            aiCustomPrompt: cfg.aiCustomPrompt,
            activeWorkflowPreset: cfg.activeWorkflowPreset,
            activePlatform: "GitLab",
            activeWorkspaceID: noMainlineProfile.id,
            workspaces: [noMainlineProfile],
            githubDefaultTargetBranch: cfg.githubDefaultTargetBranch,
            githubDashboardBaselines: cfg.githubDashboardBaselines,
            gitlabDashboardBaselines: cfg.gitlabDashboardBaselines,
            mergeRootDirs: cfg.mergeRootDirs,
            mergeBranchMiddle: "sync",
            envBranches: ["test"],
            branchMap: [:],
            protectedTargets: ["main"],
            autoMergeDelaySeconds: 5,
            autoMergeRetryCount: 2,
            syncIDEConfigs: cfg.syncIDEConfigs,
            ideConfigSyncItems: cfg.ideConfigSyncItems
        )
        let normalizedNoMainline = configService.normalizeWorkbenchConfig(noMainlineCfg, configPath: tempFile.path)
        try configService.serializeWorkbenchConfig(normalizedNoMainline).write(to: tempFile, atomically: true, encoding: .utf8)
        let reloadedNoMainline = try configService.loadWorkbenchConfig(at: tempFile.path)
        #expect(reloadedNoMainline.workspaces[0].configuredMainlineBranches.isEmpty)
        #expect(reloadedNoMainline.asMergeWorkflowConfig(for: reloadedNoMainline.workspaces[0]).mainlineBranches.isEmpty)
    }

    @Test("BranchSyncService switches back to configured mainline branch after sync and merge, and stays put when unconfigured")
    func branchSyncAndMergeRestoreMainlineBehavior() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let remoteRepo = root.appendingPathComponent("remote.git", isDirectory: true)
        let localRepo = root.appendingPathComponent("demo", isDirectory: true)

        _ = try ProcessRunner.runGit(arguments: ["init", "--bare", remoteRepo.path])
        _ = try ProcessRunner.runGit(arguments: ["clone", remoteRepo.path, localRepo.path])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "config", "user.name", "Test User"])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "config", "user.email", "test@example.com"])

        try "init\n".write(to: localRepo.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "add", "README.md"])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "commit", "-m", "init"])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "branch", "-M", "master"])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "push", "-u", "origin", "master"])

        // 创建环境分支 test、集成分支 test_sync、特性分支 feat/a
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "checkout", "-b", "test"])
        try "env\n".write(to: localRepo.appendingPathComponent("env.txt"), atomically: true, encoding: .utf8)
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "add", "env.txt"])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "commit", "-m", "env"])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "push", "-u", "origin", "test"])

        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "checkout", "-b", "test_sync", "test"])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "push", "-u", "origin", "test_sync"])

        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "checkout", "-b", "feat/a", "master"])
        try "feature\n".write(to: localRepo.appendingPathComponent("feat.txt"), atomically: true, encoding: .utf8)
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "add", "feat.txt"])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "commit", "-m", "feat"])

        let gitCli = GitCliService()
        let syncService = BranchSyncService(gitCli: gitCli)
        let project = MergeProject(
            id: "demo",
            name: "demo",
            displayName: "demo",
            path: localRepo.path,
            sourceRoot: root.path,
            currentBranch: "feat/a",
            gitLabProjectID: nil,
            branchMappings: [],
            remoteBranches: ["master", "test", "test_sync"],
            localBranches: ["master", "test", "test_sync", "feat/a"],
            platform: .gitlab
        )

        // 1. 配置了主干分支 master 时：同步环境分支后自动切回 master
        let cfgWithMainline = MergeWorkflowConfig(
            configPath: "",
            host: "",
            token: "",
            rootDirs: [root.path],
            mergeBranchMiddle: "sync",
            envBranches: ["test"],
            branchMap: ["test_sync": "test"],
            protectedTargets: ["master"],
            mainlineBranches: ["master"],
            autoMergeDelaySeconds: 0,
            autoMergeRetryCount: 0
        )
        _ = try syncService.syncAndPushWithProgress(project: project, config: cfgWithMainline) { _ in }
        #expect(try gitCli.currentLocalBranch(projectPath: localRepo.path) == "master")

        // 2. 配置了主干分支 master 时：合并功能完成后自动切回 master
        _ = try syncService.mergeToTargetsWithProgress(
            project: project,
            config: cfgWithMainline,
            sourceBranch: "feat/a",
            targets: ["test_sync"]
        ) { _ in }
        #expect(try gitCli.currentLocalBranch(projectPath: localRepo.path) == "master")

        // 3. 未配置主干分支时：同步环境分支与合并完成后停留在目标分支 test_sync，不切回 master
        let cfgNoMainline = MergeWorkflowConfig(
            configPath: "",
            host: "",
            token: "",
            rootDirs: [root.path],
            mergeBranchMiddle: "sync",
            envBranches: ["test"],
            branchMap: ["test_sync": "test"],
            protectedTargets: [],
            mainlineBranches: [],
            autoMergeDelaySeconds: 0,
            autoMergeRetryCount: 0
        )
        _ = try gitCli.checkoutBranch(projectPath: localRepo.path, branch: "feat/a")
        _ = try syncService.syncAndPushWithProgress(project: project, config: cfgNoMainline) { _ in }
        #expect(try gitCli.currentLocalBranch(projectPath: localRepo.path) == "test_sync")

        _ = try gitCli.checkoutBranch(projectPath: localRepo.path, branch: "feat/a")
        _ = try syncService.mergeToTargetsWithProgress(
            project: project,
            config: cfgNoMainline,
            sourceBranch: "feat/a",
            targets: ["test_sync"]
        ) { _ in }
        #expect(try gitCli.currentLocalBranch(projectPath: localRepo.path) == "test_sync")
    }

    @Test("Interactive conflict resolution detects Rebased staging, external commit, external abort, and avoids committing untracked .idea files")
    func interactiveConflictResolutionClosure() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let remoteRepo = root.appendingPathComponent("remote.git", isDirectory: true)
        let localRepo = root.appendingPathComponent("demo", isDirectory: true)

        _ = try ProcessRunner.runGit(arguments: ["init", "--bare", remoteRepo.path])
        _ = try ProcessRunner.runGit(arguments: ["clone", remoteRepo.path, localRepo.path])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "config", "user.name", "Test User"])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "config", "user.email", "test@example.com"])

        // 1. 初始化 main 与共同祖先
        try "line1\nvalue=base\n".write(to: localRepo.appendingPathComponent("app.txt"), atomically: true, encoding: .utf8)
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "add", "app.txt"])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "commit", "-m", "init"])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "branch", "-M", "main"])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "push", "-u", "origin", "main"])

        // 2. 创建 stage_sync 分支并修改 app.txt
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "checkout", "-b", "stage_sync"])
        try "line1\nvalue=stage\n".write(to: localRepo.appendingPathComponent("app.txt"), atomically: true, encoding: .utf8)
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "commit", "-am", "stage change"])
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "push", "-u", "origin", "stage_sync"])

        // 3. 创建 feat/a 和 feat/b 两个分支，均与 stage_sync 冲突
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "checkout", "-b", "feat/a", "main"])
        try "line1\nvalue=feat-a\n".write(to: localRepo.appendingPathComponent("app.txt"), atomically: true, encoding: .utf8)
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "commit", "-am", "feat a change"])

        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "checkout", "-b", "feat/b", "main"])
        try "line1\nvalue=feat-b\n".write(to: localRepo.appendingPathComponent("app.txt"), atomically: true, encoding: .utf8)
        _ = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "commit", "-am", "feat b change"])

        // 模拟 Rebased 生成的未追踪 .idea 目录
        let ideaDir = localRepo.appendingPathComponent(".idea", isDirectory: true)
        try fm.createDirectory(at: ideaDir, withIntermediateDirectories: true)
        try "<project/>\n".write(to: ideaDir.appendingPathComponent("misc.xml"), atomically: true, encoding: .utf8)

        let gitCli = GitCliService()
        let syncService = BranchSyncService(gitCli: gitCli)

        // --- 场景 A：Rebased 点 Accept and Finish 仅 git add，未自动 commit ---
        let mergeResultA = try syncService.syncToMergeBranchInteractive(
            projectPath: localRepo.path,
            sourceBranch: "feat/a",
            mergeBranch: "stage_sync"
        )
        guard case .conflict(let conflictFilesA) = mergeResultA else {
            Issue.record("预期发生冲突")
            return
        }
        #expect(conflictFilesA == ["app.txt"])
        let mergeHeadA = try #require(try gitCli.activeMergeHeadSHA(projectPath: localRepo.path))

        // 刚发生冲突时仍有冲突标记
        let initialState = try gitCli.inspectMergeState(projectPath: localRepo.path, sourceRef: mergeHeadA)
        #expect(initialState == .mergingWithUnresolvedFiles(conflictFiles: ["app.txt"], markerFreeFiles: []))

        // 模拟用户在编辑器解决了冲突标记但尚未 git add
        try "line1\nvalue=resolved-a\n".write(to: localRepo.appendingPathComponent("app.txt"), atomically: true, encoding: .utf8)
        let markerFreeState = try gitCli.inspectMergeState(projectPath: localRepo.path, sourceRef: mergeHeadA)
        #expect(markerFreeState == .mergingWithUnresolvedFiles(conflictFiles: ["app.txt"], markerFreeFiles: ["app.txt"]))

        // 模拟 Rebased Accept and Finish 执行 git add app.txt（不执行 commit）
        try gitCli.stageFiles(projectPath: localRepo.path, files: ["app.txt"])
        let readyState = try gitCli.inspectMergeState(projectPath: localRepo.path, sourceRef: mergeHeadA)
        #expect(readyState == .mergingReadyToCommit)

        // 验证 ActiveSyncSession 在 conflictFiles 为空但 readyToCommit 时横幅仍保持显示
        let session = ActiveSyncSession(
            projectID: "demo",
            projectPath: localRepo.path,
            projectName: "demo",
            initialBranch: "feat/a",
            targets: [SyncSessionTargetItem(sourceBranch: "feat/a", targetBranch: "stage_sync", status: .inProgress)],
            currentTargetIndex: 0,
            activeConflictFiles: [],
            conflictPhase: .readyToCommit,
            conflictMergeHeadSHA: mergeHeadA
        )
        #expect(session.hasActiveConflict == true)
        #expect(session.canCommitAndContinue == true)

        // 自动收尾应生成标准双亲 Merge Commit 并推送，且不能把 .idea/misc.xml 提交进去
        _ = try syncService.finalizeResolvedMergeAndPush(
            projectPath: localRepo.path,
            sourceRef: mergeHeadA,
            mergeBranch: "stage_sync"
        )
        #expect(try gitCli.hasActiveMergeHead(projectPath: localRepo.path) == false)
        let parentsLine = try ProcessRunner.runGit(
            arguments: ["-C", localRepo.path, "rev-list", "--parents", "-n", "1", "HEAD"]
        ).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(parentsLine.split(separator: " ").count == 3) // commit + 2 parents

        let committedFiles = try ProcessRunner.runGit(
            arguments: ["-C", localRepo.path, "show", "--name-only", "--pretty=format:", "HEAD"]
        ).stdout
        #expect(!committedFiles.contains(".idea/misc.xml"))
        #expect(fm.fileExists(atPath: ideaDir.appendingPathComponent("misc.xml").path))

        // --- 场景 B：用户在外部（Rebased）自己点了 Commit，但未 Push ---
        let mergeResultB = try syncService.syncToMergeBranchInteractive(
            projectPath: localRepo.path,
            sourceBranch: "feat/b",
            mergeBranch: "stage_sync"
        )
        guard case .conflict = mergeResultB else {
            Issue.record("预期 feat/b 与 stage_sync 发生冲突")
            return
        }
        let mergeHeadB = try #require(try gitCli.activeMergeHeadSHA(projectPath: localRepo.path))

        try "line1\nvalue=resolved-b\n".write(to: localRepo.appendingPathComponent("app.txt"), atomically: true, encoding: .utf8)
        try gitCli.stageFiles(projectPath: localRepo.path, files: ["app.txt"])
        try gitCli.commitMerge(projectPath: localRepo.path)

        let externalCommitState = try gitCli.inspectMergeState(projectPath: localRepo.path, sourceRef: mergeHeadB)
        #expect(externalCommitState == .committedExternally)

        // 幂等收尾不应因工作区干净而报错，应直接推送成功
        _ = try syncService.finalizeResolvedMergeAndPush(
            projectPath: localRepo.path,
            sourceRef: mergeHeadB,
            mergeBranch: "stage_sync"
        )
        let localHead = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "rev-parse", "HEAD"]).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let remoteHead = try ProcessRunner.runGit(arguments: ["-C", localRepo.path, "rev-parse", "origin/stage_sync"]).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(localHead == remoteHead)
    }

    @Test("External merge abort is accurately detected without confusing with committed state")
    func externalMergeAbortDetection() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let repo = root.appendingPathComponent("demo", isDirectory: true)
        _ = try ProcessRunner.runGit(arguments: ["init", repo.path])
        _ = try ProcessRunner.runGit(arguments: ["-C", repo.path, "config", "user.name", "Test User"])
        _ = try ProcessRunner.runGit(arguments: ["-C", repo.path, "config", "user.email", "test@example.com"])

        try "v1\n".write(to: repo.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try ProcessRunner.runGit(arguments: ["-C", repo.path, "add", "file.txt"])
        _ = try ProcessRunner.runGit(arguments: ["-C", repo.path, "commit", "-m", "init"])
        _ = try ProcessRunner.runGit(arguments: ["-C", repo.path, "branch", "-M", "main"])

        _ = try ProcessRunner.runGit(arguments: ["-C", repo.path, "checkout", "-b", "target"])
        try "v-target\n".write(to: repo.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try ProcessRunner.runGit(arguments: ["-C", repo.path, "commit", "-am", "target"])

        _ = try ProcessRunner.runGit(arguments: ["-C", repo.path, "checkout", "-b", "source", "main"])
        try "v-source\n".write(to: repo.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try ProcessRunner.runGit(arguments: ["-C", repo.path, "commit", "-am", "source"])

        _ = try ProcessRunner.runGit(arguments: ["-C", repo.path, "checkout", "target"])
        let gitCli = GitCliService()
        let result = try gitCli.mergeBranchInteractive(projectPath: repo.path, sourceBranch: "source")
        guard case .conflict = result else {
            Issue.record("预期发生冲突")
            return
        }
        let mergeHead = try #require(try gitCli.activeMergeHeadSHA(projectPath: repo.path))

        try gitCli.abortMerge(projectPath: repo.path)
        let abortedState = try gitCli.inspectMergeState(projectPath: repo.path, sourceRef: mergeHead)
        #expect(abortedState == .abortedExternally)
    }

    @Test("TerminalService correctly identifies Otty, iTerm, Terminal, and modern terminals")
    func terminalKindDetection() {
        let service = TerminalService.shared

        #expect(service.detectTerminalKind(terminalName: "Otty", bundleID: "io.appmakes.otty") == .otty)
        #expect(service.detectTerminalKind(terminalName: "otty", bundleID: nil) == .otty)
        #expect(service.detectTerminalKind(terminalName: "Custom", bundleID: "io.appmakes.otty") == .otty)

        #expect(service.detectTerminalKind(terminalName: "iTerm", bundleID: "com.googlecode.iterm2") == .iterm)
        #expect(service.detectTerminalKind(terminalName: "iTerm2", bundleID: nil) == .iterm)

        #expect(service.detectTerminalKind(terminalName: "Terminal", bundleID: "com.apple.Terminal") == .appleTerminal)
        #expect(service.detectTerminalKind(terminalName: "Terminal (系统自带)", bundleID: "com.apple.Terminal") == .appleTerminal)

        #expect(service.detectTerminalKind(terminalName: "Ghostty", bundleID: "com.mitchellh.ghostty") == .ghostty)
        #expect(service.detectTerminalKind(terminalName: "kitty", bundleID: "net.kovidgoyal.kitty") == .kitty)
        #expect(service.detectTerminalKind(terminalName: "WezTerm", bundleID: "com.github.wez.wezterm") == .wezterm)
        #expect(service.detectTerminalKind(terminalName: "Alacritty", bundleID: "org.alacritty") == .alacritty)
        #expect(service.detectTerminalKind(terminalName: "UnknownTerm", bundleID: "com.example.unknown") == .generic)
    }

    @MainActor
    @Test("AppModel resolves tab titles for worktrees and projects according to description rules")
    func terminalTabTitleResolution() {
        let appModel = AppModel()

        // 1. Worktree 有自定义描述
        let wtWithDesc = WorktreeItem(
            id: "/path/wt-1",
            project: "核心支付服务",
            projectName: "pay-service",
            projectPath: "/repos/pay-service",
            branch: "feature/pay-v2",
            summary: "支持微信分账业务",
            updatedAt: "刚刚",
            kind: .worktree,
            path: "/path/wt-1",
            upstream: "origin/feature/pay-v2",
            head: "abc1234",
            createdDetail: "",
            diskUsage: "10M",
            canRemoveRemoteBranch: true,
            commits: []
        )
        #expect(appModel.resolvedWorktreeTabTitle(wtWithDesc) == "支持微信分账业务")

        // 2. 主仓库（summary 为 "主仓库"）-> 使用项目名称
        let wtMain = WorktreeItem(
            id: "/repos/pay-service",
            project: "核心支付服务",
            projectName: "pay-service",
            projectPath: "/repos/pay-service",
            branch: "main",
            summary: "主仓库",
            updatedAt: "刚刚",
            kind: .mainRepo,
            path: "/repos/pay-service",
            upstream: "origin/main",
            head: "abc1234",
            createdDetail: "",
            diskUsage: "10M",
            canRemoveRemoteBranch: false,
            commits: []
        )
        #expect(appModel.resolvedWorktreeTabTitle(wtMain) == "pay-service")

        // 3. Worktree 未填写描述（summary 为 "未填写功能描述"）-> 使用项目名称
        let wtNoDesc = WorktreeItem(
            id: "/path/wt-2",
            project: "核心支付服务",
            projectName: "pay-service",
            projectPath: "/repos/pay-service",
            branch: "fix/refund-bug",
            summary: "未填写功能描述",
            updatedAt: "刚刚",
            kind: .worktree,
            path: "/path/wt-2",
            upstream: "origin/fix/refund-bug",
            head: "abc1234",
            createdDetail: "",
            diskUsage: "10M",
            canRemoveRemoteBranch: true,
            commits: []
        )
        #expect(appModel.resolvedWorktreeTabTitle(wtNoDesc) == "pay-service")

        // 4. MergeProject -> 使用显示名称或名称
        let project = MergeProject(
            id: "proj-1",
            name: "order-center",
            displayName: "订单中心服务",
            path: "/repos/order-center",
            sourceRoot: "/repos",
            currentBranch: "master",
            gitLabProjectID: nil,
            branchMappings: [],
            remoteBranches: [],
            localBranches: []
        )
        #expect(appModel.resolvedProjectTabTitle(project) == "订单中心服务")

        // 5. 超长描述与多行描述自动截断与换行清理
        let wtLongDesc = WorktreeItem(
            id: "/path/wt-3",
            project: "核心支付服务",
            projectName: "pay-service",
            projectPath: "/repos/pay-service",
            branch: "feature/super-long",
            summary: "这是一个非常非常非常非常非常非常非常非常非常长的需求描述内容用于测试截断逻辑\n并且带换行符",
            updatedAt: "刚刚",
            kind: .worktree,
            path: "/path/wt-3",
            upstream: "origin/main",
            head: "abc1234",
            createdDetail: "",
            diskUsage: "10M",
            canRemoveRemoteBranch: true,
            commits: []
        )
        let resolved = appModel.resolvedWorktreeTabTitle(wtLongDesc)
        #expect(!resolved.contains("\n"))
        #expect(resolved.hasSuffix("..."))
        #expect(resolved.count <= 45)
    }
}
