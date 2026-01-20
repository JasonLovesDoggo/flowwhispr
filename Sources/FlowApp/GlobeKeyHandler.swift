//
// GlobeKeyHandler.swift
// Flow
//
// Captures the recording hotkey (Fn key or custom) using a CGEvent tap.
// Fn key and modifier-only use press-and-hold for recording.
// Custom hotkeys (key + modifiers) use toggle mode.
// All hotkeys are captured via CGEventTap (no Carbon dependency).
// Requires "Accessibility" permission in System Settings > Privacy & Security.
//

import ApplicationServices
import Foundation

final class GlobeKeyHandler {
    enum Trigger {
        case pressed
        case released
        case toggle
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var onHotkeyTriggered: (@Sendable (Trigger) -> Void)?
    private var hotkey: Hotkey

    private var isFunctionDown = false
    private var functionUsedAsModifier = false
    private var hasFiredFnPressed = false
    private var fnPressTime: Date?

    private var isModifierDown = false
    private var modifierUsedAsModifier = false
    private var hasFiredModifierPressed = false
    private var modifierPressTime: Date?

    // Stale state detection: if a key appears held for longer than this, assume we missed the release
    private let staleKeyTimeout: TimeInterval = 5.0

    // Periodic health check to ensure the event tap stays enabled
    private var tapHealthTimer: Timer?

    // Resilience: track tap restarts to avoid infinite loops
    private var tapRestartCount = 0
    private let maxTapRestarts = 5
    private var lastTapRestartTime: Date?

    init(hotkey: Hotkey, onHotkeyTriggered: @escaping @Sendable (Trigger) -> Void) {
        self.hotkey = hotkey
        self.onHotkeyTriggered = onHotkeyTriggered
        startListening(prompt: false)
    }

    deinit {
        tapHealthTimer?.invalidate()
        tapHealthTimer = nil
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }

    func updateHotkey(_ hotkey: Hotkey) {
        self.hotkey = hotkey

        // Reset state for Fn/modifier-only modes
        isFunctionDown = false
        functionUsedAsModifier = false
        hasFiredFnPressed = false
        fnPressTime = nil
        isModifierDown = false
        modifierUsedAsModifier = false
        hasFiredModifierPressed = false
        modifierPressTime = nil
    }

    @discardableResult
    func startListening(prompt: Bool) -> Bool {
        guard accessibilityTrusted(prompt: prompt) else { return false }
        guard eventTap == nil else { return true }

        // Event tap for all hotkey types: Fn key, modifier-only, and custom key combos
        // Listen to flagsChanged (modifiers) and keyDown (for custom key+modifier combos)
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: globeKeyEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        self.eventTap = eventTap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        tapRestartCount = 0

        // Start periodic health check to ensure the tap stays enabled
        // System can disable taps if they're slow or unresponsive
        // Using 0.5s interval for faster recovery when tap gets disabled
        tapHealthTimer?.invalidate()
        tapHealthTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.ensureTapEnabled()
        }

        return true
    }

