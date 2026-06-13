import Carbon
import CoreGraphics
import Foundation

@MainActor
final class PushToTalkHotkeyController {
    enum Hotkey: String, CaseIterable, Identifiable {
        case fnKey
        case controlOptionSpace
        case controlOptionD
        case controlOptionReturn
        case controlShiftSpace
        case commandShiftSpace
        case f13
        case f14
        case f15
        case f16
        case f17
        case f18
        case f19

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .fnKey:
                return "Fn / Globe"
            case .controlOptionSpace:
                return "Control + Option + Space"
            case .controlOptionD:
                return "Control + Option + D"
            case .controlOptionReturn:
                return "Control + Option + Return"
            case .controlShiftSpace:
                return "Control + Shift + Space"
            case .commandShiftSpace:
                return "Command + Shift + Space"
            case .f13:
                return "F13"
            case .f14:
                return "F14"
            case .f15:
                return "F15"
            case .f16:
                return "F16"
            case .f17:
                return "F17"
            case .f18:
                return "F18"
            case .f19:
                return "F19"
            }
        }

        var keyCode: UInt32 {
            switch self {
            case .fnKey:
                return UInt32(kVK_Function)
            case .controlOptionSpace, .controlShiftSpace, .commandShiftSpace:
                return UInt32(kVK_Space)
            case .controlOptionD:
                return UInt32(kVK_ANSI_D)
            case .controlOptionReturn:
                return UInt32(kVK_Return)
            case .f13:
                return UInt32(kVK_F13)
            case .f14:
                return UInt32(kVK_F14)
            case .f15:
                return UInt32(kVK_F15)
            case .f16:
                return UInt32(kVK_F16)
            case .f17:
                return UInt32(kVK_F17)
            case .f18:
                return UInt32(kVK_F18)
            case .f19:
                return UInt32(kVK_F19)
            }
        }

        var modifiers: UInt32 {
            switch self {
            case .fnKey:
                return 0
            case .controlOptionSpace, .controlOptionD, .controlOptionReturn:
                return UInt32(controlKey | optionKey)
            case .controlShiftSpace:
                return UInt32(controlKey | shiftKey)
            case .commandShiftSpace:
                return UInt32(cmdKey | shiftKey)
            case .f13, .f14, .f15, .f16, .f17, .f18, .f19:
                return 0
            }
        }
    }

    enum HotkeyError: LocalizedError {
        case registrationFailed(Hotkey, OSStatus)
        case eventTapFailed(Hotkey)
        case eventHandlerFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case let .registrationFailed(hotkey, status):
                return "Could not register \(hotkey.displayName). macOS returned \(status)."
            case let .eventTapFailed(hotkey):
                return "Could not listen for \(hotkey.displayName). Enable Input Monitoring and Accessibility."
            case let .eventHandlerFailed(status):
                return "Could not install the hotkey listener. macOS returned \(status)."
            }
        }
    }

    private static let hotkeySignature = OSType(
        UInt32(UInt8(ascii: "V")) << 24 |
        UInt32(UInt8(ascii: "T")) << 16 |
        UInt32(UInt8(ascii: "M")) << 8 |
        UInt32(UInt8(ascii: "i"))
    )

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var fnEventTap: CFMachPort?
    private var fnEventTapSource: CFRunLoopSource?
    private var isPressed = false
    private(set) var activeHotkey: Hotkey?

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    var isEnabled: Bool {
        hotkeyRef != nil || fnEventTap != nil
    }

    func start(hotkey: Hotkey) throws {
        guard !isEnabled else {
            return
        }

        if hotkey == .fnKey {
            try startFnEventTap(hotkey: hotkey)
            return
        }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            eventTypes.count,
            &eventTypes,
            refcon,
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            throw HotkeyError.eventHandlerFailed(handlerStatus)
        }

        let hotkeyID = EventHotKeyID(
            signature: Self.hotkeySignature,
            id: 1
        )

        let registrationStatus = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        guard registrationStatus == noErr else {
            if let eventHandlerRef {
                RemoveEventHandler(eventHandlerRef)
                self.eventHandlerRef = nil
            }
            throw HotkeyError.registrationFailed(hotkey, registrationStatus)
        }

        activeHotkey = hotkey
    }

    func stop() {
        if let fnEventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), fnEventTapSource, .commonModes)
        }

        if let fnEventTap {
            CFMachPortInvalidate(fnEventTap)
        }

        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }

        fnEventTap = nil
        fnEventTapSource = nil
        hotkeyRef = nil
        eventHandlerRef = nil
        isPressed = false
        activeHotkey = nil
    }

    fileprivate func handle(eventKind: UInt32) {
        switch Int(eventKind) {
        case kEventHotKeyPressed:
            guard !isPressed else {
                return
            }
            isPressed = true
            onPress?()
        case kEventHotKeyReleased:
            guard isPressed else {
                return
            }
            isPressed = false
            onRelease?()
        default:
            return
        }
    }

    fileprivate func handleFnFlagsChanged(flags: CGEventFlags) {
        let isFnDown = flags.contains(.maskSecondaryFn)
        if isFnDown {
            guard !isPressed else {
                return
            }
            isPressed = true
            onPress?()
        } else {
            guard isPressed else {
                return
            }
            isPressed = false
            onRelease?()
        }
    }

    fileprivate func enableFnEventTapIfNeeded() {
        if let fnEventTap {
            CGEvent.tapEnable(tap: fnEventTap, enable: true)
        }
    }

    private func startFnEventTap(hotkey: Hotkey) throws {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: fnKeyEventHandler,
            userInfo: refcon
        ) else {
            throw HotkeyError.eventTapFailed(hotkey)
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            throw HotkeyError.eventTapFailed(hotkey)
        }

        fnEventTap = eventTap
        fnEventTapSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        activeHotkey = hotkey
    }
}

private func hotkeyEventHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else {
        return noErr
    }

    let controller = Unmanaged<PushToTalkHotkeyController>
        .fromOpaque(userData)
        .takeUnretainedValue()
    let eventKind = GetEventKind(event)

    DispatchQueue.main.async {
        controller.handle(eventKind: eventKind)
    }

    return noErr
}

private func fnKeyEventHandler(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<PushToTalkHotkeyController>
        .fromOpaque(userInfo)
        .takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        DispatchQueue.main.async {
            controller.enableFnEventTapIfNeeded()
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .flagsChanged else {
        return Unmanaged.passUnretained(event)
    }

    let flags = event.flags
    DispatchQueue.main.async {
        controller.handleFnFlagsChanged(flags: flags)
    }

    return Unmanaged.passUnretained(event)
}
