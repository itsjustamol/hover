import AppKit
import SwiftUI
import Combine

/// A transient, non-activating panel — behaves like the built-in Dictionary
/// popover: appears at the cursor, never steals focus from the app you're in,
/// and disappears when you click anywhere outside it.
final class LookupPanel: NSPanel {
    static let panelWidth: CGFloat = 440
    private static let minHeight: CGFloat = 148
    private static let maxHeight: CGFloat = 460
    /// Header + divider + capsule gap + follow-up capsule + paddings
    /// around the transcript.
    private static let chromeHeight: CGFloat = 112

    let model = LookupModel()
    var onDismiss: (() -> Void)?

    private var clickMonitor: Any?
    private var escGlobalMonitor: Any?
    private var escLocalMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.minHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        // No window-level shadow: it's computed against the rectangular
        // window frame and shows up as a hairline box around the glass
        // shapes (including the transparent gap between them). The Liquid
        // Glass shapes carry their own edge treatment.
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow
        // Only take key status when the user clicks the follow-up field —
        // showing the panel never steals focus from the frontmost app.
        becomesKeyOnlyIfNeeded = true

        let hosting = NSHostingView(rootView: LookupView(model: model))
        hosting.frame = NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.minHeight)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting

        model.$contentHeight
            .removeDuplicates()
            .throttle(for: .milliseconds(60), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] height in
                self?.resize(toContentHeight: height)
            }
            .store(in: &cancellables)
    }

    // Key status is allowed (for typing follow-ups) but only "if needed" —
    // the frontmost app keeps focus until the user clicks the input field.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func show(query: String, at screenPoint: NSPoint) {
        model.reset(query: query)
        position(at: screenPoint, height: Self.minHeight)
        orderFrontRegardless()
        installClickMonitor()
    }

    func dismiss() {
        guard isVisible else { return }
        orderOut(nil)
        removeClickMonitor()
        onDismiss?()
    }

    private func position(at point: NSPoint, height: CGFloat) {
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        // Below-right of the cursor, clamped to the screen.
        var x = point.x - 20
        var y = point.y - height - 10
        x = min(max(x, visible.minX + 8), visible.maxX - Self.panelWidth - 8)
        if y < visible.minY + 8 {
            y = min(point.y + 14, visible.maxY - height - 8)
        }
        setFrame(NSRect(x: x, y: y, width: Self.panelWidth, height: height), display: true)
    }

    /// Grow downward as the answer streams in, keeping the top edge anchored.
    private func resize(toContentHeight contentHeight: CGFloat) {
        guard isVisible else { return }
        let target = min(max(contentHeight + Self.chromeHeight, Self.minHeight), Self.maxHeight)
        guard abs(target - frame.height) > 1 else { return }

        var newFrame = frame
        let top = frame.maxY
        newFrame.size.height = target
        newFrame.origin.y = top - target

        if let visible = screen?.visibleFrame, newFrame.minY < visible.minY + 8 {
            newFrame.origin.y = visible.minY + 8
        }
        setFrame(newFrame, display: true, animate: false)
    }

    private func installClickMonitor() {
        removeClickMonitor()
        // Global monitor: fires for clicks in *other* apps only, so clicks
        // inside the panel don't dismiss it.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.dismiss()
        }
        // Esc while focus is still in the other app (observed, not consumed).
        escGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.dismiss() }
        }
        // Esc while the panel itself is key (user is typing a follow-up) —
        // consumed so it doesn't leak anywhere else.
        escLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismiss()
                return nil
            }
            return event
        }
    }

    private func removeClickMonitor() {
        for monitor in [clickMonitor, escGlobalMonitor, escLocalMonitor] {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
        clickMonitor = nil
        escGlobalMonitor = nil
        escLocalMonitor = nil
    }
}