    private func ensureTapEnabled() {
        guard let eventTap else { return }
        if !CGEvent.tapIsEnabled(tap: eventTap) {
            #if DEBUG
                print("[HOTKEY] Tap was disabled, re-enabling")
            #endif
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    static func isAccessibilityAuthorized() -> Bool {
        accessibilityTrusted(prompt: false)
    }

    private static func accessibilityTrusted(prompt: Bool) -> Bool {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func accessibilityTrusted(prompt: Bool) -> Bool {
        Self.accessibilityTrusted(prompt: prompt)
    }

    fileprivate func handleEvent(type: CGEventType, event: CGEvent) {
        // Handle tap being disabled by system (timeout or user input flood)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            restartTapIfNeeded()
            return
        }

        switch hotkey.kind {
        case .globe:
            switch type {
            case .flagsChanged:
                handleFunctionFlagChange(event)
            case .keyDown:
                // Only mark as used if Fn is ACTUALLY pressed in this event's flags.
                // System events like Cmd+V don't have Fn flag, so they shouldn't
                // incorrectly mark Fn as "used as a combo key".
                if isFunctionDown, event.flags.contains(.maskSecondaryFn) {
                    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
                    // kVK_Function = 63
                    if keycode != 63 {
                        #if DEBUG
                            print("[HOTKEY] keyDown with Fn held, marking as used")
                        #endif
                        functionUsedAsModifier = true
                    }
                }
            default:
                break
            }
        case let .modifierOnly(modifier):
            switch type {
            case .flagsChanged:
                handleModifierFlagChange(event, modifier: modifier)
            case .keyDown:
                // Only mark as used if the modifier is ACTUALLY pressed in this event.
                // System events like Cmd+V don't have our modifier flag, so they shouldn't
                // incorrectly mark the modifier as "used as a combo key".
                if isModifierDown, event.flags.contains(modifier.cgFlag) {
                    #if DEBUG
                        print("[HOTKEY] keyDown with modifier held, marking as used")
                    #endif
                    modifierUsedAsModifier = true
                }
            default:
                break
            }
        case let .custom(keyCode, modifiers, _):
            // Handle custom key+modifier combos via CGEventTap (no Carbon needed)
            if type == .keyDown {
                handleCustomKeyDown(event, expectedKeyCode: keyCode, expectedModifiers: modifiers)
            }
        }
    }

    private func handleCustomKeyDown(_ event: CGEvent, expectedKeyCode: Int, expectedModifiers: Hotkey.Modifiers) {
        let pressedKeyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let pressedModifiers = Hotkey.Modifiers.from(cgFlags: event.flags)

        if pressedKeyCode == expectedKeyCode, pressedModifiers == expectedModifiers {
            fireHotkey(.toggle)
        }
    }

    private func restartTapIfNeeded() {
        guard let eventTap else { return }

        // Rate limit restarts to avoid infinite loops
        let now = Date()
        if let lastRestart = lastTapRestartTime, now.timeIntervalSince(lastRestart) < 1.0 {
            tapRestartCount += 1
            if tapRestartCount >= maxTapRestarts {
                // Too many restarts, give up (user may need to check accessibility permissions)
                return
            }
        } else {
            tapRestartCount = 0
        }
        lastTapRestartTime = now

        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func handleFunctionFlagChange(_ event: CGEvent) {
        let hasFn = event.flags.contains(.maskSecondaryFn)

        #if DEBUG
            print("[HOTKEY] Fn flagsChanged: hasFn=\(hasFn), isFunctionDown=\(isFunctionDown)")
        #endif

        // Detect and recover from stale state: if we think the key is held but it's been
        // too long, we probably missed the release event (tap was disabled, run loop blocked, etc.)
        if isFunctionDown, let pressTime = fnPressTime,
           Date().timeIntervalSince(pressTime) > staleKeyTimeout
        {
            #if DEBUG
                print("[HOTKEY] Fn stale state detected, resetting")
            #endif
            isFunctionDown = false
            hasFiredFnPressed = false
            functionUsedAsModifier = false
            fnPressTime = nil
        }

        guard hasFn != isFunctionDown else { return }

        if hasFn {
            isFunctionDown = true
            fnPressTime = Date()
            functionUsedAsModifier = false
            hasFiredFnPressed = true
            // Fire immediately - no delay for instant response
            fireHotkey(.pressed)
            return
        }

        guard isFunctionDown else { return }
        isFunctionDown = false
        fnPressTime = nil

        if hasFiredFnPressed, !functionUsedAsModifier {
            fireHotkey(.released)
        }
        hasFiredFnPressed = false
    }

    private func handleModifierFlagChange(_ event: CGEvent, modifier: Hotkey.ModifierKey) {
        let hasModifier = event.flags.contains(modifier.cgFlag)

        #if DEBUG
            print("[HOTKEY] Modifier flagsChanged: hasModifier=\(hasModifier), isModifierDown=\(isModifierDown)")
        #endif

        // Detect and recover from stale state: if we think the key is held but it's been
        // too long, we probably missed the release event (tap was disabled, run loop blocked, etc.)
        if isModifierDown, let pressTime = modifierPressTime,
           Date().timeIntervalSince(pressTime) > staleKeyTimeout
        {
            #if DEBUG
                print("[HOTKEY] Modifier stale state detected, resetting")
            #endif
            isModifierDown = false
            hasFiredModifierPressed = false
            modifierUsedAsModifier = false
            modifierPressTime = nil
        }

        // Check if other modifiers are also pressed (means it's being used as a combo)
        let otherModifiersPressed = hasOtherModifiers(event.flags, excluding: modifier)

        guard hasModifier != isModifierDown else {
            // If the modifier is still down but other modifiers changed, mark as used
            if isModifierDown, otherModifiersPressed {
                modifierUsedAsModifier = true
            }
            return
        }

        if hasModifier {
            // Modifier just pressed
            if otherModifiersPressed {
                // Already in a combo, don't trigger
                return
            }
            isModifierDown = true
            modifierPressTime = Date()
            modifierUsedAsModifier = false
            hasFiredModifierPressed = true
            // Fire immediately - no delay for instant response
            fireHotkey(.pressed)
            return
        }

        // Modifier released
        guard isModifierDown else { return }
        isModifierDown = false
        modifierPressTime = nil

        if hasFiredModifierPressed, !modifierUsedAsModifier {
            fireHotkey(.released)
        }
        hasFiredModifierPressed = false
    }

    private func hasOtherModifiers(_ flags: CGEventFlags, excluding: Hotkey.ModifierKey) -> Bool {
        let allModifiers: [(CGEventFlags, Hotkey.ModifierKey)] = [
            (.maskAlternate, .option),
            (.maskShift, .shift),
            (.maskControl, .control),
            (.maskCommand, .command),
        ]
        for (flag, key) in allModifiers {
            if key != excluding && flags.contains(flag) {
                return true
            }
        }
        return false
    }

    private func fireHotkey(_ trigger: Trigger) {
        onHotkeyTriggered?(trigger)
    }
}

private func globeKeyEventTapCallback(
    proxy _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }

    let handler = Unmanaged<GlobeKeyHandler>.fromOpaque(refcon).takeUnretainedValue()
    handler.handleEvent(type: type, event: event)
    return Unmanaged.passUnretained(event)
}
