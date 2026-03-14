import SwiftUI
import ServiceManagement
import Carbon

struct SettingsView: View {
    @State private var whisperPath: String = AppConfig.whisperBinaryPath
    @State private var selectedModelId: String = AppConfig.selectedModelId
    @State private var hasMic: Bool = PermissionsService.hasMicrophonePermission
    @State private var hasAccessibility: Bool = PermissionsService.hasAccessibilityPermission
    @StateObject private var downloadService = ModelDownloadService()

    // Language
    @State private var language: String = AppConfig.language

    // Silence
    @State private var autoStopEnabled: Bool = AppConfig.autoStopEnabled
    @State private var silenceTimeout: Double = AppConfig.silenceTimeoutSeconds
    @State private var silenceThreshold: Float = AppConfig.silenceThresholdDb

    // VAD
    @State private var vadEnabled: Bool = AppConfig.vadEnabled

    // Prompt conditioning
    @State private var usePromptConditioning: Bool = AppConfig.usePromptConditioning
    @State private var customVocabulary: String = AppConfig.customVocabulary

    // Launch at login
    @State private var launchAtLogin: Bool = AppConfig.launchAtLogin

    // Hotkey
    @State private var isCapturingHotkey: Bool = false
    @State private var hotkeyDisplay: String = AppConfig.hotkeyDisplayString
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    var body: some View {
        Form {
            Section("Model") {
                ForEach(WhisperModel.all) { model in
                    ModelRow(
                        model: model,
                        isSelected: selectedModelId == model.id,
                        downloadService: downloadService,
                        onSelect: {
                            selectedModelId = model.id
                            AppConfig.selectedModelId = model.id
                        }
                    )
                }
            }

            Section("Transcription") {
                Picker("Language", selection: $language) {
                    ForEach(AppConfig.supportedLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .onChange(of: language) { newValue in
                    AppConfig.language = newValue
                }

                Toggle("Enable VAD (trim silence for speed)", isOn: $vadEnabled)
                    .onChange(of: vadEnabled) { newValue in
                        AppConfig.vadEnabled = newValue
                    }

                if vadEnabled {
                    let vadExists = FileUtils.fileExists(AppConfig.resolvedVadModelPath)
                    HStack {
                        Label(
                            vadExists ? "VAD model found" : "VAD model not found",
                            systemImage: vadExists ? "checkmark.circle.fill" : "xmark.circle"
                        )
                        .font(.caption)
                        .foregroundColor(vadExists ? .green : .red)
                        Spacer()
                        if !vadExists {
                            Button("Download VAD") {
                                Task {
                                    try? await downloadService.download(WhisperModel.vadModel)
                                }
                            }
                            .font(.caption)
                        }
                    }
                }

            }

            Section("Learning") {
                Toggle("Learn from my speaking style", isOn: $usePromptConditioning)
                    .onChange(of: usePromptConditioning) { newValue in
                        AppConfig.usePromptConditioning = newValue
                    }

                if usePromptConditioning {
                    Text("Feeds your recent transcriptions to whisper as context, improving recognition of your vocabulary and patterns over time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom vocabulary")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $customVocabulary)
                        .font(.body)
                        .frame(height: 60)
                        .border(Color.secondary.opacity(0.3))
                        .onChange(of: customVocabulary) { newValue in
                            AppConfig.customVocabulary = newValue
                        }
                    Text("Names, terms, or phrases whisper often gets wrong. One per line or comma-separated.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Button("Clear transcription history") {
                    TranscriptionHistory().clear()
                }
                .foregroundColor(.red)
                .font(.caption)
            }

            Section("Corrections & Favorites") {
                CorrectionListView()
            }

            Section("Recording") {
                Toggle("Auto-stop on silence", isOn: $autoStopEnabled)
                    .onChange(of: autoStopEnabled) { newValue in
                        AppConfig.autoStopEnabled = newValue
                    }

                if autoStopEnabled {
                    HStack {
                        Text("Silence timeout")
                        Slider(value: $silenceTimeout, in: 1...10, step: 0.5)
                            .onChange(of: silenceTimeout) { newValue in
                                AppConfig.silenceTimeoutSeconds = newValue
                            }
                        Text("\(silenceTimeout, specifier: "%.1f")s")
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }

            Section("Hotkey") {
                HStack {
                    Text("Current: \(hotkeyDisplay)")
                    Spacer()
                    Button(isCapturingHotkey ? "Press any key..." : "Change Hotkey") {
                        if isCapturingHotkey {
                            stopCapturingHotkey()
                        } else {
                            startCapturingHotkey()
                        }
                    }
                    .foregroundColor(isCapturingHotkey ? .orange : .accentColor)
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        AppConfig.launchAtLogin = newValue
                        updateLaunchAtLogin(newValue)
                    }

                TextField("whisper.cpp binary path", text: $whisperPath)
                    .onSubmit { AppConfig.whisperBinaryPath = whisperPath }
            }

            Section("Permissions") {
                HStack {
                    Label(
                        hasMic ? "Microphone: Granted" : "Microphone: Not Granted",
                        systemImage: hasMic ? "checkmark.circle.fill" : "xmark.circle"
                    )
                    .foregroundColor(hasMic ? .green : .red)
                    Spacer()
                    if !hasMic {
                        Button("Open Settings") { PermissionsService.openMicrophoneSettings() }
                    }
                }

                HStack {
                    Label(
                        hasAccessibility ? "Accessibility: Granted" : "Accessibility: Not Granted",
                        systemImage: hasAccessibility ? "checkmark.circle.fill" : "xmark.circle"
                    )
                    .foregroundColor(hasAccessibility ? .green : .red)
                    Spacer()
                    Button("Open Settings") { PermissionsService.openAccessibilitySettings() }
                }

                if !hasAccessibility {
                    Text("Accessibility status is cached per launch. Restart the app after granting.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button("Refresh") {
                    hasMic = PermissionsService.hasMicrophonePermission
                    hasAccessibility = PermissionsService.hasAccessibilityPermission
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 750)
        .onDisappear {
            AppConfig.whisperBinaryPath = whisperPath
            stopCapturingHotkey()
        }
    }

    // MARK: - Hotkey Capture

    private func handleCapturedKey(_ event: NSEvent) {
        let keyCode = UInt32(event.keyCode)
        var modifiers: UInt32 = 0
        if event.modifierFlags.contains(.control) { modifiers |= UInt32(controlKey) }
        if event.modifierFlags.contains(.option) { modifiers |= UInt32(optionKey) }
        if event.modifierFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.command) { modifiers |= UInt32(cmdKey) }

        // Require at least one modifier
        guard modifiers != 0 else { return }

        AppConfig.hotkeyKeyCode = keyCode
        AppConfig.hotkeyModifiers = modifiers
        hotkeyDisplay = AppConfig.hotkeyDisplayString
        stopCapturingHotkey()

        NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
    }

    private func startCapturingHotkey() {
        isCapturingHotkey = true

        // Local monitor for events in our own windows
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleCapturedKey(event)
            return nil
        }

        // Global monitor for events when another app is focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            self.handleCapturedKey(event)
        }
    }

    private func stopCapturingHotkey() {
        isCapturingHotkey = false
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }
    }

    // MARK: - Launch at Login

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            AppLogger.general.error("Launch at login failed: \(error.localizedDescription)")
        }
    }

    static func open() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 750),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Typie Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        _settingsWindow = window
    }
}

