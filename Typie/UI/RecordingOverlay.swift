import AppKit
import SwiftUI
import Carbon

@MainActor
final class RecordingOverlay {
    private var window: NSPanel?

    func show() {
        guard window == nil else { return }

        let size = NSSize(width: 24, height: 24)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true

        let hostingView = NSHostingView(rootView: RecordingMicIcon())
        hostingView.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hostingView

        let origin = Self.getCaretScreenPosition(windowSize: size)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        self.window = panel
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }

    /// Get the caret position. Try Accessibility API, then fall back to mouse.
    private static func getCaretScreenPosition(windowSize: NSSize) -> NSPoint {
        // Try Accessibility API
        if let pos = getCaretViaAccessibility(windowSize: windowSize) {
            return pos
        }
        // Fallback: mouse cursor
        let mouse = NSEvent.mouseLocation
        return NSPoint(x: mouse.x + 16, y: mouse.y - windowSize.height - 4)
    }

    private static func getCaretViaAccessibility(windowSize: NSSize) -> NSPoint? {
        // We need to query the frontmost app's focused element
        let systemWide = AXUIElementCreateSystemWide()

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedRef) == .success else {
            return nil
        }
        let focusedApp = focusedRef as! AXUIElement

        // Get the focused UI element from the focused app
        var elementRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedApp, kAXFocusedUIElementAttribute as CFString, &elementRef) == .success else {
            return nil
        }
        let element = elementRef as! AXUIElement

        // Try to get caret rect via selected text range
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success else {
            return nil
        }

        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeRef!,
            &boundsRef
        ) == .success else {
            return nil
        }

        var axRect = CGRect.zero
        guard AXValueGetValue(boundsRef as! AXValue, .cgRect, &axRect) else {
            return nil
        }

        // Convert from AX coords (top-left origin) to Cocoa coords (bottom-left origin)
        guard let screenHeight = NSScreen.main?.frame.height else { return nil }
        let x = axRect.origin.x + axRect.width + 2
        let cocoaY = screenHeight - axRect.origin.y - axRect.height
        return NSPoint(x: x, y: cocoaY - windowSize.height / 2 + axRect.height / 2)
    }
}

struct RecordingMicIcon: View {
    @State private var isPulsing = false

    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.red)
            .opacity(isPulsing ? 0.4 : 1.0)
            .frame(width: 24, height: 24)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}
