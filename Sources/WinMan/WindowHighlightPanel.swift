import Foundation
import AppKit

@MainActor
public final class WindowHighlightPanel: NSPanel {
    public static let shared = WindowHighlightPanel()
    
    private init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        // Set level right below the switcher HUD so it highlights the desktop window
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) - 1)
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = true
        
        let borderView = HighlightBorderView()
        borderView.autoresizingMask = [.width, .height]
        self.contentView = borderView
    }
    
    public func highlight(bounds: CGRect) {
        guard let primaryScreen = NSScreen.screens.first else { return }
        
        // Convert Quartz top-left coordinates to Cocoa bottom-left coordinates
        let primaryHeight = primaryScreen.frame.height
        let cocoaY = primaryHeight - (bounds.origin.y + bounds.height)
        let frame = NSRect(x: bounds.origin.x, y: cocoaY, width: bounds.width, height: bounds.height)
        
        // Expand slightly to outline the window
        let expanded = frame.insetBy(dx: -4, dy: -4)
        self.setFrame(expanded, display: true)
        
        if !self.isVisible {
            self.alphaValue = 0
            self.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                self.animator().alphaValue = 1.0
            }
        }
    }
    
    public func dismiss() {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        self.animator().alphaValue = 0
        NSAnimationContext.endGrouping()
        self.orderOut(nil)
    }
}

private final class HighlightBorderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        let outerPath = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        let innerPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 5, yRadius: 5)
        
        // Glowing accent border
        NSColor.controlAccentColor.withAlphaComponent(0.85).setStroke()
        outerPath.lineWidth = 3.5
        outerPath.stroke()
        
        // Subtle translucent fill
        NSColor.controlAccentColor.withAlphaComponent(0.06).setFill()
        innerPath.fill()
    }
}
