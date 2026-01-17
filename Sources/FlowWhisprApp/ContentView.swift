//
// ContentView.swift
// FlowWhispr
//
// Main navigation container with segmented tabs for Record, Shortcuts, Settings.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .record

    enum Tab: String, CaseIterable {
        case record = "Record"
        case shortcuts = "Shortcuts"
        case settings = "Settings"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Group {
                switch selectedTab {
                case .record:
                    RecordView()
                case .shortcuts:
                    ShortcutsContentView()
                case .settings:
                    SettingsContentView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: WindowSize.minWidth, minHeight: WindowSize.minHeight)
        .background(FW.surfacePrimary)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Logo
            HStack(spacing: FW.spacing8) {
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundStyle(FW.accentGradient)
                Text("FlowWhispr")
                    .font(.title2.weight(.semibold))
            }

            Spacer()

            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)

            Spacer()

            // Status indicator
            statusIndicator
        }
        .padding(.horizontal, FW.spacing24)
        .padding(.vertical, FW.spacing16)
    }

    private var statusIndicator: some View {
        HStack(spacing: FW.spacing8) {
            Circle()
                .fill(appState.isConfigured ? FW.success : FW.warning)
                .frame(width: 8, height: 8)

            Text(appState.isConfigured ? "Ready" : "Setup required")
                .font(.caption)
                .foregroundStyle(FW.textSecondary)
        }
        .padding(.horizontal, FW.spacing12)
        .padding(.vertical, FW.spacing4)
        .background {
            Capsule()
                .fill((appState.isConfigured ? FW.success : FW.warning).opacity(0.1))
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
