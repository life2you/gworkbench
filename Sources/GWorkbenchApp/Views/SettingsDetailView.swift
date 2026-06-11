import SwiftUI
import AppKit

struct SettingsDetailView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("GWorkbench 设置")
                            .font(.largeTitle.weight(.semibold))
                        Text("独立维护桌面版自己的配置文件，保存后会立即刷新工作树和 MR 数据。")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        Button("从 gwtm / gmux 导入") {
                            Task { await appModel.importLegacyConfigs() }
                        }
                        Button("重新加载") {
                            Task { await appModel.reloadSettingsOnly() }
                        }
                        Button("保存设置") {
                            Task { await appModel.saveSettings() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                InlineOperationView(state: appModel.settingsOperation)

                SectionCard(title: "配置文件") {
                    VStack(alignment: .leading, spacing: 12) {
                        settingHelp(
                            "配置路径",
                            "GWorkbench 自己的主配置文件位置。保存设置时会直接写回这里。"
                        )
                        DetailLabelRow(title: "配置路径", value: appModel.settingsDraft.configPath)

                        settingHelp(
                            "元数据路径",
                            "工作树功能描述保存在这里，不会写回项目仓库。"
                        )
                        DetailLabelRow(title: "元数据路径", value: appModel.settingsDraft.metadataPath)
                    }
                }

                SectionCard(title: "工作树") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            settingHelp(
                                "工作树根目录",
                                "新建 worktree 时默认创建到这个目录下。"
                            )
                            HStack(spacing: 12) {
                                TextField("工作树根目录", text: $appModel.settingsDraft.worktreesRootDir)
                                Button("选择目录") {
                                    if let path = chooseDirectory() {
                                        appModel.settingsDraft.worktreesRootDir = path
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            settingHelp(
                                "IDE 打开方式",
                                "`app` 会按 App 名称打开，`system` 使用系统默认方式打开目录。"
                            )
                            HStack(spacing: 12) {
                                Picker("IDE 模式", selection: $appModel.settingsDraft.ideMode) {
                                    Text("app").tag("app")
                                    Text("system").tag("system")
                                    Text("custom").tag("custom")
                                }
                                .frame(width: 180)

                                TextField("IDE 命令 / App 名称", text: $appModel.settingsDraft.ideCommand)
                                TextField("IDE 显示名称", text: $appModel.settingsDraft.ideLabel)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("工作树项目根目录")
                                        .font(.headline)
                                    Text("决定 `工作树` 和 `分支同步` 两个页面能扫描到哪些本地仓库。")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("选择目录") {
                                    if let path = chooseDirectory() {
                                        appModel.addWorktreeProjectsRoot(path)
                                    }
                                }
                            }

                            ForEach($appModel.settingsDraft.worktreeProjectsRootDirs) { $entry in
                                HStack(spacing: 10) {
                                    TextField("项目根目录", text: $entry.path)
                                    Button(role: .destructive) {
                                        appModel.removeWorktreeProjectsRoot(id: entry.id)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                SectionCard(title: "GitLab 与 MR") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            settingHelp(
                                "GitLab 地址",
                                "用于读取项目、拉取 MR 列表、审批、关闭和自动合并。示例: `http://gitlab.example.com:8099`。"
                            )
                            TextField("GitLab Host", text: $appModel.settingsDraft.gitlabHost)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            settingHelp(
                                "GitLab Token",
                                "需要具备读取项目、创建 MR、审批和合并权限。"
                            )
                            HStack(spacing: 10) {
                                Group {
                                    if appModel.settingsTokenVisible {
                                        TextField("GitLab Token", text: $appModel.settingsDraft.gitlabToken)
                                    } else {
                                        SecureField("GitLab Token", text: $appModel.settingsDraft.gitlabToken)
                                    }
                                }
                                Button {
                                    appModel.settingsTokenVisible.toggle()
                                } label: {
                                    Image(systemName: appModel.settingsTokenVisible ? "eye.slash" : "eye")
                                }
                            }
                        }

                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                settingHelp(
                                    "merge_branch_middle",
                                    "默认合并分支名的中间段。例如环境 `uat` 会生成 `uat_henry_meger`。"
                                )
                                TextField("merge_branch_middle", text: $appModel.settingsDraft.mergeBranchMiddle)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                settingHelp(
                                    "环境分支",
                                    "发布链路中的环境名列表，逗号分隔。会影响分支同步和默认 MR 映射。"
                                )
                                TextField("环境分支（逗号分隔）", text: $appModel.settingsDraft.envBranchesText)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                settingHelp(
                                    "保护目标分支",
                                    "这些目标分支会被视为高风险分支，自动合并策略更谨慎。"
                                )
                                TextField("保护目标分支（逗号分隔）", text: $appModel.settingsDraft.protectedTargetsText)
                            }
                        }

                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                settingHelp(
                                    "自动合并等待秒数",
                                    "每次调用 merge 之前先等待几秒，给 GitLab pipeline 或状态刷新留时间。"
                                )
                                TextField("自动合并等待秒数", text: $appModel.settingsDraft.autoMergeDelaySecondsText)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                settingHelp(
                                    "自动合并重试次数",
                                    "merge 失败时最多再试几次。总尝试次数 = 1 + 重试次数。"
                                )
                                TextField("自动合并重试次数", text: $appModel.settingsDraft.autoMergeRetryCountText)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("MR 项目根目录")
                                        .font(.headline)
                                    Text("只影响 `合并请求` 页面扫描哪些本地项目去匹配 GitLab 仓库。")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("选择目录") {
                                    if let path = chooseDirectory() {
                                        appModel.addMergeRoot(path)
                                    }
                                }
                            }

                            ForEach($appModel.settingsDraft.mergeRootDirs) { $entry in
                                HStack(spacing: 10) {
                                    TextField("MR 项目根目录", text: $entry.path)
                                    Button(role: .destructive) {
                                        appModel.removeMergeRoot(id: entry.id)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                SectionCard(title: "分支映射") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("一条一条维护 source -> target 映射。")
                                    .foregroundStyle(.secondary)
                                Text("批量创建 MR 时会直接使用这里的映射。左边是来源分支，右边是目标分支。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("新增映射") {
                                appModel.addBranchMapping()
                            }
                        }

                        ForEach($appModel.settingsDraft.branchMappings) { $mapping in
                            HStack(spacing: 10) {
                                TextField("来源分支", text: $mapping.source)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                TextField("目标分支", text: $mapping.target)
                                Button(role: .destructive) {
                                    appModel.removeBranchMapping(id: mapping.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }

                        if appModel.settingsDraft.branchMappings.isEmpty {
                            Text("当前还没有映射，点“新增映射”开始添加。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func chooseDirectory() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "选择"
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    private func settingHelp(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}
