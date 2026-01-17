//
// MenuBarView.swift
// FlowWhispr
//
// Menu bar dropdown content using standard .menu style.
//

import FlowWhispr
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack {
            Button(appState.isRecording ? "Stop Recording (🌐)" : "Start Recording (🌐)") {
                appState.toggleRecording()
            }
            .disabled(!appState.isConfigured)

            Divider()

            Text("App: \(appState.currentApp)")
                .font(.caption)

            Text("Mode: \(appState.currentMode.displayName)")
                .font(.caption)

            Menu("Change Mode") {
                ForEach(WritingMode.allCases, id: \.self) { mode in
                    Button {
                        appState.setMode(mode)
                    } label: {
                        HStack {
                            Text(mode.displayName)
                            if mode == appState.currentMode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Button("Open FlowWhispr") {
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppState())
}
