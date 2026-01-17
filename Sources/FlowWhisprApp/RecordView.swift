//
// RecordView.swift
// FlowWhispr
//
// Main recording view with waveform visualization and transcription output.
//

import FlowWhispr
import SwiftUI

struct RecordView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // hero waveform + record button
            heroSection
                .padding(.horizontal, FW.spacing24)
                .padding(.top, FW.spacing32)

            // context bar
            contextBar
                .padding(.horizontal, FW.spacing24)
                .padding(.top, FW.spacing24)

            // output area
            if let text = appState.lastTranscription {
                outputSection(text)
                    .padding(.horizontal, FW.spacing24)
                    .padding(.top, FW.spacing16)
            }

            Spacer()

            // footer
            footer
                .padding(FW.spacing16)
        }
        .background(FW.surfacePrimary)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: FW.spacing24) {
            // waveform visualization
            WaveformView(isRecording: appState.isRecording)
                .frame(height: 80)
                .padding(.horizontal, FW.spacing16)

            // big record button
            Button(action: { appState.toggleRecording() }) {
                HStack(spacing: FW.spacing12) {
                    Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))

                    if appState.isRecording {
                        Text(formatDuration(appState.recordingDuration))
                            .font(FW.fontMonoLarge)
                    } else {
                        Text("Record")
                            .font(.headline)
                    }
                }
                .frame(minWidth: 160)
            }
            .buttonStyle(FWPrimaryButtonStyle(isRecording: appState.isRecording))
            .disabled(!appState.isConfigured)

            // shortcut hint
            Text("🌐 Globe key")
                .font(FW.fontMonoSmall)
                .foregroundStyle(FW.textTertiary)
        }
        .padding(FW.spacing24)
        .fwCard()
    }

    // MARK: - Context Bar

    private var contextBar: some View {
        HStack(spacing: FW.spacing16) {
            // current app
            HStack(spacing: FW.spacing8) {
                Image(systemName: "app.fill")
                    .font(.caption)
                    .foregroundStyle(FW.accent)

                Text(appState.currentApp)
                    .font(.subheadline)
                    .foregroundStyle(FW.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

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
                HStack(spacing: FW.spacing4) {
                    Text(appState.currentMode.displayName)
                        .font(.subheadline.weight(.medium))

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(FW.accent)
                .padding(.horizontal, FW.spacing12)
                .padding(.vertical, FW.spacing4)
                .background {
                    RoundedRectangle(cornerRadius: FW.radiusSmall)
                        .fill(FW.accent.opacity(0.1))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(FW.spacing12)
        .background {
            RoundedRectangle(cornerRadius: FW.radiusSmall)
                .fill(FW.surfaceElevated.opacity(0.5))
        }
    }

    // MARK: - Output Section

    private func outputSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: FW.spacing8) {
            HStack {
                Text("Output")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(FW.textTertiary)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    HStack(spacing: FW.spacing4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.caption)
                }
                .buttonStyle(FWSecondaryButtonStyle())
            }

            Text(text)
                .font(.body)
                .foregroundStyle(FW.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FW.spacing12)
                .background {
                    RoundedRectangle(cornerRadius: FW.radiusSmall)
                        .fill(FW.surfaceElevated.opacity(0.5))
                        .overlay {
                            RoundedRectangle(cornerRadius: FW.radiusSmall)
                                .strokeBorder(FW.accent.opacity(0.2), lineWidth: 1)
                        }
                }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()

            HStack(spacing: FW.spacing16) {
                statItem(value: "\(appState.totalTranscriptions)", label: "transcriptions")

                if appState.totalMinutes > 0 {
                    statItem(value: "\(appState.totalMinutes)", label: "minutes")
                }
            }
        }
    }

    private func statItem(value: String, label: String) -> some View {
        HStack(spacing: FW.spacing4) {
            Text(value)
                .font(FW.fontMonoSmall.weight(.medium))
                .foregroundStyle(FW.textPrimary)

            Text(label)
                .font(.caption)
                .foregroundStyle(FW.textTertiary)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ ms: UInt64) -> String {
        let seconds = ms / 1000
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    RecordView()
        .environmentObject(AppState())
}
