import AppKit
import SwiftUI
import Combine

/// A floating, non-activating panel in the spirit of the built-in Dictionary
/// popover: appears at the cursor and never steals focus from the app you're
/// in. It stays up while you work and closes on Esc, the header's close
/// control, or the hotkey toggle.
final class LookupPanel: NSPanel {
    /// Width of the visible glass shapes.
    static let contentWidth: CGFloat = 440
    /// Transparent margin around the glass. Without it the shapes touch the
    /// window boundary and the glass blur clamps at the edge, smearing the
    /// backdrop into streaks. The margin gives the sampler headroom.
    static let margin: CGFloat = 24
    static var panelWidth: CGFloat { contentWidth + margin * 2 }
    private static let minHeight: CGFloat = 148 + 48
    private static let maxHeight: CGFloat = 460 + 48
    /// Header + divider + capsule gap + follow-up capsule + paddings
    /// around the transcript + the transparent margin.
    private static let chromeHeight: CGFloat = 112 + 48

    let model = LookupModel()
    var onDismiss: (() -> Void)?

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
        // The panel takes key status the moment it appears (Spotlight-style).
        // Two reasons: keyboard focus lands in the follow-up field and Esc is
        // captured without clicking first, and, because macOS renders
        // key-window glass more opaque than idle glass, the material doesn't
        // visibly "pop" when the input is first focused. The host app stays
        // visually active throughout (non-activating panel).

        let hosting = NSHostingView(rootView: LookupView(model: model))
        hosting.frame = NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.minHeight)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting

        model.onClose = { [weak self] in
            self?.dismiss()
        }

        model.$contentHeight
            .removeDuplicates()
            .throttle(for: .milliseconds(60), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] height in
                self?.resize(toContentHeight: height)
            }
            .store(in: &cancellables)
    }

    // Key status is required for typing follow-ups and capturing Esc; the
    // panel takes it on show (see init notes above).
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func show(query: String, at screenPoint: NSPoint) {
        model.reset(query: query)
        position(at: screenPoint, height: Self.minHeight)
        orderFrontRegardless()
        makeKey()
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

        // Below-right of the cursor, clamped to the screen. Offsets are
        // relative to the *visible* glass edge, which sits `margin` inside
        // the window frame.
        var x = point.x - 20 - Self.margin
        var y = point.y - height - 10 + Self.margin
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
        // Clicking outside deliberately does NOT dismiss, the popover stays
        // up so the user can read alongside other work. Only Esc, the ✕ esc
        // control, or the hotkey toggle closes it.
        // Esc while focus is still in the other app (observed, not consumed).
        escGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.dismiss() }
        }
        // Esc while the panel itself is key (user is typing a follow-up) -
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
        for monitor in [escGlobalMonitor, escLocalMonitor] {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
        escGlobalMonitor = nil
        escLocalMonitor = nil
    }
}
