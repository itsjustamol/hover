import AppKit
import ApplicationServices
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panel = LookupPanel()
    private var lookupTask: Task<Void, Never>?
    private var titleTask: Task<Void, Never>?

    /// Selections longer than this get an AI-generated header title.
    private let titleThreshold = 60

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Ask for Accessibility access up front — needed to read the current
        // selection (AX API) and for the copy-based fallback (posting ⌘C).
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        panel.onDismiss = { [weak self] in
            self?.lookupTask?.cancel()
            self?.lookupTask = nil
            self?.titleTask?.cancel()
            self?.titleTask = nil
        }

        panel.model.onFollowUp = { [weak self] question in
            self?.askFollowUp(question)
        }

        // ⇧⌘C
        HotKeyCenter.shared.register(
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: UInt32(shiftKey | cmdKey)
        ) { [weak self] in
            self?.toggleLookup()
        }
    }

    func toggleLookup() {
        if panel.isVisible {
            panel.dismiss()
        } else {
            performLookup()
        }
    }

    func performLookup() {
        lookupTask?.cancel()
        titleTask?.cancel()
        let mouse = NSEvent.mouseLocation

        guard AXIsProcessTrusted() else {
            panel.show(query: "Hover", at: mouse)
            panel.model.fail("Hover needs Accessibility access to read your selection. Enable Hover in the settings pane that just opened, then quit and relaunch Hover from the menu bar icon.")
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            return
        }

        guard let selection = SelectionReader.currentSelection(),
              !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            panel.show(query: "Hover", at: mouse)
            panel.model.fail("No selection found. Select some text, then press ⇧⌘C.")
            return
        }

        panel.show(query: selection, at: mouse)

        guard let apiKey = ClaudeClient.resolveAPIKey() else {
            panel.model.fail("No API key. Choose \"Set Claude API Key…\" from the menu bar icon, or launch with ANTHROPIC_API_KEY set.")
            return
        }

        let model = panel.model
        model.apiMessages = [["role": "user", "content": selection]]
        model.exchanges = [.init(question: nil)]
        startStream(model: model, apiKey: apiKey)

        // Long selections get a short AI-generated title in the header.
        if selection.count > titleThreshold {
            titleTask = Task { @MainActor in
                if let title = try? await ClaudeClient.title(for: selection, apiKey: apiKey),
                   !title.isEmpty, !Task.isCancelled {
                    model.title = title
                }
            }
        }
    }

    private func askFollowUp(_ question: String) {
        let model = panel.model
        guard let apiKey = ClaudeClient.resolveAPIKey() else {
            model.fail("No API key. Choose \"Set Claude API Key…\" from the menu bar icon.")
            return
        }
        lookupTask?.cancel()
        model.apiMessages.append(["role": "user", "content": question])
        model.exchanges.append(.init(question: question))
        startStream(model: model, apiKey: apiKey)
    }

    private func startStream(model: LookupModel, apiKey: String) {
        model.phase = .loading
        lookupTask = Task { @MainActor in
            do {
                var full = ""
                for try await delta in ClaudeClient.stream(messages: model.apiMessages, apiKey: apiKey) {
                    if case .loading = model.phase { model.phase = .streaming }
                    full += delta
                    if let last = model.exchanges.indices.last {
                        model.exchanges[last].answer = full
                    }
                }
                model.apiMessages.append(["role": "assistant", "content": full])
                model.phase = .done
            } catch is CancellationError {
                // dismissed mid-stream — nothing to do
            } catch {
                model.fail(error.localizedDescription)
            }
        }
    }

    func promptForAPIKey() {
        let alert = NSAlert()
        alert.messageText = "Claude API Key"
        alert.informativeText = "Stored in your login keychain and used only for lookups."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "sk-ant-…"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { Keychain.save(key) }
        }
    }
}
