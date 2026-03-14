import Foundation

struct WhisperModel: Identifiable, Hashable {
    let id: String
    let displayName: String
    let fileName: String
    let size: String
    let downloadURL: URL
    let speedNote: String

    var localPath: String {
        let dir = NSString(string: "~/.typie/models").expandingTildeInPath
        return (dir as NSString).appendingPathComponent(fileName)
    }

    var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: localPath)
    }

    static let all: [WhisperModel] = [
        WhisperModel(
            id: "tiny",
            displayName: "Tiny",
            fileName: "ggml-tiny.bin",
            size: "75 MB",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin")!,
            speedNote: "Fastest, lowest accuracy"
        ),
        WhisperModel(
            id: "base",
            displayName: "Base",
            fileName: "ggml-base.bin",
            size: "142 MB",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!,
            speedNote: "Fast, basic accuracy"
        ),
        WhisperModel(
            id: "small",
            displayName: "Small",
            fileName: "ggml-small.bin",
            size: "466 MB",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!,
            speedNote: "Good balance"
        ),
        WhisperModel(
            id: "medium",
            displayName: "Medium",
            fileName: "ggml-medium.bin",
            size: "1.5 GB",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin")!,
            speedNote: "Good accuracy, moderate speed"
        ),
        WhisperModel(
            id: "large-v3",
            displayName: "Large v3",
            fileName: "ggml-large-v3.bin",
            size: "2.9 GB",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin")!,
            speedNote: "Best accuracy, slowest"
        ),
        WhisperModel(
            id: "large-v3-turbo",
            displayName: "Large v3 Turbo",
            fileName: "ggml-large-v3-turbo.bin",
            size: "1.6 GB",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!,
            speedNote: "Near-best accuracy, faster than large"
        ),
    ]

    static let vadModel = WhisperModel(
        id: "vad-silero",
        displayName: "Silero VAD",
        fileName: "ggml-silero-v5.0.bin",
        size: "2 MB",
        downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-silero-v5.0.bin")!,
        speedNote: "Voice activity detection model"
    )

    static func find(_ id: String) -> WhisperModel? {
        all.first { $0.id == id }
    }
}
