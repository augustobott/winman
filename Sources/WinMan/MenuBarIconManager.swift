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
           let image = NSImage(contentsOf: resourceURL),
           let img = image.copy() as? NSImage {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = false
            return img
        }
        
        // Check Resources directory relative to executable
        let exeURL = Bundle.main.executableURL
        let resourcesURL = exeURL?.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/MenuBarIconColor.png")
        if let url = resourcesURL, let image = NSImage(contentsOf: url),
           let img = image.copy() as? NSImage {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = false
            return img
        }
        
        return programmaticColorIcon()
    }
    
    public func programmaticColorIcon() -> NSImage {
        let size: CGFloat = 18
        let imgSize = NSSize(width: size, height: size)
        let image = NSImage(size: imgSize, flipped: false) { rect in
            let margin: CGFloat = size * 0.08
            let iconSize: CGFloat = size - (margin * 2.0)
            let iconRect = NSRect(x: margin, y: margin, width: iconSize, height: iconSize)
            let squirclePath = NSBezierPath(roundedRect: iconRect, xRadius: iconSize * 0.25, yRadius: iconSize * 0.25)
            
            // Gradient: cyan to purple
            let startColor = NSColor(red: 0.05, green: 0.78, blue: 0.95, alpha: 1.0)
            let endColor = NSColor(red: 0.58, green: 0.18, blue: 0.62, alpha: 1.0)
            if let gradient = NSGradient(starting: startColor, ending: endColor) {
                gradient.draw(in: squirclePath, angle: -45)
            }
            
            // 2 cols x 3 rows white window tiles
            let colW = iconSize * 0.32
            let rowH = iconSize * 0.18
            let col1X = iconRect.minX + iconSize * 0.12
            let col2X = iconRect.minX + iconSize * 0.56
            let yOffsets: [CGFloat] = [0.12, 0.41, 0.70]
            
            NSColor.white.withAlphaComponent(0.92).setFill()
            for yOff in yOffsets {
                let y = iconRect.minY + iconSize * yOff
                let r1 = NSRect(x: col1X, y: y, width: colW, height: rowH)
                let r2 = NSRect(x: col2X, y: y, width: colW, height: rowH)
                let cr = min(colW, rowH) * 0.28
                NSBezierPath(roundedRect: r1, xRadius: cr, yRadius: cr).fill()
                NSBezierPath(roundedRect: r2, xRadius: cr, yRadius: cr).fill()
            }
            
            return true
        }
        image.isTemplate = false
        return image
    }
    
    public func monochromeTemplateIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let strokeColor = NSColor.black
            
            // Outer window outline with transparent interior
            let winRect = NSRect(x: 1.5, y: 1.5, width: 15.0, height: 15.0)
            let path = NSBezierPath(roundedRect: winRect, xRadius: 2.8, yRadius: 2.8)
            path.lineWidth = 1.3
            strokeColor.setStroke()
            path.stroke()
            
            // Vertical divider (halves)
            let vLine = NSBezierPath()
            vLine.move(to: NSPoint(x: 9.0, y: 1.5))
            vLine.line(to: NSPoint(x: 9.0, y: 16.5))
            vLine.lineWidth = 1.3
            vLine.stroke()
            
            // 2 Horizontal dividers (thirds)
            let hLine1 = NSBezierPath()
            hLine1.move(to: NSPoint(x: 1.5, y: 6.5))
            hLine1.line(to: NSPoint(x: 16.5, y: 6.5))
            hLine1.lineWidth = 1.3
            hLine1.stroke()
            
            let hLine2 = NSBezierPath()
            hLine2.move(to: NSPoint(x: 1.5, y: 11.5))
            hLine2.line(to: NSPoint(x: 16.5, y: 11.5))
            hLine2.lineWidth = 1.3
            hLine2.stroke()
            
            return true
        }
        
        image.isTemplate = true
        return image
    }
}
