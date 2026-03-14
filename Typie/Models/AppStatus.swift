import Foundation

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("com.typie.hotkeyChanged")
}

enum AppStatus: Equatable {
    case idle
    case recording
    case transcribing
    case error(String)

    var menuBarIcon: String {
        switch self {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .transcribing: return "ellipsis.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    var statusText: String {
        switch self {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .transcribing: return "Transcribing..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
