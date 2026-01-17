//
// FlowWhisprApp.swift
// FlowWhispr
//
// Main app entry point.
//

import SwiftUI

@main
struct FlowWhisprApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        // main window
        WindowGroup {
            MainView()
                .environmentObject(appState)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 540, height: 520)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // menu bar
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.isRecording ? "mic.fill" : "mic")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(appState.isRecording ? .red : .primary)
        }
        .menuBarExtraStyle(.window)

        // settings
        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        // shortcuts window
        Window("Shortcuts", id: "shortcuts") {
            ShortcutsView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)

        // recording overlay
        Window("Recording", id: "recording-overlay") {
            RecordingOverlay()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}
