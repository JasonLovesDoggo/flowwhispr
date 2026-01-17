//
// SettingsView.swift
// FlowWhispr
//
// Settings content view with sections for API, general settings, and about.
//

import FlowWhispr
import SwiftUI

struct SettingsContentView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: FW.spacing24) {
                APISettingsSection()
                Divider()
                GeneralSettingsSection()
                Divider()
                InputMonitoringSection()
                Divider()
                AboutSection()
            }
            .padding(FW.spacing24)
        }
    }
}

// MARK: - API Settings

struct APISettingsSection: View {
    @EnvironmentObject var appState: AppState
    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var showOpenAIKey = false
    @State private var showAnthropicKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: FW.spacing16) {
            Label("API Keys", systemImage: "key")
                .font(.headline)

            // OpenAI
            VStack(alignment: .leading, spacing: FW.spacing8) {
                Text("OpenAI (Whisper)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(FW.textPrimary)

                HStack {
                    Group {
                        if showOpenAIKey {
                            TextField("sk-...", text: $openAIKey)
                        } else {
                            SecureField("sk-...", text: $openAIKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(FW.fontMonoSmall)

                    Button {
                        showOpenAIKey.toggle()
                    } label: {
                        Image(systemName: showOpenAIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)

                    Button("Save") {
                        appState.setApiKey(openAIKey)
                        openAIKey = ""
                    }
                    .buttonStyle(FWSecondaryButtonStyle())
                    .disabled(openAIKey.isEmpty)
                }

                Text("Required for transcription")
                    .font(.caption)
                    .foregroundStyle(FW.textTertiary)
            }

            // Anthropic
            VStack(alignment: .leading, spacing: FW.spacing8) {
                Text("Anthropic (Claude)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(FW.textPrimary)

                HStack {
                    Group {
                        if showAnthropicKey {
                            TextField("sk-ant-...", text: $anthropicKey)
                        } else {
                            SecureField("sk-ant-...", text: $anthropicKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(FW.fontMonoSmall)

                    Button {
                        showAnthropicKey.toggle()
                    } label: {
                        Image(systemName: showAnthropicKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)

                    Button("Save") {
                        appState.setAnthropicKey(anthropicKey)
                        anthropicKey = ""
                    }
                    .buttonStyle(FWSecondaryButtonStyle())
                    .disabled(anthropicKey.isEmpty)
                }

                Text("Optional, for enhanced text processing")
                    .font(.caption)
                    .foregroundStyle(FW.textTertiary)
            }

            // Status
            HStack(spacing: FW.spacing8) {
                Circle()
                    .fill(appState.isConfigured ? FW.success : FW.warning)
                    .frame(width: 10, height: 10)

                Text(appState.isConfigured ? "API configured" : "API key required")
                    .foregroundStyle(appState.isConfigured ? FW.success : FW.warning)
            }
            .padding(.top, FW.spacing8)
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsSection: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("playSounds") private var playSounds = true
    @AppStorage("defaultMode") private var defaultMode = 1

    var body: some View {
        VStack(alignment: .leading, spacing: FW.spacing16) {
            Label("General", systemImage: "gear")
                .font(.headline)

            VStack(alignment: .leading, spacing: FW.spacing12) {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Play sounds", isOn: $playSounds)
            }

            VStack(alignment: .leading, spacing: FW.spacing8) {
                Text("Default writing mode")
                    .font(.subheadline.weight(.medium))

                Picker("", selection: $defaultMode) {
                    ForEach(WritingMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(Int(mode.rawValue))
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if let mode = WritingMode(rawValue: UInt8(defaultMode)) {
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(FW.textTertiary)
                }
            }
        }
    }
}

// MARK: - Input Monitoring

struct InputMonitoringSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FW.spacing16) {
            Label("Keyboard", systemImage: "keyboard")
                .font(.headline)

            VStack(alignment: .leading, spacing: FW.spacing8) {
                HStack(spacing: FW.spacing8) {
                    Text("🌐")
                        .font(.title2)
                    Text("Globe key toggles recording")
                        .font(.subheadline.weight(.medium))
                }

                Text("Press the globe key (🌐) on your keyboard to start/stop recording. This requires Input Monitoring permission.")
                    .font(.caption)
                    .foregroundStyle(FW.textSecondary)

                Button("Open Privacy Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(FWSecondaryButtonStyle())
                .padding(.top, FW.spacing4)
            }
        }
    }
}

// MARK: - About

struct AboutSection: View {
    var body: some View {
        VStack(spacing: FW.spacing16) {
            // logo
            ZStack {
                Circle()
                    .fill(FW.accentGradient)
                    .frame(width: 60, height: 60)

                Image(systemName: "waveform")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: FW.spacing4) {
                Text("FlowWhispr")
                    .font(.title3.weight(.semibold))

                Text("v1.0.0")
                    .font(FW.fontMonoSmall)
                    .foregroundStyle(FW.textTertiary)
            }

            Text("Voice dictation powered by AI")
                .font(.subheadline)
                .foregroundStyle(FW.textSecondary)

            HStack(spacing: FW.spacing24) {
                Link(destination: URL(string: "https://flowwhispr.app")!) {
                    HStack(spacing: FW.spacing4) {
                        Image(systemName: "globe")
                        Text("Website")
                    }
                    .font(.caption)
                    .foregroundStyle(FW.accent)
                }

                Link(destination: URL(string: "https://github.com/json/flowwhispr")!) {
                    HStack(spacing: FW.spacing4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                        Text("GitHub")
                    }
                    .font(.caption)
                    .foregroundStyle(FW.accent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FW.spacing16)
    }
}

#Preview {
    SettingsContentView()
        .environmentObject(AppState())
}
