//
// RecordingIndicatorWindow.swift
// FlowWispr
//
// Lightweight, non-activating recording indicator shown while recording or processing.
//

import AppKit
import SwiftUI

@MainActor
final class RecordingIndicatorWindow {
    private let window: NSPanel

    init(appState: AppState) {
        let view = RecordingIndicatorView()
            .environmentObject(appState)
        let hosting = NSHostingController(rootView: view)

        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.borderless, .nonactivatingPanel]
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.setFrame(NSRect(x: 0, y: 0, width: 200, height: 32), display: false)

        self.window = panel
        positionWindow()
    }

    func show() {
        positionWindow()
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let size = window.frame.size
        let padding: CGFloat = 12
        let origin = CGPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.minY + padding
        )
        window.setFrameOrigin(origin)
    }
}

private struct RecordingIndicatorView: View {
    @EnvironmentObject var appState: AppState
    @State private var pulse = false

    var body: some View {
        HStack(spacing: FW.spacing8) {
            Circle()
                .fill(appState.isRecording ? FW.recording : FW.accent)
                .frame(width: 8, height: 8)
                .opacity(pulse ? 0.6 : 1.0)

            if appState.isRecording {
                CompactWaveformView(isRecording: true)
                    .frame(width: 90, height: 18)
                    .transition(.opacity)
            }

            if appState.isProcessing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .tint(.white.opacity(0.9))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, FW.spacing12)
        .padding(.vertical, FW.spacing6)
        .background {
            Capsule()
                .fill(Color.black.opacity(0.55))
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.isRecording)
        .animation(.easeInOut(duration: 0.2), value: appState.isProcessing)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
