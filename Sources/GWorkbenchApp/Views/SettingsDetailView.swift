import SwiftUI
import AppKit

struct SettingsDetailView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let rebasedInstalled = RebasedService.shared.isInstalled
        let currentWS = appModel.activeWorkspace
        let githubReady = appModel.ghCLITokenAvailable
            || (currentWS?.platform == .github && !(currentWS?.token ?? "").isEmpty)
            || !appModel.settingsDraft.githubToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let activeCredReady: Bool = {
            guard let ws = currentWS else { return false }
            if ws.platform == .github {
                return appModel.ghCLITokenAvailable || !ws.token.isEmpty
            } else {
                return !ws.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !ws.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }()

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerSection

                Divider().opacity(0.5)

                if let ws = currentWS {
                    inspectorCard(title: "当前工作区概览", systemImage: ws.platform.icon) {
                        VStack(alignment: .leading, spacing: 8) {
                            detailRow(label: "标签名称", value: ws.name)
                            detailRow(label: "托管平台", value: ws.platform.shortName)
                            detailRow(label: "绑定目录", value: ws.projectsRootDirs.joined(separator: ", "))
                            detailRow(label: "扫描仓库", value: "\(appModel.filteredWorktreeProjects.count) 个本地仓库")
                            detailRow(label: "生产主干", value: ws.configuredMainlineBranches.isEmpty ? "未配置" : ws.configuredMainlineBranches.joined(separator: ", "))
                            detailRow(label: "保护分支", value: ws.effectiveProtectedBranches.isEmpty ? "未配置" : ws.effectiveProtectedBranches.joined(separator: ", "))
                            detailRow(label: "看板基线", value: ws.effectiveDashboardBaselines.joined(separator: ", "))
                        }
                    }
                }

                inspectorCard(title: "本机依赖自检", systemImage: "stethoscope") {
                    VStack(alignment: .leading, spacing: 8) {
                        checkRow(
                            label: "Git CLI",
                            value: appModel.gitVersion.isEmpty ? "未检测" : "✓ \(appModel.gitVersion.replacingOccurrences(of: "git version ", with: ""))",
                            ok: !appModel.gitVersion.isEmpty
                        )
                        checkRow(
                            label: "Rebased (冲突解决)",
                            value: rebasedInstalled ? "✓ 已安装" : "○ 未安装",
                            ok: rebasedInstalled
                        )
                        checkRow(
                            label: "GitHub gh CLI",
                            value: githubReady ? (appModel.ghCLITokenAvailable ? "✓ 已登录" : "✓ 已配置 PAT") : "○ 未登录",
                            ok: githubReady
                        )
                        if let ws = currentWS {
                            checkRow(
                                label: "\(ws.name) 凭据",
                                value: activeCredReady ? "✓ 就绪" : "○ 未配置",
                                ok: activeCredReady
                            )
                        }
                    }
                }

                if !rebasedInstalled {
                    Button {
                        appModel.showingRebasedInstallSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("一键安装 Rebased 冲突解决器")
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                if let ws = currentWS {
                    Button {
                        appModel.openEditWorkspaceEditor(ws)
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("编辑「\(ws.name)」标签配置")
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                Button {
                    appModel.openNewWorkspaceEditor()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("新建另一个工作区标签")
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Divider().opacity(0.4)

                Button {
                    let path = appModel.settingsDraft.configPath
                    if !path.isEmpty {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder.fill")
                        Text("在 Finder 打开配置目录")
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                HStack(spacing: 8) {
                    Button {
                        let path = appModel.settingsDraft.configPath
                        if !path.isEmpty {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(path, forType: .string)
                        }
                    } label: {
                        Label("复制路径", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        Task { await appModel.reloadSettingsOnly() }
                    } label: {
                        Label("重新加载", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("配置诊断与当前标签")
                .font(.system(size: 14.5, weight: .semibold))

            Text(appModel.settingsDraft.configPath.isEmpty ? "~/.config/gworkbench/config.toml" : appModel.settingsDraft.configPath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Helpers

    private func checkRow(label: String, value: String, ok: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(ok ? Color.green : Color.secondary)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func inspectorCard<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 0.75)
        )
    }
}
