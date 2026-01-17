//
// FlowWisprApp.swift
// FlowWispr
//
// Main app entry point with single-window architecture.
//

import SwiftUI

@main
struct FlowWisprApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    
    private var menuBarIcon: NSImage? {
        guard let iconURL = Bundle.module.url(forResource: "flow_wispr_menubar_18x18", withExtension: "png"),
              let icon = NSImage(contentsOf: iconURL) else {
            return nil
        }
        icon.isTemplate = true
        return icon
    }

    var body: some Scene {
        // main window
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: WindowSize.width, height: WindowSize.height)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // menu bar
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            if let icon = menuBarIcon {
                Image(nsImage: icon)
                    .foregroundStyle(appState.isRecording ? .red : .primary)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
