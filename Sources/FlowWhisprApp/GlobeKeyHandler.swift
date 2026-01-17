//
// GlobeKeyHandler.swift
// FlowWhispr
//
// Captures the globe key (🌐) using IOHIDManager.
// The globe key is Apple's vendor-specific HID at usage page 0xFF, usage 0x03.
// Requires "Input Monitoring" permission in System Settings > Privacy & Security.
//

import Foundation
import IOKit
import IOKit.hid

final class GlobeKeyHandler {
    private var manager: IOHIDManager?
    private var onGlobeKeyPressed: (() -> Void)?

    init(onGlobeKeyPressed: @escaping () -> Void) {
        self.onGlobeKeyPressed = onGlobeKeyPressed
        setupHIDManager()
    }

    private func setupHIDManager() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let manager else { return }

        // Match all keyboards
        let matchingDict: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
        ]
        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)

        // Register callback using the C function pointer wrapper
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, globeKeyHIDCallback, context)

        // Schedule with run loop
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    fileprivate func handleHIDValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let intValue = IOHIDValueGetIntegerValue(value)

        // Apple Globe Key: usage page 0xFF (AppleVendor Top Case), usage 0x03 (KeyboardFn)
        // intValue == 1 means key press, 0 means release
        if usagePage == 0xFF && usage == 0x03 && intValue == 1 {
            DispatchQueue.main.async { [weak self] in
                self?.onGlobeKeyPressed?()
            }
        }
    }

    deinit {
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
    }
}

// C callback function for IOHIDManager
private func globeKeyHIDCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    value: IOHIDValue
) {
    guard let context else { return }
    let handler = Unmanaged<GlobeKeyHandler>.fromOpaque(context).takeUnretainedValue()
    handler.handleHIDValue(value)
}
