import SwiftUI

// Custom notification names for menu actions
extension Notification.Name {
    static let showAboutInfo = Notification.Name("showAboutInfo")
    static let checkForUpdates = Notification.Name("checkForUpdates")
}

@main
struct ImageViewerProApp: App {
    // The view model is now created here as a @StateObject, so it can be shared
    // with the main view and the .onOpenURL modifier.
    @StateObject private var viewModel = ImageViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 1024, minHeight: 768)
                // MODIFIED: .onOpenURL is now correctly applied to the view inside the WindowGroup.
                .onOpenURL { url in
                    // It passes the file's URL to our view model to be handled.
                    viewModel.handleOpenFile(url: url)
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ImageViewerPro") {
                    NotificationCenter.default.post(name: .showAboutInfo, object: nil)
                }
            }
            
            CommandMenu("Help") {
                Button("Check for Updates...") {
                    NotificationCenter.default.post(name: .checkForUpdates, object: nil)
                }
            }
        }
    }
}
