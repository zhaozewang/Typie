import Carbon
import Cocoa

final class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private var callback: (() -> Void)?

    private static let hotkeyID = EventHotKeyID(
        signature: OSType(0x5451_4C00),  // "TQL\0"
        id: 1
    )

    func register(callback: @escaping () -> Void) {
        self.callback = callback
        registerWithCurrentConfig()
    }

    func reregister() {
        unregister()
        if let cb = callback {
            register(callback: cb)
        }
    }

    private func registerWithCurrentConfig() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.callback?()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        let keyCode = AppConfig.hotkeyKeyCode
        let modifiers = AppConfig.hotkeyModifiers
        let hotkeyIDVar = Self.hotkeyID

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyIDVar,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        AppLogger.hotkey.info("Global hotkey registered: \(AppConfig.hotkeyDisplayString)")
    }

    func unregister() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        AppLogger.hotkey.info("Global hotkey unregistered")
    }

    deinit {
        unregister()
    }
}
