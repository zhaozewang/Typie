import AVFoundation
import Foundation

/// Records audio via AVAudioEngine, saves to WAV, and periodically runs
/// whisper.cpp on snapshots for real-time transcription updates.
final class StreamingRecognitionService: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var audioFileURL: URL?
    private var pcmBuffers: [AVAudioPCMBuffer] = []
    private var snapshotTimer: Timer?
    private var whisperService = WhisperTranscriptionService()
    private var isTranscribingSnapshot = false
    private var totalSamples: Int = 0
    private var inputSampleRate: Double = 48000

    /// Called on main queue with updated full transcription text
    var onTextUpdated: ((String) -> Void)?

    /// How often to run whisper on a snapshot (seconds)
    var snapshotInterval: TimeInterval = 4.0

    /// Minimum seconds of audio before first snapshot (longer = better first result)
    var firstSnapshotDelay: TimeInterval = 5.0
    private var recordingStartTime: Date?

    private let bufferLock = NSLock()

    func start(audioSaveURL: URL) throws {
        audioFileURL = audioSaveURL
        pcmBuffers = []
        totalSamples = 0
        recordingStartTime = Date()

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        inputSampleRate = inputFormat.sampleRate

        AppLogger.audio.info("Audio input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch")

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            // Keep a copy of the buffer
            guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return }
            copy.frameLength = buffer.frameLength
            if let src = buffer.floatChannelData, let dst = copy.floatChannelData {
                for ch in 0..<Int(buffer.format.channelCount) {
                    memcpy(dst[ch], src[ch], Int(buffer.frameLength) * MemoryLayout<Float>.size)
                }
            }
            self.bufferLock.lock()
            self.pcmBuffers.append(copy)
            self.totalSamples += Int(buffer.frameLength)
            self.bufferLock.unlock()
        }

        engine.prepare()
        try engine.start()
        self.audioEngine = engine

        startSnapshotTimer()
        AppLogger.audio.info("Streaming recording started (format: \(inputFormat))")
    }

    func stop() -> URL? {
        snapshotTimer?.invalidate()
        snapshotTimer = nil

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        // Write final WAV file
        guard let url = audioFileURL else { return nil }
        writeBuffersToWAV(url: url)

        AppLogger.audio.info("Streaming recording stopped, wrote \(self.totalSamples) samples")
        return url
    }

    var isRunning: Bool {
        audioEngine?.isRunning ?? false
    }

    // MARK: - Write buffers to 16kHz mono WAV for whisper.cpp

    private func writeBuffersToWAV(url: URL) {
        bufferLock.lock()
        let buffers = pcmBuffers
        bufferLock.unlock()

        guard !buffers.isEmpty, let firstFormat = buffers.first?.format else { return }

        // Collect all float samples, mix to mono
        var monoSamples: [Float] = []
        let channelCount = Int(firstFormat.channelCount)

        for buf in buffers {
            guard let data = buf.floatChannelData else { continue }
            let frameCount = Int(buf.frameLength)
            for i in 0..<frameCount {
                var sample: Float = 0
                for ch in 0..<channelCount {
                    sample += data[ch][i]
                }
                sample /= Float(channelCount)
                monoSamples.append(sample)
            }
        }

        // Resample to 16kHz
        let inputRate = firstFormat.sampleRate
        let outputRate = 16000.0
        let ratio = outputRate / inputRate
        let outputCount = Int(Double(monoSamples.count) * ratio)
        var resampled = [Int16](repeating: 0, count: outputCount)

        for i in 0..<outputCount {
            let srcIdx = Double(i) / ratio
            let idx0 = Int(srcIdx)
            let frac = Float(srcIdx - Double(idx0))
            let s0 = idx0 < monoSamples.count ? monoSamples[idx0] : 0
            let s1 = (idx0 + 1) < monoSamples.count ? monoSamples[idx0 + 1] : s0
            let sample = s0 + frac * (s1 - s0)
            // Convert float [-1, 1] to Int16
            let clamped = max(-1.0, min(1.0, sample))
            resampled[i] = Int16(clamped * 32767)
        }

        // Write WAV file
        writeWAV(samples: resampled, sampleRate: 16000, url: url)
    }

    private func writeSnapshotWAV(url: URL) {
        // Same as writeBuffersToWAV but takes a snapshot of current buffers
        writeBuffersToWAV(url: url)
    }

    private func writeWAV(samples: [Int16], sampleRate: Int, url: URL) {
        let dataSize = samples.count * 2
        let fileSize = 36 + dataSize

        var header = Data()
        // RIFF header
        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)
        // fmt chunk
        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })  // chunk size
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })   // PCM
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })   // mono
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Array($0) }) // byte rate
        header.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })   // block align
        header.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })  // bits per sample
        // data chunk
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })

        // Sample data
        var sampleData = Data(count: dataSize)
        sampleData.withUnsafeMutableBytes { ptr in
            let dst = ptr.bindMemory(to: Int16.self)
            for i in 0..<samples.count {
                dst[i] = samples[i].littleEndian
            }
        }

        var fileData = header
        fileData.append(sampleData)
        try? fileData.write(to: url)
    }

    // MARK: - Snapshot Timer

    private func startSnapshotTimer() {
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: snapshotInterval, repeats: true) { [weak self] _ in
            self?.transcribeSnapshot()
        }
    }

    private func transcribeSnapshot() {
        guard !isTranscribingSnapshot else { return }

        // Wait for the first snapshot delay before attempting any transcription
        if let start = recordingStartTime, Date().timeIntervalSince(start) < firstSnapshotDelay {
            return
        }

        // Need at least ~2 seconds of audio at the input sample rate
        let minSamples = Int(inputSampleRate * 2.0)
        guard totalSamples > minSamples else {
            return
        }

        isTranscribingSnapshot = true

        let snapshotURL = FileUtils.tempAudioFileURL()

        // Write current buffers to snapshot file
        bufferLock.lock()
        let buffers = pcmBuffers
        bufferLock.unlock()

        guard !buffers.isEmpty, let firstFormat = buffers.first?.format else {
            isTranscribingSnapshot = false
            return
        }

        // Build mono + resample
        var monoSamples: [Float] = []
        let channelCount = Int(firstFormat.channelCount)
        for buf in buffers {
            guard let data = buf.floatChannelData else { continue }
            let frameCount = Int(buf.frameLength)
            for i in 0..<frameCount {
                var sample: Float = 0
                for ch in 0..<channelCount {
                    sample += data[ch][i]
                }
                sample /= Float(channelCount)
                monoSamples.append(sample)
            }
        }

        let inputRate = firstFormat.sampleRate
        let outputRate = 16000.0
        let ratio = outputRate / inputRate
        let outputCount = Int(Double(monoSamples.count) * ratio)
        var resampled = [Int16](repeating: 0, count: outputCount)
        for i in 0..<outputCount {
            let srcIdx = Double(i) / ratio
            let idx0 = Int(srcIdx)
            let frac = Float(srcIdx - Double(idx0))
            let s0 = idx0 < monoSamples.count ? monoSamples[idx0] : 0
            let s1 = (idx0 + 1) < monoSamples.count ? monoSamples[idx0 + 1] : s0
            let sample = s0 + frac * (s1 - s0)
            let clamped = max(-1.0, min(1.0, sample))
            resampled[i] = Int16(clamped * 32767)
        }

        writeWAV(samples: resampled, sampleRate: 16000, url: snapshotURL)

        AppLogger.transcription.info("Snapshot: \(resampled.count) samples (\(Double(resampled.count)/16000.0)s), running whisper...")

        Task {
            defer {
                FileUtils.deleteIfExists(snapshotURL)
                self.isTranscribingSnapshot = false
            }
            do {
                let text = try await whisperService.transcribe(audioFileURL: snapshotURL)
                AppLogger.transcription.info("Snapshot result: \(text.prefix(60))")
                DispatchQueue.main.async {
                    self.onTextUpdated?(text)
                }
            } catch {
                AppLogger.transcription.error("Snapshot transcription failed: \(error.localizedDescription)")
            }
        }
    }

    enum StreamingError: LocalizedError {
        case audioFormatError

        var errorDescription: String? {
            switch self {
            case .audioFormatError:
                return "Failed to set up audio format for streaming"
            }
        }
    }
}
