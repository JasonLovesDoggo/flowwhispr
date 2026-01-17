//
// MenuBarView.swift
// FlowWhispr
//
// Menu bar dropdown content.
//

import FlowWhispr
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // header with mini waveform
            VStack(spacing: FW.spacing8) {
                HStack {
                    Text("FlowWhispr")
                        .font(.headline)
                        .foregroundStyle(FW.textPrimary)

                    Spacer()

                    Circle()
                        .fill(appState.isConfigured ? FW.success : FW.warning)
                        .frame(width: 8, height: 8)
                }

                CompactWaveformView(isRecording: appState.isRecording)
            }
            .padding(FW.spacing16)

            Divider()

            // recording button
            Button(action: { appState.toggleRecording() }) {
                HStack {
                    Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                        .foregroundStyle(appState.isRecording ? FW.recording : FW.accent)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.isRecording ? "Stop Recording" : "Start Recording")
                            .foregroundStyle(FW.textPrimary)

                        if appState.isRecording {
                            Text(formatDuration(appState.recordingDuration))
                                .font(FW.fontMonoSmall)
                                .foregroundStyle(FW.recording)
                        }
                    }

                    Spacer()

                    Text("⌥ Space")
                        .font(FW.fontMonoSmall)
                        .foregroundStyle(FW.textTertiary)
                }
                .padding(.horizontal, FW.spacing16)
                .padding(.vertical, FW.spacing12)
                .background(appState.isRecording ? FW.recording.opacity(0.1) : Color.clear)
            }
            .buttonStyle(.plain)
            .disabled(!appState.isConfigured)

            Divider()

            // context info
            VStack(alignment: .leading, spacing: FW.spacing4) {
                HStack(spacing: FW.spacing4) {
                    Text("App")
                        .font(.caption)
                        .foregroundStyle(FW.textTertiary)
                        .frame(width: 40, alignment: .leading)

                    Text(appState.currentApp)
                        .font(.caption)
                        .foregroundStyle(FW.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: FW.spacing4) {
                    Text("Mode")
                        .font(.caption)
                        .foregroundStyle(FW.textTertiary)
                        .frame(width: 40, alignment: .leading)

                    Text(appState.currentMode.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(FW.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FW.spacing16)

            Divider()

            // mode picker
            Menu {
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
            } label: {
                HStack {
                    Text("Change Mode")
                        .foregroundStyle(FW.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(FW.textTertiary)
                }
                .padding(.horizontal, FW.spacing16)
                .padding(.vertical, FW.spacing8)
            }
            .buttonStyle(.plain)

            Divider()

            // actions
            VStack(spacing: 0) {
                menuButton("Open FlowWhispr", icon: "macwindow") {
                    NSApp.activate(ignoringOtherApps: true)
                }

                menuButton("Shortcuts", icon: "text.badge.plus") {
                    openWindow(id: "shortcuts")
                }

                menuButton("Settings", icon: "gear") {
                    openSettings()
                }
            }

            Divider()

            menuButton("Quit", icon: "power") {
                NSApp.terminate(nil)
            }
        }
        .frame(width: 280)
    }

    private func menuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(FW.textSecondary)
                    .frame(width: 20)

                Text(title)
                    .foregroundStyle(FW.textPrimary)

                Spacer()
            }
            .padding(.horizontal, FW.spacing16)
            .padding(.vertical, FW.spacing8)
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ ms: UInt64) -> String {
        let seconds = ms / 1000
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppState())
}
