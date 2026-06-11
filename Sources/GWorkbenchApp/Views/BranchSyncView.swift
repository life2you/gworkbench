import SwiftUI

struct BranchSyncView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        VStack(spacing: 0) {
            header

            if appModel.localMergeProjects.isEmpty {
                ContentUnavailableView("未检测到 gmux 本地项目", systemImage: "arrow.triangle.branch")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionCard(title: "执行模式") {
                            Picker("执行模式", selection: $appModel.localOperationMode) {
                                ForEach(LocalBranchOperationMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: appModel.localOperationMode) { _, newValue in
                                appModel.setLocalOperationMode(newValue)
                            }

                            Text(appModel.localOperationMode.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if appModel.localOperationMode.requiresSourceBranch {
                            SectionCard(title: "源分支") {
                                TextField("筛选本地源分支", text: $appModel.localBranchSearchText)
                                    .textFieldStyle(.roundedBorder)

                                if appModel.filteredLocalBranches.isEmpty {
                                    Text("当前项目没有可选的本地分支。")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Picker("源分支", selection: $appModel.localOperationSourceBranch) {
                                        ForEach(appModel.filteredLocalBranches, id: \.self) { branch in
                                            Text(branch).tag(branch)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                        }

                        SectionCard(title: "目标分支") {
                            switch appModel.localOperationMode {
                            case .syncEnvironments:
                                targetList(showSelectionHint: false)
                            case .mergeAll:
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("将把当前源分支依次合并到以下全部目标分支。")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    targetList(showSelectionHint: false)
                                }
                            case .mergeSingle:
                                if appModel.localTargetOptions.isEmpty {
                                    Text("当前没有可用的目标分支。")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Picker("目标分支", selection: $appModel.localOperationSingleTarget) {
                                        ForEach(appModel.localTargetOptions) { option in
                                            Text(option.label).tag(option.targetBranch)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            case .mergeCustom:
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("勾选这次要处理的目标分支。")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    if appModel.localTargetOptions.isEmpty {
                                        Text("当前没有可用的目标分支。")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        ForEach(appModel.localTargetOptions) { option in
                                            Toggle(isOn: customTargetBinding(option.targetBranch)) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(option.targetBranch)
                                                        .font(.subheadline.weight(.medium))
                                                    Text("环境分支 \(option.envBranch)")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            .toggleStyle(.checkbox)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ViewThatFits(in: .horizontal) {
                wideHeader
                compactHeader
            }

            InlineOperationView(state: appModel.localOperation)
        }
        .padding(20)
        .background(.bar)
    }

    private var wideHeader: some View {
        HStack(spacing: 12) {
            titleBlock
            Spacer()
            projectPicker
                .frame(width: 240)
            refreshButton
            executeButton
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleBlock
            HStack(spacing: 12) {
                projectPicker
                    .frame(minWidth: 220, maxWidth: 320)
                Spacer(minLength: 0)
                refreshButton
                executeButton
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("分支同步")
                .font(.title2.weight(.semibold))
            Text("把 gmux 里的本地分支同步、批量 merge 和推送流程搬回桌面版。")
                .foregroundStyle(.secondary)
        }
    }

    private var projectPicker: some View {
        Picker("项目", selection: localProjectBinding) {
            ForEach(appModel.localMergeProjects) { project in
                Text(project.displayName).tag(Optional(project.id))
            }
        }
        .pickerStyle(.menu)
    }

    private var refreshButton: some View {
        Button("刷新") {
            Task {
                await appModel.refreshLocalMergeProjects()
            }
        }
    }

    private var executeButton: some View {
        Button("开始执行") {
            Task {
                await appModel.executeLocalOperation()
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!appModel.canExecuteLocalOperation)
    }

    private var localProjectBinding: Binding<String?> {
        Binding(
            get: { appModel.selectedLocalProjectID },
            set: { if let value = $0 { appModel.selectLocalProject(value) } }
        )
    }

    @ViewBuilder
    private func targetList(showSelectionHint: Bool) -> some View {
        if appModel.localTargetOptions.isEmpty {
            Text("当前没有可用的目标分支。")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if showSelectionHint {
                    Text("按需选择这次要处理的目标分支。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(appModel.localTargetOptions) { option in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.targetBranch)
                                .font(.subheadline.weight(.medium))
                            Text("环境分支 \(option.envBranch)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func customTargetBinding(_ target: String) -> Binding<Bool> {
        Binding(
            get: { appModel.localOperationCustomTargets.contains(target) },
            set: { _ in appModel.toggleCustomLocalTarget(target) }
        )
    }
}
