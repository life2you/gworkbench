import SwiftUI

@main
struct GWorkbenchApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .frame(minWidth: 1380, minHeight: 780)
        }
        .defaultSize(width: 1560, height: 900)
        .commands {
            CommandMenu("编辑器") {
                Button("用默认编辑器打开 (\(appModel.defaultIDEProfile.effectiveLabel))") {
                    appModel.openCurrentSelectionInIDE()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                if appModel.configuredIDEProfiles.count > 1 {
                    Menu("选择已配置的编辑器打开") {
                        ForEach(appModel.configuredIDEProfiles) { ide in
                            Button {
                                appModel.openCurrentSelectionInIDE(ide)
                            } label: {
                                if ide.id == appModel.defaultIDEProfile.id {
                                    Label("\(ide.effectiveLabel)（默认）", systemImage: "star.fill")
                                } else {
                                    Label(ide.effectiveLabel, systemImage: "macwindow")
                                }
                            }
                        }
                    }
                }

                Divider()

                Button("配置 IDE 编辑器…") {
                    appModel.showingSettingsSheet = true
                }
            }
        }
    }
}
