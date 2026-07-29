import SwiftUI

@main
struct HoverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Hover", systemImage: "text.magnifyingglass") {
            Button("Look Up Selection    ⇧⌘C") {
                appDelegate.performLookup()
            }
            Divider()
            Button("Set Claude API Key…") {
                appDelegate.promptForAPIKey()
            }
            Divider()
            Button("Quit Hover") {
                NSApp.terminate(nil)
            }
        }
    }
}
