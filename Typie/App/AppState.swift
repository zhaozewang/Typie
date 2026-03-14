import SwiftUI
import AppKit

@MainActor
final class AppState: ObservableObject {
    @Published var status: AppStatus = .idle
    @Published var lastTranscription: String = ""

    let hotkeyManager = HotkeyManager()
    let audioRecorder = AudioRecorder()
    let whisperService = WhisperTranscriptionService()
    let textInsertionService = TextInsertionService()

    private var hasSetup = false
    private let recordingOverlay = RecordingOverlay()
    private let correctionPopup = CorrectionPopup()

    func setup() {
        guard !hasSetup else { return }
        hasSetup = true
        hotkeyManager.register { [weak self] in
            Task { @MainActor in
                self?.hotkeyPressed()
            }
        }
        audioRecorder.onSilenceDetected = { [weak self] in
            Task { @MainActor in
                self?.stopAndTranscribe()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .hotkeyChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.hotkeyManager.reregister()
        }
        checkPermissions()
    }

    func hotkeyPressed() {
        switch status {
        case .idle:
            startRecording()
        case .recording:
            stopAndTranscribe()
        case .transcribing:
            AppLogger.general.info("Hotkey ignored: transcription in progress")
        case .error:
            status = .idle
        }
    }

    private func startRecording() {
        guard PermissionsService.hasMicrophonePermission else {
            Task {
                let granted = await PermissionsService.requestMicrophonePermission()
                if !granted { PermissionsService.openMicrophoneSettings() }
            }
            return
        }

        do {
            let _ = try audioRecorder.startRecording()
            status = .recording
            recordingOverlay.show()
            NSSound(named: "Tink")?.play()
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func stopAndTranscribe() {
        recordingOverlay.hide()
        guard let url = audioRecorder.stopRecording() else {
            status = .error("No recording to stop")
            return
        }

        NSSound(named: "Pop")?.play()
        status = .transcribing

        Task {
            do {
                let text = try await whisperService.transcribe(audioFileURL: url)
                lastTranscription = text
                try textInsertionService.insertText(text)
                status = .idle

                // Show correction popup so user can fix errors
                correctionPopup.show(originalText: text) { [weak self] original, corrected in
                    guard let self = self else { return }
                    // Learn the correction
                    self.whisperService.corrections.addReplacement(wrong: original, right: corrected)
                    // Also add corrected words as favorites for prompt conditioning
                    // Replace the text in the text field
                    self.textInsertionService.replaceStreamedText(
                        currentStreamedText: original,
                        with: corrected
                    )
                    self.lastTranscription = corrected
                    AppLogger.general.info("Learned correction: '\(original)' → '\(corrected)'")
                }
            } catch {
                status = .error(error.localizedDescription)
            }

            FileUtils.deleteIfExists(url)
        }
    }

    private func checkPermissions() {
        if !PermissionsService.hasMicrophonePermission {
            Task { _ = await PermissionsService.requestMicrophonePermission() }
        }
        if !PermissionsService.hasAccessibilityPermission {
            PermissionsService.requestAccessibilityPermission()
        }
    }

    func quit() {
        hotkeyManager.unregister()
        NSApplication.shared.terminate(nil)
    }
}
