import AppKit
import SwiftUI

@MainActor
final class CorrectionPopup {
    private var window: NSPanel?
    private var onCorrection: ((String, String) -> Void)?

    /// Show a small popup near the mouse with the transcribed text.
    /// User can edit to correct, and the correction is learned.
    func show(originalText: String, onCorrection: @escaping (String, String) -> Void) {
        hide()
        self.onCorrection = onCorrection

        let view = CorrectionView(
            originalText: originalText,
            onDismiss: { [weak self] in self?.hide() },
            onSubmit: { [weak self] corrected in
                if corrected != originalText {
                    onCorrection(originalText, corrected)
                }
                self?.hide()
            }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 100),
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: view)
        panel.contentView = hostingView

        // Position near mouse
        let mouse = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(x: mouse.x - 170, y: mouse.y + 10))
        panel.makeKeyAndOrderFront(nil)

        self.window = panel

        // Auto-dismiss after 8 seconds if user doesn't interact
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.hide()
        }
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

struct CorrectionView: View {
    let originalText: String
    let onDismiss: () -> Void
    let onSubmit: (String) -> Void

    @State private var editedText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Correct?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Dismiss") { onDismiss() }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }

            TextField("", text: $editedText)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .onSubmit {
                    onSubmit(editedText)
                }

            HStack {
                Text("Press Return to save correction")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if editedText != originalText && !editedText.isEmpty {
                    Button("Save") {
                        onSubmit(editedText)
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        )
        .frame(width: 340)
        .onAppear {
            editedText = originalText
        }
    }
}
