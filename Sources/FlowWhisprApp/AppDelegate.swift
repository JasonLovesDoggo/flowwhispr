//
// AppDelegate.swift
// FlowWhispr
//
// Handles window lifecycle: ensures window opens on launch and handles reopen.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            WindowManager.openMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        WindowManager.openMainWindow()
        return true
    }
}