private var _settingsWindow: NSWindow?


struct CorrectionListView: View {
    @State private var data = CorrectionDictionary().load()
    @State private var newWord: String = ""
    @State private var newWrong: String = ""
    @State private var newRight: String = ""
    private let dict = CorrectionDictionary()

    var body: some View {
        // Favorite words
        VStack(alignment: .leading, spacing: 4) {
            Text("Favorite words")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(data.favoriteWords, id: \.self) { word in
                HStack {
                    Text(word).font(.caption)
                    Spacer()
                    Button("Remove") {
                        dict.removeFavoriteWord(word)
                        data = dict.load()
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            }

            HStack {
                TextField("Add word...", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit { addWord() }
                Button("Add") { addWord() }
                    .font(.caption)
                    .disabled(newWord.isEmpty)
            }
        }

        Divider()

        // Auto-corrections
        VStack(alignment: .leading, spacing: 4) {
            Text("Auto-corrections")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(data.replacements) { r in
                HStack {
                    Text(r.wrong).font(.caption).foregroundColor(.red)
                    Text("→").font(.caption)
                    Text(r.right).font(.caption).foregroundColor(.green)
                    Spacer()
                    Button("Remove") {
                        dict.removeReplacement(id: r.id)
                        data = dict.load()
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            }

            HStack(spacing: 4) {
                TextField("Wrong", text: $newWrong)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                Text("→").font(.caption)
                TextField("Right", text: $newRight)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit { addCorrection() }
                Button("Add") { addCorrection() }
                    .font(.caption)
                    .disabled(newWrong.isEmpty || newRight.isEmpty)
            }

            Text("Corrections are applied automatically after each transcription. Edit the popup after dictation to teach new corrections.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func addWord() {
        guard !newWord.isEmpty else { return }
        dict.addFavoriteWord(newWord)
        newWord = ""
        data = dict.load()
    }

    private func addCorrection() {
        guard !newWrong.isEmpty, !newRight.isEmpty else { return }
        dict.addReplacement(wrong: newWrong, right: newRight)
        newWrong = ""
        newRight = ""
        data = dict.load()
    }
}

struct ModelRow: View {
    let model: WhisperModel
    let isSelected: Bool
    @ObservedObject var downloadService: ModelDownloadService
    let onSelect: () -> Void

    private var isDownloadingThis: Bool {
        downloadService.downloadingModelId == model.id
    }

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .onTapGesture {
                    if model.isDownloaded { onSelect() }
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(model.displayName).fontWeight(.medium)
                    Text(model.size).foregroundColor(.secondary).font(.caption)
                }
                Text(model.speedNote)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isDownloadingThis {
                VStack(alignment: .trailing, spacing: 2) {
                    ProgressView(value: downloadService.progress)
                        .frame(width: 100)
                    Text("\(Int(downloadService.progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Button("Cancel") { downloadService.cancel() }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .font(.caption)
            } else if model.isDownloaded {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Button("Download") {
                    Task {
                        do {
                            try await downloadService.download(model)
                            onSelect()
                        } catch {
                            AppLogger.general.error("Download failed: \(error.localizedDescription)")
                        }
                    }
                }
                .disabled(downloadService.isDownloading)
            }
        }
        .padding(.vertical, 2)
    }
}
