import Carbon.HIToolbox

/// Global hotkey registration via Carbon. No special permissions required.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var callbacks: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var nextID: UInt32 = 1
    private var handlerInstalled = false

    func register(keyCode: UInt32, modifiers: UInt32, _ callback: @escaping () -> Void) {
        installHandlerIfNeeded()

        let id = nextID
        nextID += 1
        callbacks[id] = callback

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x46_54_48_52) /* 'FTHR' */, id: id)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        hotKeyRefs.append(ref)
    }

    fileprivate func fire(id: UInt32) {
        callbacks[id]?()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            let id = hotKeyID.id
            DispatchQueue.main.async {
                HotKeyCenter.shared.fire(id: id)
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}
