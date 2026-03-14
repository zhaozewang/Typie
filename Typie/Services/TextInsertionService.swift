import AppKit
import Carbon

final class TextInsertionService {

    private let clipboardService = ClipboardService()
    private var insertedCharCount: Int = 0

    enum InsertionError: LocalizedError {
        case accessibilityNotGranted
        case insertionFailed

        var errorDescription: String? {
            switch self {
            case .accessibilityNotGranted:
                return "Accessibility permission required for text insertion"
            case .insertionFailed:
                return "Failed to insert text"
            }
        }
    }

    /// Insert text via clipboard paste (for final insertion)
    func insertText(_ text: String) throws {
        let saved = clipboardService.save()
        clipboardService.setText(text)
        simulatePaste()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.clipboardService.restore(saved)
        }
    }

    /// Type text character by character using CGEvent key simulation.
    /// Tracks how many characters were inserted for later replacement.
    func typeText(_ text: String) {
        for char in text {
            typeCharacter(char)
        }
        insertedCharCount = text.count
    }

    /// Update the previously streamed text: delete old text, type new text.
    func updateStreamedText(from oldText: String, to newText: String) {
        // Find common prefix to minimize keystrokes
        let oldChars = Array(oldText)
        let newChars = Array(newText)
        var commonLen = 0
        while commonLen < oldChars.count && commonLen < newChars.count
                && oldChars[commonLen] == newChars[commonLen] {
            commonLen += 1
        }

        // Delete characters after the common prefix
        let deleteCount = oldChars.count - commonLen
        for _ in 0..<deleteCount {
            simulateBackspace()
        }

        // Type the new suffix
        let newSuffix = String(newChars[commonLen...])
        for char in newSuffix {
            typeCharacter(char)
        }

        insertedCharCount = newText.count
    }

    /// Delete all streamed text and insert final text via paste
    func replaceStreamedText(currentStreamedText: String, with finalText: String) {
        // Delete all streamed characters
        let deleteCount = currentStreamedText.count
        for _ in 0..<deleteCount {
            simulateBackspace()
        }

        // Small delay to let deletes process, then paste final text
        usleep(50_000) // 50ms

        let saved = clipboardService.save()
        clipboardService.setText(finalText)
        simulatePaste()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.clipboardService.restore(saved)
        }

        insertedCharCount = 0
    }

    /// Reset tracking
    func resetTracking() {
        insertedCharCount = 0
    }

    // MARK: - Private

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    private func simulateBackspace() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true)  // 0x33 = delete/backspace
        keyDown?.post(tap: .cghidEventTap)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false)
        keyUp?.post(tap: .cghidEventTap)
        usleep(2_000) // 2ms between keystrokes
    }

    private func typeCharacter(_ char: Character) {
        let source = CGEventSource(stateID: .hidSystemState)
        let utf16 = Array(String(char).utf16)

        let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        event?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        event?.post(tap: .cghidEventTap)

        let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        upEvent?.post(tap: .cghidEventTap)

        usleep(2_000) // 2ms between characters
    }
}
