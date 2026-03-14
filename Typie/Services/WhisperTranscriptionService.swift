import Foundation

final class WhisperTranscriptionService {
    let history = TranscriptionHistory()
    let corrections = CorrectionDictionary()

    enum TranscriptionError: LocalizedError {
        case binaryNotFound(String)
        case modelNotFound(String)
        case processFailed(String)
        case emptyResult

        var errorDescription: String? {
            switch self {
            case .binaryNotFound(let path):
                return "whisper.cpp binary not found at: \(path)"
            case .modelNotFound(let path):
                return "Whisper model not found at: \(path)"
            case .processFailed(let msg):
                return "Transcription failed: \(msg)"
            case .emptyResult:
                return "Transcription returned empty result"
            }
        }
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        let binaryPath = AppConfig.resolvedWhisperBinaryPath
        let modelPath = AppConfig.resolvedModelPath

        guard FileUtils.fileExists(binaryPath) else {
            throw TranscriptionError.binaryNotFound(binaryPath)
        }
        guard FileUtils.fileExists(modelPath) else {
            throw TranscriptionError.modelNotFound(modelPath)
        }

        AppLogger.transcription.info("Starting transcription of \(audioFileURL.lastPathComponent)")

        var args = [
            "-m", modelPath,
            "-f", audioFileURL.path,
            "-l", AppConfig.language,
            "-np",
            "--no-timestamps",
            "-t", "8",
            "-bo", "1",
            "-bs", "1",
            "--flash-attn",
        ]

        // Prompt conditioning: feed recent transcriptions + custom vocabulary
        if AppConfig.usePromptConditioning {
            let prompt = buildPrompt()
            if !prompt.isEmpty {
                args += ["--prompt", prompt]
            }
        }

        // VAD
        if AppConfig.vadEnabled {
            let vadPath = AppConfig.resolvedVadModelPath
            if FileUtils.fileExists(vadPath) {
                args += ["--vad-model", vadPath]
            }
        }

        let result = try await ProcessRunner.run(
            executablePath: binaryPath,
            arguments: args
        )

        if result.exitCode != 0 {
            AppLogger.transcription.error("whisper.cpp stderr: \(result.stderr)")
            throw TranscriptionError.processFailed(
                result.stderr.isEmpty ? "Exit code \(result.exitCode)" : result.stderr
            )
        }

        // Strip known whisper special tokens
        var text = result.stdout
        for token in ["[EOT]", "[SOT]", "[NOT]", "[BEG]", "[BLANK_AUDIO]",
                       "[_EOT_]", "[_SOT_]", "[_BEG_]", "[_TT_"] {
            text = text.replacingOccurrences(of: token, with: "")
        }
        text = text.replacingOccurrences(
            of: "\\[\\d{2}:\\d{2}:\\d{2}\\.\\d{3}\\s*-->\\s*\\d{2}:\\d{2}:\\d{2}\\.\\d{3}\\]",
            with: "", options: .regularExpression
        )
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Apply learned corrections
        text = corrections.applyCorrections(text)

        if text.isEmpty {
            throw TranscriptionError.emptyResult
        }

        // Save corrected text to history for future prompt conditioning
        history.add(text)

        AppLogger.transcription.info("Transcription complete: \(text.prefix(50))...")
        return text
    }

    private func buildPrompt() -> String {
        var parts: [String] = []

        // Favorite words
        let favorites = corrections.favoriteWordsPrompt()
        if !favorites.isEmpty {
            parts.append(favorites)
        }

        // Correction hints (the correct versions of previously corrected words)
        let correctionHints = corrections.correctionPromptHints()
        if !correctionHints.isEmpty {
            parts.append(correctionHints)
        }

        // Custom vocabulary
        let vocab = AppConfig.customVocabulary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !vocab.isEmpty {
            parts.append(vocab)
        }

        // Recent transcription history
        let recentText = history.promptString(lastN: 10)
        if !recentText.isEmpty {
            parts.append(recentText)
        }

        // Limit total prompt length (whisper has a token limit)
        let prompt = parts.joined(separator: " ")
        if prompt.count > 500 {
            return String(prompt.suffix(500))
        }
        return prompt
    }
}
