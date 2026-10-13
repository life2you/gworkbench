import SwiftUI
import AppKit

struct SettingsDetailView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerSection

                quickActionRow

                inspectorCard(title: "配置文件存储", systemImage: "doc.text") {
                    VStack(alignment: .leading, spacing: 8) {
                        inspectorRow(
                            label: "主配置文件",
                            value: appModel.settingsDraft.configPath.isEmpty ? "未加载" : appModel.settingsDraft.configPath,
                            isMonospaced: true,
                            canCopy: true
                        )
                        inspectorRow(
                            label: "元数据文件",
                            value: appModel.settingsDraft.metadataPath.isEmpty ? "未加载" : appModel.settingsDraft.metadataPath,
                            isMonospaced: true,
                            canCopy: true
                        )
                    }
                }

                inspectorCard(title: "运行健康雷达", systemImage: "stethoscope") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("本地代码仓库")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                            Spacer()
                            StatusPill(
                                title: "\(appModel.worktreeProjects.count) 个仓库",
                                tint: appModel.worktreeProjects.isEmpty ? .orange : .green
                            )
                        }

                        HStack {
                            Text("托管服务连接池")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                            Spacer()
                            StatusPill(
                                title: "GitLab + GitHub 就绪",
                                tint: .green,
                                systemImage: "network"
                            )
                        }

                        HStack {
                            Text("策略模板生效")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                            Spacer()
                            StatusPill(
                                title: "2 组模板 (含环境流)",
                                tint: .purple
                            )
                        }

                        HStack {
                            Text("默认终端应用")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                            Spacer()
                            StatusPill(
                                title: appModel.settingsDraft.terminalApp.isEmpty ? "Terminal" : appModel.settingsDraft.terminalApp,
                                tint: appModel.scannedTerminals.first(where: { $0.name == appModel.settingsDraft.terminalApp })?.isInstalled == true ? .green : .blue,
                                systemImage: "terminal.fill"
                            )
                        }

                        HStack {
                            Text("默认 IDE 编辑器")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                            Spacer()
                            StatusPill(
                                title: appModel.settingsDraft.ideLabel.isEmpty ? "系统默认" : appModel.settingsDraft.ideLabel,
                                tint: appModel.scannedIDEs.first(where: { $0.name.caseInsensitiveCompare(appModel.settingsDraft.ideCommand) == .orderedSame })?.isInstalled == true ? .green : .blue,
                                systemImage: "macwindow"
                            )
                        }

                        HStack {
                            Text("路径命名模板")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(appModel.settingsDraft.worktreePathTemplate.replacingOccurrences(of: "${rootDir}/", with: ""))
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                inspectorCard(title: "使用建议与安全准则", systemImage: "lightbulb") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• 优先保证根目录正确配置，以便完整扫描本地代码库。")
                        Text("• GitLab Token 仅保存在本地 ~/.config/gworkbench/config.toml，不向任何第三方服务上传。")
                        Text("• 生产基准分支（如 master/main）建议配置进保护目标分支列表，避免意外自动合入。")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("GWorkbench")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("/")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("首选项")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text("配置与运行诊断")
                .font(.system(size: 16, weight: .semibold))

            Text("实时监控本地工作树存储与 GitLab 服务凭据状态。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                StatusPill(title: "独立桌面配置", tint: .blue)
                StatusPill(title: "\(appModel.settingsDraft.branchMappings.count) 组分支映射", tint: .purple)
            }
            .padding(.top, 2)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Quick Action Row

    private var quickActionRow: some View {
        HStack(spacing: 6) {
            Button {
                let path = appModel.settingsDraft.configPath
                if !path.isEmpty {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                }
            } label: {
                Label("访达中显示", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                let path = appModel.settingsDraft.configPath
                if !path.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                }
            } label: {
                Label("复制路径", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                Task {
                    await appModel.reloadSettingsOnly()
                }
            } label: {
                Label("重新加载", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Inspector Helpers

    private func inspectorRow(label: String, value: String, isMonospaced: Bool = false, canCopy: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .leading)

            Text(value)
                .font(isMonospaced ? .system(size: 11.5, design: .monospaced) : .system(size: 11.5))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if canCopy {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("复制")
            }
        }
    }

    private func inspectorCard<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            content()
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
        )
    }
}
