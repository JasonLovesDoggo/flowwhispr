//
// AppState.swift
// FlowWispr
//
// Observable state for the FlowWispr app.
//

import AppKit
import Carbon.HIToolbox
import Combine
import FlowWispr
import Foundation

/// Main app state observable
@MainActor
final class AppState: ObservableObject {
    /// The FlowWispr engine
    let engine: FlowWispr

    /// Current recording state
    @Published var isRecording = false
    @Published var isProcessing = false

    /// Last transcribed text
    @Published var lastTranscription: String?

    /// Current writing mode
    @Published var currentMode: WritingMode = .casual

    /// Current app name
    @Published var currentApp: String = "Unknown"

    /// Current app category
    @Published var currentCategory: AppCategory = .unknown

    /// Recent transcriptions
    @Published var history: [TranscriptionSummary] = []
    @Published var retryableHistoryId: String?

    /// API key configured
    @Published var isConfigured = false

    /// Current selected tab
    @Published var selectedTab: AppTab = .record

    /// Current recording hotkey
    @Published var hotkey: Hotkey
    @Published var isCapturingHotkey = false
    @Published var isAccessibilityEnabled = false
    @Published var isOnboardingComplete: Bool

    /// Error message to display
    @Published var errorMessage: String?

    /// Recording duration in milliseconds
    @Published var recordingDuration: UInt64 = 0

    /// Workspace observer for app changes
    private var workspaceObserver: NSObjectProtocol?
    private var recordingTimer: Timer?
    private var globeKeyHandler: GlobeKeyHandler?
    private var hotkeyCaptureMonitor: Any?
    private var appActiveObserver: NSObjectProtocol?
    private var appInactiveObserver: NSObjectProtocol?
    private var mediaPauseState = MediaPauseState()
    private var recordingIndicator: RecordingIndicatorWindow?
    private var targetApplication: NSRunningApplication?

    private static let onboardingKey = "onboardingComplete"

    init() {
        self.engine = FlowWispr()
        self.isConfigured = engine.isConfigured
        self.hotkey = Hotkey.load()
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        self.isAccessibilityEnabled = GlobeKeyHandler.isAccessibilityAuthorized()

        setupGlobeKey()
        setupLifecycleObserver()
        setupWorkspaceObserver()
        updateCurrentApp()
        refreshHistory()
    }

