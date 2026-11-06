import SwiftUI
import AppKit

struct RebasedInstallSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                    .frame(width: 56, height: 56)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("检测到代码冲突，推荐使用 Rebased 解决")
                        .font(.headline)
                    Text("Rebased 是一个极速、独立提取自 IntelliJ 的 3-Way 可视化合并利器，能大幅降低冲突解决难度。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                Text("为什么推荐 Rebased？")
                    .font(.subheadline.bold())

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("三方对比视窗：左侧当前、右侧传入、中间为解决结果，支持一键点击箭头合并。")
                        .font(.caption)
                }
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("轻量独立运行：无需打开庞大的 IDE，专注于冲突解决，秒开秒退。")
                        .font(.caption)
                }
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("无缝流水线协同：在 Rebased 解决并保存后，GWorkbench 自动感知并推进下一分支。")
                        .font(.caption)
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if appModel.isInstallingRebased || !appModel.rebasedInstallLog.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        if appModel.isInstallingRebased {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(appModel.rebasedInstallLog)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(appModel.rebasedInstallLog.contains("失败") ? .red : .primary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack {
                Button("暂不安装，手动解决") {
                    dismiss()
                }
                .disabled(appModel.isInstallingRebased)

                Spacer()

                Button {
                    Task {
                        await appModel.installRebased()
                    }
                } label: {
                    if appModel.isInstallingRebased {
                        Text("正在通过 Homebrew 安装...")
                    } else {
                        Text("一键帮我安装 Rebased (Brew Cask)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appModel.isInstallingRebased)
            }
        }
        .padding(24)
        .frame(width: 540)
    }
}
