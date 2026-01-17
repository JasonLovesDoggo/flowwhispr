//
// RecordingOverlay.swift
// FlowWhispr
//
// Floating overlay shown during recording.
//

import SwiftUI

struct RecordingOverlay: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: FW.spacing16) {
            // waveform
            WaveformView(isRecording: appState.isRecording, barCount: 24)
                .frame(height: 40)

            HStack(spacing: FW.spacing16) {
                // duration
                VStack(alignment: .leading, spacing: FW.spacing2) {
                    Text("Recording")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(FW.textSecondary)

                    Text(formatDuration(appState.recordingDuration))
                        .font(FW.fontMonoLarge)
                        .foregroundStyle(FW.recording)
                }

                Spacer()

                // stop button
                Button(action: { appState.stopRecording() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle()
                                .fill(FW.recordingGradient)
                        }
                }
                .buttonStyle(.plain)
            }

            // hint
            Text("⌥ Space to stop")
                .font(FW.fontMonoSmall)
                .foregroundStyle(FW.textTertiary)
        }
        .padding(FW.spacing16)
        .frame(width: 260)
        .background {
            RoundedRectangle(cornerRadius: FW.radiusLarge)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: FW.radiusLarge)
                        .strokeBorder(FW.recording.opacity(0.3), lineWidth: 1)
                }
                .shadow(color: FW.recording.opacity(0.2), radius: 16, y: 4)
        }
    }

    private func formatDuration(_ ms: UInt64) -> String {
        let seconds = ms / 1000
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    RecordingOverlay()
        .environmentObject(AppState())
        .padding()
}
