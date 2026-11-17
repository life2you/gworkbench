import Foundation

struct ParsedWorktreeEntry: Sendable {
    var path: String
    var head: String
    var branch: String?
}

struct CommitInfo: Sendable {
    let headLine: String
    let updatedAt: String
    let commits: [CommitEntry]
}

enum GitMergeExecutionResult: Sendable {
    case success
    case alreadyUpToDate
    case conflict([String])
}

enum GitMergeStateInspection: Sendable, Equatable {
    /// MERGE_HEAD 仍在，但仍有未标记解决的冲突文件；markerFreeFiles 为其中已无冲突标记的文件
    case mergingWithUnresolvedFiles(conflictFiles: [String], markerFreeFiles: [String])
    /// MERGE_HEAD 仍在，且所有冲突已解决并暂存，可直接执行 git commit --no-edit
    case mergingReadyToCommit
    /// MERGE_HEAD 已消失，且合并源提交已合入 HEAD（外部已完成 merge commit）
    case committedExternally
    /// MERGE_HEAD 已消失，且合并源提交未合入 HEAD（外部中止了 merge）
    case abortedExternally
}

enum GitFileStatus: String, Sendable, CaseIterable {
    case unmodified = " "
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case unmerged = "U"
    case untracked = "?"
    case ignored = "!"
    case unknown = "X"

    init(code: Character) {
        self = GitFileStatus(rawValue: String(code)) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .unmodified: return "未修改"
        case .modified: return "修改"
        case .added: return "新增"
        case .deleted: return "删除"
        case .renamed: return "重命名"
        case .copied: return "复制"
        case .unmerged: return "冲突"
        case .untracked: return "未跟踪"
        case .ignored: return "已忽略"
        case .unknown: return "未知"
        }
    }
}

struct WorktreeFileChange: Identifiable, Hashable, Sendable {
    var id: String { path }
    let path: String
    let stagingStatus: GitFileStatus
    let worktreeStatus: GitFileStatus
    let rawCode: String

    var statusSummary: String {
        if rawCode == "??" {
            return "未跟踪"
        }
        if rawCode == "UU" || stagingStatus == .unmerged || worktreeStatus == .unmerged {
            return "冲突"
        }
        var parts: [String] = []
        if stagingStatus != .unmodified && stagingStatus != .unknown {
            parts.append("\(stagingStatus.displayName)(暂存)")
        }
        if worktreeStatus != .unmodified && worktreeStatus != .unknown {
            parts.append(worktreeStatus.displayName)
        }
        return parts.isEmpty ? "改动" : parts.joined(separator: " · ")
    }

    var primaryBadgeCode: String {
        if rawCode == "??" { return "??" }
        if rawCode == "UU" || stagingStatus == .unmerged || worktreeStatus == .unmerged { return "UU" }
        if stagingStatus != .unmodified && stagingStatus != .unknown {
            return stagingStatus.rawValue
        }
        if worktreeStatus != .unmodified && worktreeStatus != .unknown {
            return worktreeStatus.rawValue
        }
        return rawCode.trimmingCharacters(in: .whitespaces)
    }
}

struct AheadBehindCount: Equatable, Sendable {
    let ahead: Int
    let behind: Int
}

/// 仓库平台判定缓存：避免偶发探测失败导致仓库被错误归类为「本地」
final class PlatformCache: @unchecked Sendable {
    static let shared = PlatformCache()

    private struct Entry {
        let url: String?
        let platform: RepositoryPlatform
    }

    private var entries: [String: Entry] = [:]
    private let lock = NSLock()

    func set(_ url: String?, for path: String) {
        let platform = RepositoryPlatform.detect(remoteURL: url)
        lock.lock()
        defer { lock.unlock() }
        entries[path] = Entry(url: url, platform: platform)
    }

    func set(platform: RepositoryPlatform, url: String?, for path: String) {
        lock.lock()
        defer { lock.unlock() }
        entries[path] = Entry(url: url, platform: platform)
    }

    func platform(for path: String) -> RepositoryPlatform? {
        lock.lock()
        defer { lock.unlock() }
        return entries[path]?.platform
    }

    func url(for path: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return entries[path]?.url
    }
}

/// 本地项目扫描结果的短期缓存（纯 TTL，无阻塞、无单飞）
///
/// 设计取舍：
/// 早期版本在这里使用了 NSCondition 实现「单飞 + 等待」，但调用方位于
/// `Task.detached` 中，阻塞等待会占满 Swift 并发线程池，进而饿死其它任务，
/// 表现为应用卡死、数据刷不出来、甚至无法退出。
///
/// 现在改为完全无阻塞的纯缓存：
/// - 命中有效缓存 → 直接返回
/// - 未命中 → 由调用方各自扫描；扫描完成后写入缓存
/// 配合下面「全局扫描闸门」限制同时进行的真实扫描数量，避免进程风暴。
final class ProjectScanCache: @unchecked Sendable {
    static let shared = ProjectScanCache()

    private struct Cached {
        let roots: [String]
        let forcedPlatform: RepositoryPlatform?
        let projects: [LocalProject]
        let timestamp: Date
    }

    private let lock = NSLock()
    private var cached: Cached?
    private let ttl: TimeInterval = 2.0

