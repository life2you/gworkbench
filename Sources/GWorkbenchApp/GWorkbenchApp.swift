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
    }
}
