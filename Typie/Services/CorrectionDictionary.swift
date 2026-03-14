import Foundation

/// Stores user corrections (wrong → right) and favorite words.
/// Corrections are applied post-transcription and fed as prompt context.
final class CorrectionDictionary {
    private let filePath: URL

    init() {
        let dir = NSString(string: "~/.typie").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        filePath = URL(fileURLWithPath: dir).appendingPathComponent("corrections.json")
    }

    struct Data: Codable {
        var replacements: [Replacement] = []
        var favoriteWords: [String] = []
    }

    struct Replacement: Codable, Identifiable {
        let id: UUID
        var wrong: String
        var right: String

        init(wrong: String, right: String) {
            self.id = UUID()
            self.wrong = wrong
            self.right = right
        }
    }

    func load() -> Data {
        guard let raw = try? Foundation.Data(contentsOf: filePath),
              let data = try? JSONDecoder().decode(Data.self, from: raw) else {
            return Data()
        }
        return data
    }

    func save(_ data: Data) {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        try? raw.write(to: filePath)
    }

    // MARK: - Replacements

    func addReplacement(wrong: String, right: String) {
        var data = load()
        // Update existing or add new
        if let idx = data.replacements.firstIndex(where: { $0.wrong == wrong }) {
            data.replacements[idx].right = right
        } else {
            data.replacements.append(Replacement(wrong: wrong, right: right))
        }
        save(data)
    }

    func removeReplacement(id: UUID) {
        var data = load()
        data.replacements.removeAll { $0.id == id }
        save(data)
    }

    /// Apply all replacement rules to a transcription
    func applyCorrections(_ text: String) -> String {
        let data = load()
        var result = text
        for r in data.replacements {
            result = result.replacingOccurrences(of: r.wrong, with: r.right)
        }
        return result
    }

    // MARK: - Favorite Words

    func addFavoriteWord(_ word: String) {
        var data = load()
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !data.favoriteWords.contains(trimmed) else { return }
        data.favoriteWords.append(trimmed)
        save(data)
    }

    func removeFavoriteWord(_ word: String) {
        var data = load()
        data.favoriteWords.removeAll { $0 == word }
        save(data)
    }

    /// Get all favorite words as prompt text
    func favoriteWordsPrompt() -> String {
        let data = load()
        return data.favoriteWords.joined(separator: ", ")
    }

    /// Get correction targets as prompt hints (the "right" versions)
    func correctionPromptHints() -> String {
        let data = load()
        return data.replacements.map { $0.right }.joined(separator: ", ")
    }
}
