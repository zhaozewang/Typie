import Foundation
import Carbon

struct AppConfig {
    static let defaultWhisperBinaryPath = "/usr/local/bin/whisper-cpp"

    static var whisperBinaryPath: String {
        get { UserDefaults.standard.string(forKey: "whisperBinaryPath") ?? defaultWhisperBinaryPath }
        set { UserDefaults.standard.set(newValue, forKey: "whisperBinaryPath") }
    }

    static var selectedModelId: String {
        get { UserDefaults.standard.string(forKey: "selectedModelId") ?? "large-v3-turbo" }
        set { UserDefaults.standard.set(newValue, forKey: "selectedModelId") }
    }

    static var selectedModel: WhisperModel {
        WhisperModel.find(selectedModelId) ?? WhisperModel.all.last!
    }

    static var resolvedModelPath: String { selectedModel.localPath }

    static var resolvedWhisperBinaryPath: String {
        NSString(string: whisperBinaryPath).expandingTildeInPath
    }

    // MARK: - Language (Feature 9)

    static var language: String {
        get { UserDefaults.standard.string(forKey: "language") ?? "auto" }
        set { UserDefaults.standard.set(newValue, forKey: "language") }
    }

    static let supportedLanguages: [(code: String, name: String)] = [
        ("auto", "Auto-detect"),
        ("zh", "Chinese"),
        ("en", "English"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("de", "German"),
        ("fr", "French"),
        ("es", "Spanish"),
        ("ru", "Russian"),
        ("ar", "Arabic"),
    ]

    // MARK: - Silence detection (Feature 2)

    static var silenceTimeoutSeconds: Double {
        get { UserDefaults.standard.object(forKey: "silenceTimeoutSeconds") as? Double ?? 3.0 }
        set { UserDefaults.standard.set(newValue, forKey: "silenceTimeoutSeconds") }
    }

    static var silenceThresholdDb: Float {
        get { UserDefaults.standard.object(forKey: "silenceThresholdDb") as? Float ?? -40.0 }
        set { UserDefaults.standard.set(newValue, forKey: "silenceThresholdDb") }
    }

    static var autoStopEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "autoStopEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "autoStopEnabled") }
    }

    // MARK: - Hotkey (Feature 3)

    static var hotkeyKeyCode: UInt32 {
        get { UInt32(UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? Int ?? Int(kVK_Space)) }
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkeyKeyCode") }
    }

    static var hotkeyModifiers: UInt32 {
        get { UInt32(UserDefaults.standard.object(forKey: "hotkeyModifiers") as? Int ?? Int(optionKey)) }
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkeyModifiers") }
    }

    static var hotkeyDisplayString: String {
        var parts: [String] = []
        let mods = hotkeyModifiers
        if mods & UInt32(controlKey) != 0 { parts.append("⌃") }
        if mods & UInt32(optionKey) != 0 { parts.append("⌥") }
        if mods & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if mods & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyCodeToString(hotkeyKeyCode))
        return parts.joined(separator: "")
    }

    private static func keyCodeToString(_ keyCode: UInt32) -> String {
        let map: [UInt32: String] = [
            UInt32(kVK_Space): "Space",
            UInt32(kVK_Return): "Return",
            UInt32(kVK_Tab): "Tab",
            UInt32(kVK_Delete): "Delete",
            UInt32(kVK_Escape): "Esc",
            UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
            UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
            UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
            UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
            UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
            UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
            UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
            UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
            UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
            UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
            UInt32(kVK_ANSI_9): "9",
        ]
        return map[keyCode] ?? "Key\(keyCode)"
    }

    // MARK: - Launch at login (Feature 4)

    static var launchAtLogin: Bool {
        get { UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "launchAtLogin") }
    }

    // MARK: - VAD (Feature 7)

    static var vadEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "vadEnabled") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "vadEnabled") }
    }

    static var vadModelPath: String {
        get { UserDefaults.standard.string(forKey: "vadModelPath") ?? "~/.typie/models/ggml-silero-v5.0.bin" }
        set { UserDefaults.standard.set(newValue, forKey: "vadModelPath") }
    }

    static var resolvedVadModelPath: String {
        NSString(string: vadModelPath).expandingTildeInPath
    }

    // MARK: - Prompt conditioning

    static var usePromptConditioning: Bool {
        get { UserDefaults.standard.object(forKey: "usePromptConditioning") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "usePromptConditioning") }
    }

    static var customVocabulary: String {
        get { UserDefaults.standard.string(forKey: "customVocabulary") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "customVocabulary") }
    }
}
