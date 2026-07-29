import SwiftUI

@main
struct FeatherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Feather", systemImage: "text.magnifyingglass") {
            Button("Look Up Selection    ⇧⌘C") {
                appDelegate.performLookup()
            }
            Divider()
            Button("Set Claude API Key…") {
                appDelegate.promptForAPIKey()
            }
            Divider()
            Button("Quit Feather") {
                NSApp.terminate(nil)
            }
        }
    }
}
