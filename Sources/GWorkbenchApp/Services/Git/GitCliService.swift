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

final class GitCliService: Sendable {
    init() {}

    func scanLocalProjects(rootDirs: [String]) throws -> [LocalProject] {
        guard !rootDirs.isEmpty else {
            throw WorkbenchError.message("至少需要一个项目根目录")
        }

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
        let immutableCandidates = candidates

        DispatchQueue.concurrentPerform(iterations: immutableCandidates.count) { i in
            let c = immutableCandidates[i]
            let currentBranch = (try? self.currentLocalBranch(projectPath: c.path)) ?? "detached"
            let baseBranches = (try? self.remoteBranches(projectPath: c.path)) ?? []
            let localBranches = (try? self.localBranches(projectPath: c.path)) ?? []
            let remoteURL = self.remoteOriginURL(projectPath: c.path)
            let platform = RepositoryPlatform.detect(remoteURL: remoteURL)

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

        let projects = collector.all
        let nameCounts = Dictionary(grouping: projects, by: \.name).mapValues(\.count)
        return projects
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
    }

    func remoteOriginURL(projectPath: String) -> String? {
        let result = try? ProcessRunner.runGit(
            arguments: ["-C", projectPath, "config", "--get", "remote.origin.url"],
            allowFailure: true
        )
        guard let output = result?.stdout.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty else {
            return nil
        }
        return output
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

    /// 并行检测分支是否已经合入每个指定基线分支（不存在的基线会被跳过）
    func checkBranchMergedTargets(
        projectPath: String,
        branch: String,
        targets: [String],
        existingBranches: Set<String>
    ) -> [String: Bool] {
        var result: [String: Bool] = [:]
        guard !branch.isEmpty && branch != "HEAD" && branch != "(detached)" else {
            for target in targets { result[target] = false }
            return result
        }

        for target in targets {
            guard target != branch, existingBranches.contains(target) else {
                result[target] = false
                continue
            }
            let check = try? ProcessRunner.runGit(
                arguments: ["-C", projectPath, "merge-base", "--is-ancestor", branch, target],
                allowFailure: true
            )
            result[target] = (check?.status == 0)
        }
        return result
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

    func hasActiveMergeHead(projectPath: String) throws -> Bool {
        let gitDirRaw = try ProcessRunner.runGit(arguments: ["-C", projectPath, "rev-parse", "--git-dir"]).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let gitDirURL: URL
        if gitDirRaw.hasPrefix("/") {
            gitDirURL = URL(fileURLWithPath: gitDirRaw)
        } else {
            gitDirURL = URL(fileURLWithPath: projectPath).appendingPathComponent(gitDirRaw)
        }
        return FileManager.default.fileExists(atPath: gitDirURL.appendingPathComponent("MERGE_HEAD").path)
    }

    func conflictFiles(projectPath: String) throws -> [String] {
        let result = try ProcessRunner.runGit(
            arguments: ["-C", projectPath, "diff", "--name-only", "--diff-filter=U"],
            allowFailure: true
        )
        return result.stdout
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func fetch(projectPath: String, remote: String = "origin") throws {
        _ = try ProcessRunner.runGit(arguments: ["-C", projectPath, "fetch", remote])
    }

    func pull(projectPath: String, remote: String = "origin", branch: String) throws {
        _ = try ProcessRunner.runGit(arguments: ["-C", projectPath, "pull", remote, branch])
    }

    func push(projectPath: String, remote: String = "origin", branch: String, setUpstream: Bool = false) throws {
        var args = ["-C", projectPath, "push"]
        if setUpstream {
            args.append("-u")
        }
        args.append(contentsOf: [remote, branch])
        _ = try ProcessRunner.runGit(arguments: args)
    }

    func deleteLocalBranch(projectPath: String, branch: String) throws {
        _ = try ProcessRunner.runGit(arguments: ["-C", projectPath, "branch", "-D", branch])
    }

    func deleteRemoteBranch(projectPath: String, remote: String = "origin", branch: String) throws {
        _ = try ProcessRunner.runGit(arguments: ["-C", projectPath, "push", remote, "--delete", branch])
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
        _ = try ProcessRunner.runGit(arguments: ["-C", worktreePath, "fetch"])
    }

    func pullWorktree(worktreePath: String) throws {
        _ = try ProcessRunner.runGit(arguments: ["-C", worktreePath, "pull"])
    }

    func pushWorktree(worktreePath: String) throws {
        let upstream = try? currentUpstream(worktreePath: worktreePath)
        if upstream == nil || upstream == "未配置" {
            let branch = try currentLocalBranch(projectPath: worktreePath)
            if branch != "detached" && branch != "未提交" {
                _ = try ProcessRunner.runGit(arguments: ["-C", worktreePath, "push", "-u", "origin", branch])
                return
            }
        }
        _ = try ProcessRunner.runGit(arguments: ["-C", worktreePath, "push"])
    }
}
