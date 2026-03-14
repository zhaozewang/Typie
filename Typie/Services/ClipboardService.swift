import AppKit

final class ClipboardService {
    struct SavedContent {
        let items: [NSPasteboardItem]
    }

    func save() -> [[NSPasteboard.PasteboardType: Data]] {
        let pasteboard = NSPasteboard.general
        var saved: [[NSPasteboard.PasteboardType: Data]] = []

        for item in pasteboard.pasteboardItems ?? [] {
            var itemData: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemData[type] = data
                }
            }
            if !itemData.isEmpty {
                saved.append(itemData)
            }
        }
        return saved
    }

    func restore(_ saved: [[NSPasteboard.PasteboardType: Data]]) {
        guard !saved.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        for itemData in saved {
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }
    }

    func setText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
