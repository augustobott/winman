import Foundation
import AppKit

public enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case monochrome = "Monochrome (macOS Tahoe)"
    case color = "Vibrant Color"
    
    public var id: String { rawValue }
}

public final class MenuBarIconManager {
    public static let shared = MenuBarIconManager()
    
    private init() {}
    
    public func icon(for style: MenuBarIconStyle) -> NSImage {
        switch style {
        case .color:
            return colorIcon()
        case .monochrome:
            return monochromeTemplateIcon()
        }
    }
    
    public func colorIcon() -> NSImage {
        // Check for bundled MenuBarIconColor.png
        if let resourceURL = Bundle.main.url(forResource: "MenuBarIconColor@2x", withExtension: "png") ??
                             Bundle.main.url(forResource: "MenuBarIconColor", withExtension: "png"),
           let image = NSImage(contentsOf: resourceURL) {
            let img = image.copy() as! NSImage
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = false
            return img
        }
        
        // Check Resources directory relative to executable
        let exeURL = Bundle.main.executableURL
        let resourcesURL = exeURL?.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/MenuBarIconColor.png")
        if let url = resourcesURL, let image = NSImage(contentsOf: url) {
            let img = image.copy() as! NSImage
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = false
            return img
        }
        
        // Fallback: load AppIcon
        if let appIcon = NSApp.applicationIconImage {
            let img = appIcon.copy() as! NSImage
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = false
            return img
        }
        
        return monochromeTemplateIcon()
    }
    
    public func monochromeTemplateIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let strokeColor = NSColor.black
            
            // Outer squircle container
            let outerRect = NSRect(x: 1.0, y: 1.0, width: 16.0, height: 16.0)
            let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 4.2, yRadius: 4.2)
            outerPath.lineWidth = 1.3
            strokeColor.setStroke()
            outerPath.stroke()
            
            // 2 columns x 3 rows grid of window tiles matching the app icon
            let colWidth: CGFloat = 5.3
            let rowHeight: CGFloat = 3.0
            let col1X: CGFloat = 2.8
            let col2X: CGFloat = 9.9
            let rowY: [CGFloat] = [2.8, 7.5, 12.2]
            
            strokeColor.setFill()
            for y in rowY {
                let rect1 = NSRect(x: col1X, y: y, width: colWidth, height: rowHeight)
                let tile1 = NSBezierPath(roundedRect: rect1, xRadius: 0.9, yRadius: 0.9)
                tile1.fill()
                
                let rect2 = NSRect(x: col2X, y: y, width: colWidth, height: rowHeight)
                let tile2 = NSBezierPath(roundedRect: rect2, xRadius: 0.9, yRadius: 0.9)
                tile2.fill()
            }
            
            return true
        }
        
        image.isTemplate = true
        return image
    }
}
