import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Reads the text currently selected in whatever app is frontmost.
enum SelectionReader {
    static func currentSelection() -> String? {
        if let text = accessibilitySelection(), !text.isEmpty {
            return text
        }
        return copyFallbackSelection()
    }

    /// Preferred path: ask the focused UI element for its selected text —
    /// directly, then via selected-range → string (helps some apps that
    /// don't populate kAXSelectedText).
    private static func accessibilitySelection() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success, let focusedRef else { return nil }

        let focused = focusedRef as! AXUIElement

        var selectionRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectionRef
        ) == .success, let text = selectionRef as? String, !text.isEmpty {
            return text
        }

        return rangeSelection(from: focused)
    }

    private static func rangeSelection(from element: AXUIElement) -> String? {
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeRef
        ) == .success, let rangeRef else { return nil }

        let rangeValue = rangeRef as! AXValue
        var range = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &range), range.length > 0 else { return nil }

        var stringRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &stringRef
        ) == .success else { return nil }

        return stringRef as? String
    }

    /// Fallback for apps with poor AX support (GPU-rendered terminals like
    /// Warp, some Electron apps): synthesize ⌘C, read the pasteboard, then
    /// restore it.
    private static func copyFallbackSelection() -> String? {
        // The user is still physically holding ⌃⌘ from the hotkey; if we
        // synthesize ⌘C now, some apps read the hardware modifier state and
        // see ⌃⌘C instead. Wait for all modifiers to be released.
        waitForModifierRelease()

        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)
        let changeCount = pasteboard.changeCount

        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        else { return nil }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        usleep(10_000)
        keyUp.post(tap: .cghidEventTap)

        // Wait up to ~1s for the frontmost app to service the copy.
        var copied = false
        for _ in 0..<50 {
            usleep(20_000)
            if pasteboard.changeCount != changeCount {
                copied = true
                break
            }
        }
        guard copied else { return nil }

        let text = pasteboard.string(forType: .string)

        // Put the user's clipboard back (string contents only).
        if let saved {
            pasteboard.clearContents()
            pasteboard.setString(saved, forType: .string)
        }
        return text
    }

    private static func waitForModifierRelease() {
        let interesting: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
        for _ in 0..<40 {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            if flags.intersection(interesting).isEmpty { return }
            usleep(15_000)
        }
    }
}
