import Foundation

/// 工作树回收站分析器（nonisolated，可在后台并发执行）
enum WorktreeSweeperAnalyzer {
    static func parseDiskUsageToMB(_ usage: String) -> Double {
        let trimmed = usage.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasSuffix("G") || trimmed.hasSuffix("GB") {
            let numStr = trimmed.replacingOccurrences(of: "GB", with: "").replacingOccurrences(of: "G", with: "").trimmingCharacters(in: .whitespaces)
            return (Double(numStr) ?? 0) * 1024
        } else if trimmed.hasSuffix("M") || trimmed.hasSuffix("MB") {
            let numStr = trimmed.replacingOccurrences(of: "MB", with: "").replacingOccurrences(of: "M", with: "").trimmingCharacters(in: .whitespaces)
            return Double(numStr) ?? 0
        } else if trimmed.hasSuffix("K") || trimmed.hasSuffix("KB") {
            let numStr = trimmed.replacingOccurrences(of: "KB", with: "").replacingOccurrences(of: "K", with: "").trimmingCharacters(in: .whitespaces)
            return (Double(numStr) ?? 0) / 1024
        }
        return 0
    }

    static func sortScore(_ item: WorktreeSweeperItem) -> Int {
        switch item.statusType {
        case .mainRepo: return -1
        case .fullyMerged: return 100
        case .partiallyMerged(let count): return 50 + count * 10
        case .remoteDeleted: return 40
        case .stale: return 30
        case .active: return 10
        case .dirty: return 0
        }
    }

    static func analyze(
        projectWorktrees: [WorktreeItem],
        projectPath: String,
        existingBranches: Set<String>,
        gitCli: GitCliService
    ) async -> [WorktreeSweeperItem] {
        let mergeTargets = SweeperMergeTarget.ordered
        let targetNames = mergeTargets.map(\.rawValue)

        // 使用 concurrentPerform：每个分析都会执行阻塞式 git 子进程，
        // 放在 withTaskGroup 会占满 Swift 协作线程池，可能导致任务组永不完成。
        final class AnalysisCollector: @unchecked Sendable {
            private var items: [WorktreeSweeperItem] = []
            private let lock = NSLock()
            func append(_ item: WorktreeSweeperItem) {
                lock.lock()
                defer { lock.unlock() }
                items.append(item)
            }
            var all: [WorktreeSweeperItem] {
                lock.lock()
                defer { lock.unlock() }
                return items
            }
        }

        let collector = AnalysisCollector()
        let targets = projectWorktrees

        DispatchQueue.concurrentPerform(iterations: targets.count) { index in
            let item = targets[index]
            let result = analyzeOne(
                item: item,
                projectPath: projectPath,
                existingBranches: existingBranches,
                mergeTargets: mergeTargets,
                targetNames: targetNames,
                gitCli: gitCli
            )
            collector.append(result)
        }

        let analyzed = collector.all

        return analyzed.sorted { lhs, rhs in
            if lhs.isProtected != rhs.isProtected {
                return !lhs.isProtected && rhs.isProtected
            }
            let lScore = sortScore(lhs)
            let rScore = sortScore(rhs)
            if lScore != rScore { return lScore > rScore }
            return lhs.worktree.branch.localizedStandardCompare(rhs.worktree.branch) == .orderedAscending
        }
    }

    private static func analyzeOne(
        item: WorktreeItem,
        projectPath: String,
        existingBranches: Set<String>,
        mergeTargets: [SweeperMergeTarget],
        targetNames: [String],
        gitCli: GitCliService
    ) -> WorktreeSweeperItem {
        let isMain = item.kind == .mainRepo
        let isDirty = item.isDirty || item.dirtySummary.hasPrefix("有未提交") || item.dirtySummary.contains("未提交")
        let sizeMB = parseDiskUsageToMB(item.diskUsage)

        // 1. 主仓库优先判定（四条基线视为基准自身）
        if isMain {
            let statuses: [SweeperMergeTarget: Bool] = Dictionary(
                uniqueKeysWithValues: mergeTargets.map { ($0, true) }
            )
            return WorktreeSweeperItem(
                id: item.id,
                worktree: item,
                statusType: .mainRepo,
                statusTitle: "主仓库 (基准)",
                statusDescription: "生产代码基准目录，受系统强制保护",
                isProtected: true,
                isRecommended: false,
                diskUsageFormatted: item.diskUsage,
                approxSizeMB: sizeMB,
                mergeTargets: mergeTargets,
                mergeStatus: statuses
            )
        }

        // 2. 逐个基线检测合入情况
        let rawStatus = gitCli.checkBranchMergedTargets(
            projectPath: projectPath,
            branch: item.branch,
            targets: targetNames,
            existingBranches: existingBranches
        )
        let statuses: [SweeperMergeTarget: Bool] = Dictionary(
            uniqueKeysWithValues: mergeTargets.map { ($0, rawStatus[$0.rawValue] ?? false) }
        )
        let mergedTargets = mergeTargets.filter { statuses[$0] == true }
        let mergedCount = mergedTargets.count
        let isFullyMerged = mergedCount == mergeTargets.count && !mergeTargets.isEmpty

        // 3. 按合并优先级判定状态
        let statusType: WorktreeSweeperStatusType
        let statusTitle: String
        let statusDescription: String
        var isProtected = false
        var isRecommended = false

        if isFullyMerged {
            statusType = .fullyMerged
            statusTitle = "全部合入 (4/4)"
            statusDescription = "已完整合入 master / stage / test / uat 全部四条基线"
            isRecommended = true
        } else if mergedCount > 0 {
            statusType = .partiallyMerged(mergedCount: mergedCount)
            statusTitle = "已合入 \(mergedCount)/\(mergeTargets.count)"
            statusDescription = "已并入 " + mergedTargets.map(\.rawValue).joined(separator: " / ")
            isRecommended = !isDirty
        } else {
            let hasRemote = (try? gitCli.remoteBranchExists(projectPath: projectPath, branch: item.branch)) ?? true
            if !hasRemote {
                statusType = .remoteDeleted
                statusTitle = "远端分支已删除"
                statusDescription = "远端 tracking 分支已移除，本地为残留工作树"
                isRecommended = true
            } else {
                let isOlderThan30Days = item.updatedAt.contains("月")
                    || item.updatedAt.contains("年")
                    || (item.updatedAt.contains("天") && (Int(item.updatedAt.prefix(2)) ?? 0) >= 30)
                if isOlderThan30Days {
                    statusType = .stale(days: 30)
                    statusTitle = "休眠 >30 天"
                    statusDescription = "超过 30 天未更新，且未合入任何基线分支"
                    isRecommended = true
                } else {
                    statusType = .active
                    statusTitle = "活跃开发中"
                    statusDescription = "尚未合入任何基线分支，仍在跟进中"
                }
            }
        }

        // 4. 未提交改动强制保护（优先级最高）
        if isDirty {
            isProtected = true
            isRecommended = false
        }

        return WorktreeSweeperItem(
            id: item.id,
            worktree: item,
            statusType: statusType,
            statusTitle: statusTitle,
            statusDescription: isDirty ? "\(item.dirtySummary) · \(statusDescription)" : statusDescription,
            isProtected: isProtected,
            isRecommended: isRecommended,
            diskUsageFormatted: item.diskUsage,
            approxSizeMB: sizeMB,
            mergeTargets: mergeTargets,
            mergeStatus: statuses
        )
    }
}
