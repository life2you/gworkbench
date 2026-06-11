import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("设置")
                        .font(.title2.weight(.semibold))
                    Text("这里不再留空白。左边先告诉你每组配置管什么，右边再做具体编辑。")
                        .foregroundStyle(.secondary)
                }

                if let message = appModel.globalErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                SectionCard(title: "快速说明") {
                    VStack(alignment: .leading, spacing: 10) {
                        settingsLine("工作树项目根目录", "决定左侧 `工作树` 和 `分支同步` 会扫描哪些本地仓库。")
                        settingsLine("MR 项目根目录", "只用于 `合并请求` 页面匹配哪些本地项目参与 GitLab MR 管理。")
                        settingsLine("merge_branch_middle", "用来生成默认合并分支名，例如 `uat_henry_meger` 里的 `henry`。")
                        settingsLine("环境分支", "定义发布链路里的环境名，例如 `uat, test, stage, pre_prod`。")
                        settingsLine("保护目标分支", "命中这些目标分支时，自动合并策略会更谨慎。")
                    }
                }

                SectionCard(title: "目录关系") {
                    VStack(alignment: .leading, spacing: 10) {
                        settingsLine("工作树", "使用 `工作树项目根目录` 扫描项目。")
                        settingsLine("分支同步", "现在也使用 `工作树项目根目录` 扫描项目，和工作树保持同一批仓库。")
                        settingsLine("MR 管理", "使用 `MR 项目根目录` 扫描项目，再去匹配 GitLab 同名项目。")
                    }
                }

                SectionCard(title: "当前配置状态") {
                    VStack(alignment: .leading, spacing: 10) {
                        settingsLine("配置文件", appModel.settingsDraft.configPath.isEmpty ? "尚未加载" : appModel.settingsDraft.configPath)
                        settingsLine("工作树项目目录数", "\(appModel.settingsDraft.worktreeProjectsRootDirs.count)")
                        settingsLine("MR 项目目录数", "\(appModel.settingsDraft.mergeRootDirs.count)")
                        settingsLine("分支映射数", "\(appModel.settingsDraft.branchMappings.count)")
                    }
                }

                SectionCard(title: "建议") {
                    VStack(alignment: .leading, spacing: 10) {
                        settingsLine("先配目录", "先保证根目录能扫到仓库，再去调 MR 和分支映射。")
                        settingsLine("环境分支别随便删空", "默认分支同步和默认 MR 映射都依赖它。")
                        settingsLine("Token 权限", "GitLab Token 至少要能读取项目、创建 MR、审批和合并。")
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func settingsLine(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}
