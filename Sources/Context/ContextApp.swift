import SwiftUI

@main
struct ContextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Context", systemImage: "text.magnifyingglass") {
            Button("Look Up Selection    ⇧⌘C") {
                appDelegate.performLookup()
            }
            Divider()
            Button("Set Claude API Key…") {
                appDelegate.promptForAPIKey()
            }
            Divider()
            Button("Quit Context") {
                NSApp.terminate(nil)
            }
        }
    }
}
