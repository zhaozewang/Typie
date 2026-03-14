import AVFoundation
import Foundation

final class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private(set) var recordingURL: URL?
    private var silenceTimer: Timer?
    private var silenceStart: Date?

    var onSilenceDetected: (() -> Void)?

    func startRecording() throws -> URL {
        let url = FileUtils.tempAudioFileURL()

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw RecorderError.failedToStart
        }

        self.audioRecorder = recorder
        self.recordingURL = url
        self.silenceStart = nil

        if AppConfig.autoStopEnabled {
            startSilenceDetection()
        }

        AppLogger.audio.info("Recording started: \(url.path)")
        return url
    }

    func stopRecording() -> URL? {
        stopSilenceDetection()
        guard let recorder = audioRecorder, recorder.isRecording else {
            return nil
        }
        recorder.stop()
        let url = recordingURL
        audioRecorder = nil
        AppLogger.audio.info("Recording stopped")
        return url
    }

    var isRecording: Bool {
        audioRecorder?.isRecording ?? false
    }

    // MARK: - Silence Detection

    private func startSilenceDetection() {
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkSilence()
        }
    }

    private func stopSilenceDetection() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        silenceStart = nil
    }

    private func checkSilence() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        let threshold = AppConfig.silenceThresholdDb

        if power < threshold {
            if silenceStart == nil {
                silenceStart = Date()
            } else if let start = silenceStart,
                      Date().timeIntervalSince(start) >= AppConfig.silenceTimeoutSeconds {
                AppLogger.audio.info("Silence detected, auto-stopping")
                onSilenceDetected?()
            }
        } else {
            silenceStart = nil
        }
    }

    enum RecorderError: LocalizedError {
        case failedToStart
        var errorDescription: String? {
            switch self {
            case .failedToStart: return "Failed to start audio recording"
            }
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            AppLogger.audio.error("Recording finished unsuccessfully")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            AppLogger.audio.error("Recording encode error: \(error.localizedDescription)")
        }
    }
}