    func cachedProjects(rootDirs: [String], forcedPlatform: RepositoryPlatform? = nil) -> [LocalProject]? {
        lock.lock()
        defer { lock.unlock() }
        guard let cached else { return nil }
        guard cached.roots == rootDirs, cached.forcedPlatform == forcedPlatform else { return nil }
        guard Date().timeIntervalSince(cached.timestamp) <= ttl else { return nil }
        return cached.projects
    }

    func store(_ projects: [LocalProject], rootDirs: [String], forcedPlatform: RepositoryPlatform? = nil) {
        lock.lock()
        defer { lock.unlock() }
        cached = Cached(roots: rootDirs, forcedPlatform: forcedPlatform, projects: projects, timestamp: Date())
    }

    func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        cached = nil
    }
}

/// 全局 GitLab 主机提示（配置加载后写入），用于远端探测失败时的平台兜底判定
final class GitLabHostStore: @unchecked Sendable {
    static let shared = GitLabHostStore()
    private var host: String?
    private let lock = NSLock()

    func update(_ value: String?) {
        lock.lock()
        defer { lock.unlock() }
        host = value?.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
    }

    var current: String? {
        lock.lock()
        defer { lock.unlock() }
        return host
    }
}

/// 全局 Git HTTPS Token 凭据缓存（供 fetch/pull/push 在 HTTPS 仓库下自动认证，不污染 .git/config）
final class GitCredentialStore: @unchecked Sendable {
    static let shared = GitCredentialStore()
    private var gitlabToken: String = ""
    private var githubToken: String = ""
    private let lock = NSLock()

    func update(gitlabToken: String, githubToken: String) {
        lock.lock()
        defer { lock.unlock() }
        self.gitlabToken = gitlabToken.trimmingCharacters(in: .whitespacesAndNewlines)
        self.githubToken = githubToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func tokens() -> (gitlab: String, github: String) {
        lock.lock()
        defer { lock.unlock() }
        return (gitlabToken, githubToken)
    }
}

final class GitCliService: Sendable {
    init() {}

    /// 零子进程纯文件系统快扫：在切换工作区标签的 0~3ms 内立即拿到所有仓库列表与当前分支名
    func scanProjectPlaceholders(rootDirs: [String], forcedPlatform: RepositoryPlatform? = nil) -> [LocalProject] {
        guard !rootDirs.isEmpty else { return [] }
        if let cached = ProjectScanCache.shared.cachedProjects(rootDirs: rootDirs, forcedPlatform: forcedPlatform) {
            return cached
        }

        var seen = Set<String>()
        var raw: [(name: String, path: String, sourceRoot: String, branch: String, platform: RepositoryPlatform)] = []

        for rootDir in rootDirs {
            let expandedRoot = ProcessRunner.expandPath(rootDir)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: expandedRoot, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            guard let children = try? FileManager.default.contentsOfDirectory(atPath: expandedRoot) else {
                continue
            }
            for child in children {
                let candidate = URL(fileURLWithPath: expandedRoot).appendingPathComponent(child).path
                var isCandidateDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: candidate, isDirectory: &isCandidateDirectory), isCandidateDirectory.boolValue else {
                    continue
                }
                var isGitDirectory: ObjCBool = false
                let gitPath = URL(fileURLWithPath: candidate).appendingPathComponent(".git").path
                guard FileManager.default.fileExists(atPath: gitPath, isDirectory: &isGitDirectory), isGitDirectory.boolValue else {
                    continue
                }
                let normalized = ProcessRunner.normalizePath(candidate)
                guard seen.insert(normalized).inserted else { continue }

                let branch = Self.readBranchFromHEAD(projectPath: normalized) ?? "HEAD"
                let remoteURL = Self.readOriginURLFromGitConfig(projectPath: normalized)
                let platform = forcedPlatform ?? RepositoryPlatform.detect(remoteURL: remoteURL)
                raw.append((
                    name: URL(fileURLWithPath: normalized).lastPathComponent,
                    path: normalized,
                    sourceRoot: ProcessRunner.normalizePath(expandedRoot),
                    branch: branch,
                    platform: platform
                ))
            }
        }

        let nameCounts = Dictionary(grouping: raw, by: \.name).mapValues(\.count)
        return raw
            .sorted { $0.name != $1.name ? $0.name < $1.name : $0.path < $1.path }
            .map { item in
                let displayName = nameCounts[item.name, default: 0] > 1
                    ? "\(item.name) (\(URL(fileURLWithPath: item.sourceRoot).lastPathComponent))"
                    : item.name
                return LocalProject(
                    id: item.path,
                    name: item.name,
                    displayName: displayName,
                    path: item.path,
                    sourceRoot: item.sourceRoot,
                    currentBranch: item.branch,
                    baseBranches: [],
                    localBranches: [item.branch],
                    remoteURL: nil,
                    platform: item.platform
                )
            }
    }

    private static func readBranchFromHEAD(projectPath: String) -> String? {
        let headPath = URL(fileURLWithPath: projectPath).appendingPathComponent(".git/HEAD").path
        guard let content = try? String(contentsOfFile: headPath, encoding: .utf8) else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("ref: refs/heads/") {
            return String(trimmed.dropFirst("ref: refs/heads/".count))
        }
        if trimmed.count >= 7 {
            return String(trimmed.prefix(7))
        }
        return nil
    }

