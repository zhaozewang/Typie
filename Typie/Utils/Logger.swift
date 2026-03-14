import Foundation
import os

enum AppLogger {
    private static let subsystem = "com.typie.app"

    static let general = os.Logger(subsystem: subsystem, category: "general")
    static let audio = os.Logger(subsystem: subsystem, category: "audio")
    static let transcription = os.Logger(subsystem: subsystem, category: "transcription")
    static let hotkey = os.Logger(subsystem: subsystem, category: "hotkey")
    static let permissions = os.Logger(subsystem: subsystem, category: "permissions")
}
