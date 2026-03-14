import Foundation

enum FileUtils {
    static func tempAudioFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "typie_\(UUID().uuidString).wav"
        return tempDir.appendingPathComponent(fileName)
    }

    static func deleteIfExists(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func fileExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}
