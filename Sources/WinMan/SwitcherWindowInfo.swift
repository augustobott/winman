import Foundation
import AppKit
import CoreGraphics

public struct SwitcherWindowInfo: Identifiable {
    public let id: CGWindowID
    public let pid: pid_t
    public let appName: String
    public let appIcon: NSImage?
    public let title: String
    public let bounds: CGRect
    public var thumbnail: NSImage?
    public let isMinimized: Bool
    public let axElement: AXUIElement?
    
    public init(
        id: CGWindowID,
        pid: pid_t,
        appName: String,
        appIcon: NSImage?,
        title: String,
        bounds: CGRect,
        thumbnail: NSImage? = nil,
        isMinimized: Bool = false,
        axElement: AXUIElement? = nil
    ) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.appIcon = appIcon
        self.title = title
        self.bounds = bounds
        self.thumbnail = thumbnail
        self.isMinimized = isMinimized
        self.axElement = axElement
    }
}
