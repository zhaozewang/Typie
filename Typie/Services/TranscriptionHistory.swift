import Foundation

/// Stores recent transcriptions locally for whisper.cpp prompt conditioning.
/// This helps whisper learn the user's vocabulary and speaking patterns.
final class TranscriptionHistory {
    private let maxEntries = 50
    private let historyFile: URL

    init() {
        let dir = NSString(string: "~/.typie").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        historyFile = URL(fileURLWithPath: dir).appendingPathComponent("history.json")
    }

    /// Append a transcription to history
    func add(_ text: String) {
        guard !text.isEmpty else { return }
        var entries = load()
        entries.append(HistoryEntry(text: text, date: Date()))
        // Keep only the most recent entries
        if entries.count > maxEntries {
            entries = Array(entries.suffix(maxEntries))
        }
        save(entries)
    }

    /// Get recent transcriptions as a single prompt string for whisper.cpp.
    /// Returns the last N transcriptions joined together.
    func promptString(lastN: Int = 10) -> String {
        let entries = load()
        let recent = entries.suffix(lastN)
        let prompt = recent.map { $0.text }.joined(separator: " ")
        return prompt
    }

    /// Get all entries
    func load() -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: historyFile),
              let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private func save(_ entries: [HistoryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: historyFile)
    }

    func clear() {
        try? FileManager.default.removeItem(at: historyFile)
    }

    struct HistoryEntry: Codable {
        let text: String
        let date: Date
    }
}