    func cleanup() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
        if let observer = appActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            appActiveObserver = nil
        }
        if let observer = appInactiveObserver {
            NotificationCenter.default.removeObserver(observer)
            appInactiveObserver = nil
        }
        recordingTimer?.invalidate()
        recordingTimer = nil
        endHotkeyCapture()
        recordingIndicator?.hide()
    }

    // MARK: - Globe Key

    private func setupGlobeKey() {
        globeKeyHandler = GlobeKeyHandler(hotkey: hotkey) { [weak self] trigger in
            Task { @MainActor in
                self?.handleHotkeyTrigger(trigger)
            }
        }
    }

    private func handleHotkeyTrigger(_ trigger: GlobeKeyHandler.Trigger) {
        switch trigger {
        case .pressed:
            if !isRecording {
                startRecording()
            }
        case .released:
            if isRecording {
                stopRecording()
            }
        case .toggle:
            toggleRecording()
        }
    }

    private func setupLifecycleObserver() {
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAccessibilityStatus()
            }
        }

        appInactiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateRecordingIndicatorVisibility()
            }
        }
    }

    func setHotkey(_ hotkey: Hotkey) {
        self.hotkey = hotkey
        hotkey.save()
        globeKeyHandler?.updateHotkey(hotkey)
    }

    func requestAccessibilityPermission() {
        let started = globeKeyHandler?.startListening(prompt: true) ?? false
        if started {
            isAccessibilityEnabled = true
        } else {
            refreshAccessibilityStatus()
        }
    }

    func refreshAccessibilityStatus() {
        let enabled = GlobeKeyHandler.isAccessibilityAuthorized()
        isAccessibilityEnabled = enabled
        if enabled {
            _ = globeKeyHandler?.startListening(prompt: false)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func refreshHistory(limit: Int = 50) {
        history = engine.recentTranscriptions(limit: limit)
        if let latest = history.first, latest.status == .failed {
            retryableHistoryId = latest.id
        } else {
            retryableHistoryId = nil
        }
    }

    func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
    }

    func beginHotkeyCapture() {
        guard hotkeyCaptureMonitor == nil else { return }
        isCapturingHotkey = true

        hotkeyCaptureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            Task { @MainActor in
                self?.handleHotkeyCapture(event)
            }
            return nil
        }
    }

    func endHotkeyCapture() {
        if let monitor = hotkeyCaptureMonitor {
            NSEvent.removeMonitor(monitor)
            hotkeyCaptureMonitor = nil
        }
        isCapturingHotkey = false
    }

    private func handleHotkeyCapture(_ event: NSEvent) {
        let modifiers = Hotkey.Modifiers.from(nsFlags: event.modifierFlags)
        if event.keyCode == UInt16(kVK_Escape), modifiers.isEmpty {
            endHotkeyCapture()
            return
        }

        setHotkey(Hotkey.from(event: event))
        endHotkeyCapture()
    }

    // MARK: - Workspace Observer

    private func setupWorkspaceObserver() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            let appName = app.localizedName ?? "Unknown"
            let bundleId = app.bundleIdentifier

            Task { @MainActor in
                self?.handleAppActivation(appName: appName, bundleId: bundleId)
            }
        }
    }

    private func handleAppActivation(appName: String, bundleId: String?) {
        currentApp = appName
        let suggestedMode = engine.setActiveApp(name: appName, bundleId: bundleId)
        currentCategory = engine.currentAppCategory

        if let styleSuggestion = engine.styleSuggestion {
            currentMode = styleSuggestion
        } else {
            currentMode = suggestedMode
        }
    }

    private func updateCurrentApp() {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appName = frontApp.localizedName ?? "Unknown"
            let bundleId = frontApp.bundleIdentifier

            currentApp = appName
            let suggestedMode = engine.setActiveApp(name: appName, bundleId: bundleId)
            currentCategory = engine.currentAppCategory
            currentMode = suggestedMode
        }
    }

    // MARK: - Recording

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        guard engine.isConfigured else {
            errorMessage = "Please configure your API key in Settings"
            return
        }

        targetApplication = NSWorkspace.shared.frontmostApplication
        pauseMediaPlayback()
        if engine.startRecording() {
            isRecording = true
            isProcessing = false
            updateRecordingIndicatorVisibility()
            recordingDuration = 0

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    if let self = self, self.isRecording {
                        self.recordingDuration += 100
                    }
                }
            }
        } else {
            errorMessage = engine.lastError ?? "Failed to start recording"
            resumeMediaPlayback()
        }
    }

    func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        let duration = engine.stopRecording()
        isRecording = false
        resumeMediaPlayback()

        if duration > 0 {
            setProcessing(true)
            transcribe()
        } else {
            updateRecordingIndicatorVisibility()
        }
    }

    private func transcribe() {
        Task {
            let result = engine.transcribe(appName: currentApp)
            await MainActor.run {
                if let text = result {
                    lastTranscription = text
                    errorMessage = nil
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    activateTargetAppIfNeeded()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        self?.pasteText()
                        self?.finishProcessing()
                    }
                    refreshHistory()
                } else {
                    errorMessage = engine.lastError ?? "Transcription failed"
                    refreshHistory()
                    finishProcessing()
                }
            }
        }
    }

    func retryLastTranscription() {
        setProcessing(true)
        Task {
            let result = engine.retryLastTranscription(appName: currentApp)
            await MainActor.run {
                if let text = result {
                    lastTranscription = text
                    errorMessage = nil
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    activateTargetAppIfNeeded()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        self?.pasteText()
                        self?.finishProcessing()
                    }
                    refreshHistory()
                } else {
                    errorMessage = engine.lastError ?? "Retry failed"
                    refreshHistory()
                    finishProcessing()
                }
            }
        }
    }

    private func pasteText() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func activateTargetAppIfNeeded() {
        guard let app = targetApplication else { return }
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }
        if #available(macOS 14, *) {
            _ = app.activate(options: [.activateAllWindows])
        } else {
            _ = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
    }

    private func ensureRecordingIndicator() {
        if recordingIndicator == nil {
            recordingIndicator = RecordingIndicatorWindow(appState: self)
        }
    }

    private func setProcessing(_ processing: Bool) {
        isProcessing = processing
        updateRecordingIndicatorVisibility()
    }

    private func finishProcessing() {
        setProcessing(false)
    }

    private func updateRecordingIndicatorVisibility() {
        if isRecording || isProcessing {
            ensureRecordingIndicator()
            recordingIndicator?.show()
        } else {
            recordingIndicator?.hide()
        }
    }

    // MARK: - Settings

    func setApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if engine.setApiKey(trimmed) {
            isConfigured = engine.isConfigured
            errorMessage = nil
        } else {
            isConfigured = engine.isConfigured
            errorMessage = engine.lastError ?? "Failed to set API key"
        }
    }

    func setMode(_ mode: WritingMode) {
        if engine.setMode(mode, for: currentApp) {
            currentMode = mode
        }
    }

    // MARK: - Shortcuts

    func addShortcut(trigger: String, replacement: String) -> Bool {
        return engine.addShortcut(trigger: trigger, replacement: replacement)
    }

    func removeShortcut(trigger: String) -> Bool {
        return engine.removeShortcut(trigger: trigger)
    }

    // MARK: - Stats

    var totalTranscriptions: Int {
        (engine.stats?["total_transcriptions"] as? Int) ?? 0
    }

    var totalMinutes: Int {
        let ms = (engine.stats?["total_duration_ms"] as? Int) ?? 0
        return ms / 60000
    }

    private struct MediaPauseState {
        var musicWasPlaying = false
        var spotifyWasPlaying = false
    }

    private func pauseMediaPlayback() {
        mediaPauseState.musicWasPlaying = pauseIfPlaying(app: "Music")
        mediaPauseState.spotifyWasPlaying = pauseIfPlaying(app: "Spotify")
    }

    private func resumeMediaPlayback() {
        if mediaPauseState.musicWasPlaying {
            resumeApp(app: "Music")
        }
        if mediaPauseState.spotifyWasPlaying {
            resumeApp(app: "Spotify")
        }
        mediaPauseState = MediaPauseState()
    }

    private func pauseIfPlaying(app: String) -> Bool {
        let script = """
        tell application \"\(app)\"
            if it is running then
                if player state is playing then
                    pause
                    return \"playing\"
                end if
            end if
        end tell
        return \"\"
        """

        return runAppleScript(script) == "playing"
    }

    private func resumeApp(app: String) {
        let script = """
        tell application \"\(app)\"
            if it is running then
                play
            end if
        end tell
        """

        _ = runAppleScript(script)
    }

    private func runAppleScript(_ script: String) -> String? {
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        if error != nil {
            return nil
        }
        return result.stringValue
    }
}