    func scanLocalProjects(rootDirs: [String], forcedPlatform: RepositoryPlatform? = nil) throws -> [LocalProject] {
        guard !rootDirs.isEmpty else {
            throw WorkbenchError.message("至少需要一个项目根目录")
        }

        // 短期缓存：三个调用方在极短时间内请求同一批根目录时直接复用结果
        if let cached = ProjectScanCache.shared.cachedProjects(rootDirs: rootDirs, forcedPlatform: forcedPlatform) {
            return cached
        }

        // 直接扫描。不使用任何跨线程闸门/等待：
        // 之前的 NSCondition 单飞会阻塞 Swift 并发线程池导致应用卡死；
        // 而单一许可的闸门会让并发的三个模块互相饿死。
        // 扫描本身已是并发 + 轻量（git 调用），少量重复扫描的代价远小于卡死风险。

        var seen = Set<String>()
        var candidates: [(name: String, path: String, sourceRoot: String)] = []

        for rootDir in rootDirs {
            let expandedRoot = ProcessRunner.expandPath(rootDir)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: expandedRoot, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw WorkbenchError.message("项目根目录不存在: \(expandedRoot)")
            }

            let children = try FileManager.default.contentsOfDirectory(atPath: expandedRoot)
            for child in children {
                let candidate = URL(fileURLWithPath: expandedRoot).appendingPathComponent(child).path
                var isCandidateDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: candidate, isDirectory: &isCandidateDirectory), isCandidateDirectory.boolValue else {
                    continue
                }
                var isGitDirectory: ObjCBool = false
                let gitPath = URL(fileURLWithPath: candidate).appendingPathComponent(".git").path
                guard FileManager.default.fileExists(atPath: gitPath, isDirectory: &isGitDirectory), isGitDirectory.boolValue else {
                    // 如果 .git 不存在，或者它只是一个普通文件（例如关联工作树的 .git 文件），绝不作为独立项目展示
                    continue
                }

                let normalized = ProcessRunner.normalizePath(candidate)
                guard seen.insert(normalized).inserted else {
                    continue
                }

                candidates.append((
                    name: URL(fileURLWithPath: normalized).lastPathComponent,
                    path: normalized,
                    sourceRoot: ProcessRunner.normalizePath(expandedRoot)
                ))
            }
        }

        typealias ProjectRaw = (name: String, path: String, sourceRoot: String, currentBranch: String, baseBranches: [String], localBranches: [String], remoteURL: String?, platform: RepositoryPlatform)
        
        final class ProjectCollector: @unchecked Sendable {
            private var items: [ProjectRaw] = []
            private let lock = NSLock()
            func append(_ item: ProjectRaw) {
                lock.lock()
                defer { lock.unlock() }
                items.append(item)
            }
            var all: [ProjectRaw] {
                lock.lock()
                defer { lock.unlock() }
                return items
            }
        }

        let collector = ProjectCollector()
        let scanTargets = candidates

        // 使用 concurrentPerform：由系统线程池自行限流（上限约为 CPU 核数）。
        // 不使用「并发队列 + 信号量 + queue.sync(barrier)」组合：
        // 那种写法会让阻塞的线程占满线程池，导致 barrier 永远等不到执行，整个扫描永久挂起。
        DispatchQueue.concurrentPerform(iterations: scanTargets.count) { index in
            let c = scanTargets[index]
            if true {
                let currentBranch = (try? self.currentLocalBranch(projectPath: c.path)) ?? "detached"
                let baseBranches = (try? self.remoteBranches(projectPath: c.path)) ?? []
                let localBranches = (try? self.localBranches(projectPath: c.path)) ?? []

                // 平台判定：优先缓存，其次真实探测，失败时用远端跟踪分支兜底
                let probe = self.probeRemoteOriginURL(projectPath: c.path)
                let remoteURL: String?
                let platform: RepositoryPlatform

                switch probe {
                case .url(let value):
                    remoteURL = value
                    platform = forcedPlatform ?? RepositoryPlatform.detect(remoteURL: value)
                    PlatformCache.shared.set(platform: platform, url: value, for: c.path)
                case .noRemoteConfigured:
                    remoteURL = nil
                    platform = forcedPlatform ?? .local
                    PlatformCache.shared.set(platform: platform, url: nil, for: c.path)
                case .probeFailed:
                    // 探测失败：绝不因为偶发进程失败就把仓库降级为「本地」
                    // 优先级：工作区显式平台 → 历史缓存 → 直接解析 .git/config → 远端跟踪分支兜底
                    if let forcedPlatform {
                        remoteURL = Self.readOriginURLFromGitConfig(projectPath: c.path)
                        platform = forcedPlatform
                    } else if let cached = PlatformCache.shared.platform(for: c.path) {
                        remoteURL = PlatformCache.shared.url(for: c.path)
                        platform = cached
                    } else if let urlFromFile = Self.readOriginURLFromGitConfig(projectPath: c.path) {
                        remoteURL = urlFromFile
                        platform = RepositoryPlatform.detect(remoteURL: urlFromFile)
                        PlatformCache.shared.set(urlFromFile, for: c.path)
                    } else if let fallback = RepositoryPlatform.fallbackPlatform(
                        existingBranchRefs: baseBranches.map { "origin/\($0)" },
                        gitlabHost: GitLabHostStore.shared.current
                    ) {
                        remoteURL = nil
                        platform = fallback
                        PlatformCache.shared.set(platform: fallback, url: nil, for: c.path)
                    } else {
                        remoteURL = nil
                        platform = .local
                    }
                }

                collector.append((
                    name: c.name,
                    path: c.path,
                    sourceRoot: c.sourceRoot,
                    currentBranch: currentBranch,
                    baseBranches: baseBranches,
                    localBranches: localBranches,
                    remoteURL: remoteURL,
                    platform: platform
                ))
            }
        }

        let projects = collector.all
        let nameCounts = Dictionary(grouping: projects, by: \.name).mapValues(\.count)
        let result = projects
            .sorted {
                if $0.name != $1.name {
                    return $0.name < $1.name
                }
                return $0.path < $1.path
            }
            .map { project in
                let displayName: String
                if nameCounts[project.name, default: 0] > 1 {
                    displayName = "\(project.name) (\(URL(fileURLWithPath: project.sourceRoot).lastPathComponent))"
                } else {
                    displayName = project.name
                }
                return LocalProject(
                    id: project.path,
                    name: project.name,
                    displayName: displayName,
                    path: project.path,
                    sourceRoot: project.sourceRoot,
                    currentBranch: project.currentBranch,
                    baseBranches: project.baseBranches,
                    localBranches: project.localBranches,
                    remoteURL: project.remoteURL,
                    platform: project.platform
                )
            }

        ProjectScanCache.shared.store(result, rootDirs: rootDirs, forcedPlatform: forcedPlatform)
        return result
    }

    /// 直接解析 .git/config 读取 remote.origin.url。
    /// 纯文件读取，不依赖子进程，因此不会出现并发 fork 失败导致的误判。
    static func readOriginURLFromGitConfig(projectPath: String) -> String? {
        let configPath = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".git")
            .appendingPathComponent("config")
            .path

        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return nil
        }

        var inOriginSection = false
        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                inOriginSection = line.replacingOccurrences(of: " ", with: "") == "[remote\"origin\"]"
                continue
            }
            guard inOriginSection else { continue }
            if line.hasPrefix("url") {
                guard let eqIndex = line.firstIndex(of: "=") else { continue }
                let value = line[line.index(after: eqIndex)...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }

    func remoteOriginURL(projectPath: String) -> String? {
        switch probeRemoteOriginURL(projectPath: projectPath) {
        case .url(let value):
            return value
        case .noRemoteConfigured, .probeFailed:
            return nil
        }
    }

    /// 精确探测 remote.origin.url，并区分三种结果：
    /// - `.url`            读取成功
    /// - `.noRemoteConfigured` git 正常退出（exit=1），确实未配置 origin
    /// - `.probeFailed`    进程启动失败 / 超时 / 输出异常，属于可重试的偶发错误
    func probeRemoteOriginURL(projectPath: String) -> RepositoryPlatform.RemoteURLProbe {
        let maxAttempts = 3

        for attempt in 1...maxAttempts {
            guard let result = try? ProcessRunner.runGit(
                arguments: ["-C", projectPath, "config", "--get", "remote.origin.url"],
                allowFailure: true
            ) else {
                // 进程未能启动（资源瞬时不足等）：短暂让出后重试
                if attempt < maxAttempts {
                    Thread.sleep(forTimeInterval: 0.05 * Double(attempt))
                    continue
                }
                return .probeFailed
            }

            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

            if result.status == 0 {
                if !output.isEmpty {
                    return .url(output)
                }
                // exit=0 但输出为空：异常情况，重试
                if attempt < maxAttempts {
                    Thread.sleep(forTimeInterval: 0.05 * Double(attempt))
                    continue
                }
                return .probeFailed
            }

            if result.status == 1 {
                // git config 在 key 不存在时返回 1，这是明确的「未配置」
                return .noRemoteConfigured
            }

            // 其它退出码：视为偶发失败并重试
            if attempt < maxAttempts {
                Thread.sleep(forTimeInterval: 0.05 * Double(attempt))
                continue
            }
            return .probeFailed
        }

        return .probeFailed
    }

    func currentLocalBranch(projectPath: String) throws -> String {
        let result = try ProcessRunner.runGit(
            arguments: ["-C", projectPath, "symbolic-ref", "--quiet", "--short", "HEAD"],
            allowFailure: true
        )

        if result.status == 0 {
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty ?? "detached"
        }

        let emptyRepoCheck = try ProcessRunner.runGit(
            arguments: ["-C", projectPath, "rev-parse", "--verify", "HEAD"],
            allowFailure: true
        )
        if emptyRepoCheck.status != 0 {
            return "未提交"
        }

        return "detached"
    }

    func remoteBranches(projectPath: String) throws -> [String] {
        let output = try ProcessRunner.runGit(
            arguments: [
                "-C",
                projectPath,
                "for-each-ref",
                "--format=%(refname:short)",
                "--sort=-committerdate",
                "refs/remotes/origin"
            ]
        ).stdout

        let branches = output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: "origin/", with: "") }
            .filter { !$0.isEmpty && $0 != "HEAD" }

        return Array(NSOrderedSet(array: branches)) as? [String] ?? branches
    }

    func localBranches(projectPath: String) throws -> [String] {
        let output = try ProcessRunner.runGit(
            arguments: [
                "-C",
                projectPath,
                "for-each-ref",
                "--format=%(refname:short)",
                "--sort=-committerdate",
                "refs/heads"
            ]
        ).stdout
        let branches = output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(NSOrderedSet(array: branches)) as? [String] ?? branches
    }

    func localBranchExists(projectPath: String, branch: String) throws -> Bool {
        let result = try ProcessRunner.runGit(
            arguments: ["-C", projectPath, "show-ref", "--verify", "--quiet", "refs/heads/\(branch)"],
            allowFailure: true
        )
        return result.status == 0
    }

    func remoteBranchExists(projectPath: String, branch: String) throws -> Bool {
        let result = try ProcessRunner.runGit(
            arguments: ["-C", projectPath, "show-ref", "--verify", "--quiet", "refs/remotes/origin/\(branch)"],
            allowFailure: true
        )
        return result.status == 0
    }

    func checkBranchMerged(projectPath: String, branch: String, candidateBases: [String]) -> (isMerged: Bool, mergedTarget: String?) {
        guard !branch.isEmpty && branch != "HEAD" && branch != "(detached)" else {
            return (false, nil)
        }
        for base in candidateBases where base != branch {
            let result = try? ProcessRunner.runGit(
                arguments: ["-C", projectPath, "merge-base", "--is-ancestor", branch, base],
                allowFailure: true
            )
            if result?.status == 0 {
                return (true, base)
            }
        }
        return (false, nil)
    }

    /// 并行检测分支是否已经合入每个指定基线分支（支持多候选分支，如权威基线及环境合并分支）
    /// - targetCandidates: 每个目标对应按优先级排列的候选分支列表，如 "stage" -> ["origin/stage", "stage", "origin/stage_sync", "stage_sync"]
    /// - 返回: (mergedStatus: [基线名: 是否合入], matchedBranches: [基线名: 命中的分支名])
    func checkBranchMergedTargetsWithDetails(
        projectPath: String,
        branch: String,
        targets: [String],
        candidateBasesByTarget: [String: [String]] = [:],
        existingBranches: Set<String>
    ) -> (mergedStatus: [String: Bool], matchedBranches: [String: String]) {
        var mergedResult: [String: Bool] = [:]
        var matchedResult: [String: String] = [:]

        guard !branch.isEmpty && branch != "HEAD" && branch != "(detached)" else {
            for target in targets {
                mergedResult[target] = false
            }
            return (mergedResult, matchedResult)
        }

        for target in targets {
            guard target != branch else {
                mergedResult[target] = false
                continue
            }

            // 获取该 target 的候选基线列表（按优先级：远端权威 -> 本地权威 -> 远端集成分支 -> 本地集成分支）
            var candidateBases: [String] = []
            if let customCandidates = candidateBasesByTarget[target], !customCandidates.isEmpty {
                candidateBases = customCandidates
            } else {
                candidateBases = ["origin/\(target)", target]
            }

            var isMerged = false
            var matchedBranch: String? = nil

            for candidate in candidateBases {
                guard candidate != branch else { continue }
                guard existingBranches.contains(candidate) else { continue }

                let check = try? ProcessRunner.runGit(
                    arguments: ["-C", projectPath, "merge-base", "--is-ancestor", branch, candidate],
                    allowFailure: true
                )
                if check?.status == 0 {
                    isMerged = true
                    matchedBranch = candidate
                    break
                }
            }

            mergedResult[target] = isMerged
            if let matched = matchedBranch {
                matchedResult[target] = matched
            }
        }

        return (mergedResult, matchedResult)
    }

    /// 并行检测分支是否已经合入每个指定基线分支（优先比对远端 origin/* 基线）
    /// - 返回: [基线名: 是否已合入]
    /// - 解析顺序: origin/<base> → <base>（本地），优先使用远端权威分支，避免本地基线落后导致误判
    func checkBranchMergedTargets(
        projectPath: String,
        branch: String,
        targets: [String],
        candidateBasesByTarget: [String: [String]] = [:],
        existingBranches: Set<String>
    ) -> [String: Bool] {
        checkBranchMergedTargetsWithDetails(
            projectPath: projectPath,
            branch: branch,
            targets: targets,
            candidateBasesByTarget: candidateBasesByTarget,
            existingBranches: existingBranches
        ).mergedStatus
    }

    func pruneWorktrees(projectPath: String) {
        _ = try? ProcessRunner.runGit(
            arguments: ["-C", projectPath, "worktree", "prune"],
            allowFailure: true
        )
    }

    func parseWorktreeList(projectPath: String) throws -> [ParsedWorktreeEntry] {
        let output = try ProcessRunner.runGit(
            arguments: ["-C", projectPath, "worktree", "list", "--porcelain"]
        ).stdout

        var entries: [ParsedWorktreeEntry] = []
        var current: ParsedWorktreeEntry?

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let current {
                    entries.append(current)
                }
                current = nil
                continue
            }

            if line.hasPrefix("worktree ") {
                if let current {
                    entries.append(current)
                }
                let path = String(line.dropFirst("worktree ".count))
                current = ParsedWorktreeEntry(path: path.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), head: "", branch: nil)
                continue
            }

            guard var currentEntry = current else {
                continue
            }

            if line.hasPrefix("HEAD ") {
                let head = String(line.dropFirst("HEAD ".count))
                currentEntry.head = head.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            } else if line.hasPrefix("branch ") {
                let branch = String(line.dropFirst("branch ".count))
                currentEntry.branch = branch
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    .replacingOccurrences(of: "refs/heads/", with: "")
            }
            current = currentEntry
        }

        if let current {
            entries.append(current)
        }

        return entries
    }

    func loadCommitInfo(worktreePath: String) throws -> CommitInfo {
        let result = try ProcessRunner.runGit(
            arguments: [
                "-C",
                worktreePath,
                "log",
                "-5",
                "--pretty=format:%h%x1f%s%x1f%an%x1f%ct"
            ],
            allowFailure: true
        )

        if result.status != 0 {
            let errorText = [result.stderr, result.stdout]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if errorText.contains("does not have any commits yet")
                || errorText.contains("your current branch")
                || errorText.contains("fatal: bad revision")
            {
                return CommitInfo(
                    headLine: "尚无提交记录",
                    updatedAt: "未提交",
                    commits: []
                )
            }

            throw WorkbenchError.message(errorText.isEmpty ? "读取提交记录失败" : errorText)
        }

        let output = result.stdout

        let commits = output
            .split(separator: "\n")
            .map { line -> CommitEntry? in
                let parts = line.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
                guard parts.count == 4 else { return nil }
                let relative = DateFormatterUtils.relativeDateString(fromUnixTimestamp: parts[3])
                return CommitEntry(sha: parts[0], message: parts[1], author: parts[2], relativeTime: relative)
            }
            .compactMap { $0 }

        if let first = commits.first {
            return CommitInfo(
                headLine: "\(first.sha) · \(first.message)",
                updatedAt: first.relativeTime,
                commits: commits
            )
        }

        return CommitInfo(headLine: "无提交记录", updatedAt: "未知", commits: [])
    }

    func currentUpstream(worktreePath: String) throws -> String {
        let result = try ProcessRunner.runGit(
            arguments: ["-C", worktreePath, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
            allowFailure: true
        )
        if result.status == 0 {
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "未配置"
    }

    func diskUsage(path: String) throws -> String {
        try ProcessRunner.runCommand("du", arguments: ["-sh", path]).stdout
            .split(separator: "\t")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知"
    }

    func worktreeDirtyStatus(worktreePath: String) throws -> (isDirty: Bool, summary: String) {
        let result = try ProcessRunner.runGit(
            arguments: ["-C", worktreePath, "status", "--porcelain"],
            allowFailure: true
        )
        guard result.status == 0 else {
            return (isDirty: false, summary: "未知")
        }
        let lines = result.stdout
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if lines.isEmpty {
            return (isDirty: false, summary: "干净")
        }
        return (isDirty: true, summary: "\(lines.count) 处改动")
    }

    func gitVersion() throws -> String {
        let result = try ProcessRunner.runGit(
            arguments: ["--version"],
            allowFailure: true
        )
        if result.status == 0 {
            let raw = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.hasPrefix("git version ") {
                let ver = raw.dropFirst("git version ".count).split(separator: " ").first.map(String.init) ?? raw
                return "Git \(ver)"
            }
            return raw
        }
        return "Git"
    }

    func checkoutBranch(projectPath: String, branch: String) throws {
        _ = try ProcessRunner.runGit(arguments: ["-C", projectPath, "checkout", branch])
    }

    func checkoutNewBranch(projectPath: String, branch: String, from: String) throws {
        _ = try ProcessRunner.runGit(arguments: ["-C", projectPath, "checkout", "-b", branch, from])
    }

    func mergeBranch(projectPath: String, sourceBranch: String) throws -> GitMergeExecutionResult {
        let result = try ProcessRunner.runGit(
            arguments: ["-C", projectPath, "merge", sourceBranch, "--no-edit"],
            allowFailure: true
        )

        if result.status == 0 {
            let output = [result.stdout, result.stderr].joined(separator: "\n")
            if output.contains("Already up to date") {
                return .alreadyUpToDate
            }
            return .success
        }

        if try hasActiveMergeHead(projectPath: projectPath) {
            let files = try conflictFiles(projectPath: projectPath)
            _ = try? ProcessRunner.runGit(arguments: ["-C", projectPath, "merge", "--abort"], allowFailure: true)
            return .conflict(files)
        }

        let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
            ?? result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
            ?? "合并失败: \(sourceBranch)"
        throw WorkbenchError.message(detail)
    }

    /// 交互式合并分支：发生冲突时不自动执行 abort，完整保留 MERGE_HEAD 与冲突现场供工具解决
    func mergeBranchInteractive(projectPath: String, sourceBranch: String) throws -> GitMergeExecutionResult {
        let result = try ProcessRunner.runGit(
            arguments: ["-C", projectPath, "merge", sourceBranch, "--no-edit"],
            allowFailure: true
        )

        if result.status == 0 {
            let output = [result.stdout, result.stderr].joined(separator: "\n")
            if output.contains("Already up to date") {
                return .alreadyUpToDate
            }
            return .success
        }

        if try hasActiveMergeHead(projectPath: projectPath) {
            let files = try conflictFiles(projectPath: projectPath)
            return .conflict(files)
        }

        let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
            ?? result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
            ?? "合并失败: \(sourceBranch)"
        throw WorkbenchError.message(detail)
    }

    /// 中止当前正在进行的合并并恢复现场
    func abortMerge(projectPath: String) throws {
        _ = try ProcessRunner.runGit(
            arguments: ["-C", projectPath, "merge", "--abort"],
            allowFailure: true
        )
    }

    /// 提交当前解决完的合并
    func commitMerge(projectPath: String, message: String? = nil) throws {
        var args = ["-C", projectPath, "commit"]
        if let message, !message.isEmpty {
            args += ["-m", message]
        } else {
            args += ["--no-edit"]
        }
        _ = try ProcessRunner.runGit(
            arguments: args,
            allowFailure: false
        )
    }

    /// 显式暂存指定文件（不使用 -A，避免将外部工具生成的未追踪文件如 .idea 误纳入提交）
    func stageFiles(projectPath: String, files: [String]) throws {
        let targets = files.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !targets.isEmpty else { return }
        _ = try ProcessRunner.runGit(
            arguments: ["-C", projectPath, "add", "--"] + targets,
            allowFailure: false
        )
    }

    func activeMergeHeadSHA(projectPath: String) throws -> String? {
        let gitDirRaw = try ProcessRunner.runGit(arguments: ["-C", projectPath, "rev-parse", "--git-dir"]).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let gitDirURL: URL
        if gitDirRaw.hasPrefix("/") {
            gitDirURL = URL(fileURLWithPath: gitDirRaw)
        } else {
            gitDirURL = URL(fileURLWithPath: projectPath).appendingPathComponent(gitDirRaw)
        }
        let mergeHeadURL = gitDirURL.appendingPathComponent("MERGE_HEAD")
        guard FileManager.default.fileExists(atPath: mergeHeadURL.path) else {
            return nil
        }
        let sha = (try? String(contentsOf: mergeHeadURL, encoding: .utf8))?
            .split(whereSeparator: \.isNewline)
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        return sha?.isEmpty == false ? sha : "MERGE_HEAD"
    }

    func hasActiveMergeHead(projectPath: String) throws -> Bool {
        try activeMergeHeadSHA(projectPath: projectPath) != nil
    }

    func conflictFiles(projectPath: String) throws -> [String] {
        let result = try ProcessRunner.runGit(
            arguments: ["-c", "core.quotepath=false", "-C", projectPath, "diff", "--name-only", "--diff-filter=U"],
            allowFailure: true
        )
        return result.stdout
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func isCommitMergedIntoHead(projectPath: String, commitOrBranch: String) -> Bool {
        let trimmed = commitOrBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let result = try? ProcessRunner.runGit(
            arguments: ["-C", projectPath, "merge-base", "--is-ancestor", trimmed, "HEAD"],
            allowFailure: true
        )
        return result?.status == 0
    }

    func fileContainsConflictMarkers(projectPath: String, relativePath: String) -> Bool {
        let fileURL = URL(fileURLWithPath: projectPath).appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return false
        }
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return false
        }
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let normalized = line.hasSuffix("\r") ? String(line.dropLast()) : String(line)
            if normalized.hasPrefix("<<<<<<<") || normalized == "=======" || normalized.hasPrefix(">>>>>>>") {
                return true
            }
        }
        return false
    }

    /// 检查当前合并现场的精确状态，供 Rebased 外部解决冲突后的闭环自动化使用
    func inspectMergeState(projectPath: String, sourceRef: String) throws -> GitMergeStateInspection {
        if try hasActiveMergeHead(projectPath: projectPath) {
            let files = try conflictFiles(projectPath: projectPath)
            if files.isEmpty {
                return .mergingReadyToCommit
            }
            let markerFree = files.filter { file in
                let fileURL = URL(fileURLWithPath: projectPath).appendingPathComponent(file)
                return FileManager.default.fileExists(atPath: fileURL.path)
                    && !fileContainsConflictMarkers(projectPath: projectPath, relativePath: file)
            }
            return .mergingWithUnresolvedFiles(conflictFiles: files, markerFreeFiles: markerFree)
        }

        if isCommitMergedIntoHead(projectPath: projectPath, commitOrBranch: sourceRef) {
            return .committedExternally
        }
        return .abortedExternally
    }

    private func runNetworkGit(path: String, arguments: [String]) throws -> ShellResult {
        let remoteURL = PlatformCache.shared.url(for: path) ?? remoteOriginURL(projectPath: path)
        if let remoteURL,
           remoteURL.hasPrefix("http://") || remoteURL.hasPrefix("https://") {
            let platform = RepositoryPlatform.detect(remoteURL: remoteURL)
            let tokens = GitCredentialStore.shared.tokens()
            var username: String?
            var token: String = ""

            switch platform {
            case .github:
                token = GitHubProvider.resolveToken(configuredToken: tokens.github)
                username = "x-access-token"
            case .gitlab:
                token = tokens.gitlab
                username = "oauth2"
            case .local, .all:
                break
            }

            if let username, !token.isEmpty {
                let helper = "!f() { echo \"username=$GWORKBENCH_GIT_USER\"; echo \"password=$GWORKBENCH_GIT_TOKEN\"; }; f"
                let fullArgs = ["-c", "credential.helper=\(helper)"] + arguments
                let env = [
                    "GWORKBENCH_GIT_USER": username,
                    "GWORKBENCH_GIT_TOKEN": token,
                    "GIT_TERMINAL_PROMPT": "0"
                ]
                return try ProcessRunner.runGit(arguments: fullArgs, environment: env)
            }
        }
        return try ProcessRunner.runGit(arguments: arguments)
    }

    func fetch(projectPath: String, remote: String = "origin") throws {
        _ = try runNetworkGit(path: projectPath, arguments: ["-C", projectPath, "fetch", remote])
    }

    func pull(projectPath: String, remote: String = "origin", branch: String) throws {
        _ = try runNetworkGit(path: projectPath, arguments: ["-C", projectPath, "pull", remote, branch])
    }

    func push(projectPath: String, remote: String = "origin", branch: String, setUpstream: Bool = false) throws {
        var args = ["-C", projectPath, "push"]
        if setUpstream {
            args.append("-u")
        }
        args.append(contentsOf: [remote, branch])
        _ = try runNetworkGit(path: projectPath, arguments: args)
    }

    func deleteLocalBranch(projectPath: String, branch: String) throws {
        _ = try ProcessRunner.runGit(arguments: ["-C", projectPath, "branch", "-D", branch])
    }

    func deleteRemoteBranch(projectPath: String, remote: String = "origin", branch: String) throws {
        _ = try runNetworkGit(path: projectPath, arguments: ["-C", projectPath, "push", remote, "--delete", branch])
    }

    func addWorktree(projectPath: String, targetPath: String, branch: String, newBranchFrom: String? = nil) throws {
        if let base = newBranchFrom {
            _ = try ProcessRunner.runGit(arguments: ["-C", projectPath, "worktree", "add", "-b", branch, targetPath, base])
        } else {
            _ = try ProcessRunner.runGit(arguments: ["-C", projectPath, "worktree", "add", targetPath, branch])
        }
    }

    func removeWorktree(projectPath: String, targetPath: String, force: Bool = true) throws {
        var args = ["-C", projectPath, "worktree", "remove", targetPath]
        if force {
            args.append("--force")
        }
        _ = try ProcessRunner.runGit(arguments: args)
    }

    func worktreeDetailedChanges(worktreePath: String) throws -> [WorktreeFileChange] {
        let result = try ProcessRunner.runGit(
            arguments: ["-c", "core.quotepath=false", "-C", worktreePath, "status", "--porcelain", "-uall"],
            allowFailure: true
        )
        guard result.status == 0 else {
            let errorText = [result.stderr, result.stdout].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            throw WorkbenchError.message(errorText.isEmpty ? "获取文件改动状态失败" : errorText)
        }

        var changes: [WorktreeFileChange] = []
        let lines = result.stdout.split(separator: "\n", omittingEmptySubsequences: true)
        for rawLine in lines {
            let line = String(rawLine)
            guard line.count >= 3 else { continue }
            let xChar = line[line.startIndex]
            let yChar = line[line.index(line.startIndex, offsetBy: 1)]
            let rawCode = String([xChar, yChar])
            var filePath = String(line.dropFirst(3)).trimmingCharacters(in: .newlines)

            if filePath.hasPrefix("\"") && filePath.hasSuffix("\"") && filePath.count >= 2 {
                filePath = String(filePath.dropFirst().dropLast())
            }
            if filePath.contains(" -> ") {
                let parts = filePath.components(separatedBy: " -> ")
                if let dest = parts.last {
                    filePath = dest.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
                }
            }

            let staging = GitFileStatus(code: xChar)
            let worktree = GitFileStatus(code: yChar)
            changes.append(WorktreeFileChange(
                path: filePath,
                stagingStatus: staging,
                worktreeStatus: worktree,
                rawCode: rawCode
            ))
        }
        return changes
    }

    func aheadBehindCount(worktreePath: String) throws -> AheadBehindCount {
        let result = try ProcessRunner.runGit(
            arguments: ["-C", worktreePath, "rev-list", "--left-right", "--count", "HEAD...@{upstream}"],
            allowFailure: true
        )
        if result.status != 0 {
            return AheadBehindCount(ahead: 0, behind: 0)
        }
        let parts = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: \.isWhitespace)
        guard parts.count == 2,
              let ahead = Int(parts[0]),
              let behind = Int(parts[1]) else {
            return AheadBehindCount(ahead: 0, behind: 0)
        }
        return AheadBehindCount(ahead: ahead, behind: behind)
    }

    func fetchWorktree(worktreePath: String) throws {
        _ = try runNetworkGit(path: worktreePath, arguments: ["-C", worktreePath, "fetch"])
    }

    func pullWorktree(worktreePath: String) throws {
        _ = try runNetworkGit(path: worktreePath, arguments: ["-C", worktreePath, "pull"])
    }

    func pushWorktree(worktreePath: String) throws {
        let upstream = try? currentUpstream(worktreePath: worktreePath)
        if upstream == nil || upstream == "未配置" {
            let branch = try currentLocalBranch(projectPath: worktreePath)
            if branch != "detached" && branch != "未提交" {
                _ = try runNetworkGit(path: worktreePath, arguments: ["-C", worktreePath, "push", "-u", "origin", branch])
                return
            }
        }
        _ = try runNetworkGit(path: worktreePath, arguments: ["-C", worktreePath, "push"])
    }
}
