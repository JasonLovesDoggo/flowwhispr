//
// SettingsView.swift
// FlowWhispr
//
// Settings window.
//

import FlowWhispr
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            APISettingsView()
                .tabItem {
                    Label("API", systemImage: "key")
                }

            KeyboardSettingsView()
                .tabItem {
                    Label("Keyboard", systemImage: "keyboard")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 360)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("playSounds") private var playSounds = true
    @AppStorage("defaultMode") private var defaultMode = 1

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Play sounds", isOn: $playSounds)
            } header: {
                Label("Startup", systemImage: "power")
            }

            Section {
                Picker("Default mode", selection: $defaultMode) {
                    ForEach(WritingMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(Int(mode.rawValue))
                    }
                }
                .pickerStyle(.segmented)

                if let mode = WritingMode(rawValue: UInt8(defaultMode)) {
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(FW.textSecondary)
                }
            } header: {
                Label("Writing Mode", systemImage: "text.quote")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding()
    }
}

// MARK: - API Settings

struct APISettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var showOpenAIKey = false
    @State private var showAnthropicKey = false

    var body: some View {
        Form {
            Section {
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
            } header: {
                Label("OpenAI (Whisper)", systemImage: "waveform")
            } footer: {
                Text("Required for transcription")
                    .font(.caption)
                    .foregroundStyle(FW.textTertiary)
            }

            Section {
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
            } header: {
                Label("Anthropic (Claude)", systemImage: "sparkles")
            } footer: {
                Text("Optional, for enhanced text processing")
                    .font(.caption)
                    .foregroundStyle(FW.textTertiary)
            }

            Section {
                HStack(spacing: FW.spacing8) {
                    Circle()
                        .fill(appState.isConfigured ? FW.success : FW.warning)
                        .frame(width: 10, height: 10)

                    Text(appState.isConfigured ? "API configured" : "API key required")
                        .foregroundStyle(appState.isConfigured ? FW.success : FW.warning)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding()
    }
}

// MARK: - Keyboard Settings

struct KeyboardSettingsView: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Toggle recording", name: .toggleRecording)
            } header: {
                Label("Recording", systemImage: "mic")
            } footer: {
                Text("Press to start recording. Press again to stop and transcribe.")
                    .font(.caption)
                    .foregroundStyle(FW.textTertiary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding()
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        VStack(spacing: FW.spacing24) {
            Spacer()

            // logo
            ZStack {
                Circle()
                    .fill(FW.accentGradient)
                    .frame(width: 80, height: 80)

                Image(systemName: "waveform")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: FW.spacing4) {
                Text("FlowWhispr")
                    .font(.title.weight(.semibold))

                Text("v1.0.0")
                    .font(FW.fontMonoSmall)
                    .foregroundStyle(FW.textTertiary)
            }

            Text("Voice dictation powered by AI")
                .font(.subheadline)
                .foregroundStyle(FW.textSecondary)

            Spacer()

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

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
