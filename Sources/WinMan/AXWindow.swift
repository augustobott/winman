import Foundation
import AppKit
import ApplicationServices

public struct WindowRect {
    public var origin: CGPoint
    public var size: CGSize
    
    public init(origin: CGPoint, size: CGSize) {
        self.origin = origin
        self.size = size
    }
    
    public init(cgRect: CGRect) {
        self.origin = cgRect.origin
        self.size = cgRect.size
    }
    
    public var cgRect: CGRect {
        return CGRect(origin: origin, size: size)
    }
}

public final class AXWindow {
    public let element: AXUIElement
    
    // Cache for window frame history to support Restore / Unmaximize
    private static var restoreHistory: [Int: CGRect] = [:]
    
    public init(element: AXUIElement) {
        self.element = element
    }
    
    public var id: Int {
        return Int(CFHash(element))
    }
    
    public var frame: CGRect? {
        guard let pos = position, let sz = size else { return nil }
        return CGRect(origin: pos, size: sz)
    }
    
    public var position: CGPoint? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value)
        guard result == .success, let val = value, CFGetTypeID(val) == AXValueGetTypeID() else { return nil }
        let axVal = val as! AXValue
        var point = CGPoint.zero
        if AXValueGetValue(axVal, .cgPoint, &point) {
            return point
        }
        return nil
    }
    
    public var size: CGSize? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value)
        guard result == .success, let val = value, CFGetTypeID(val) == AXValueGetTypeID() else { return nil }
        let axVal = val as! AXValue
        var sz = CGSize.zero
        if AXValueGetValue(axVal, .cgSize, &sz) {
            return sz
        }
        return nil
    }
    
    @discardableResult
    public func setPosition(_ point: CGPoint) -> Bool {
        var pt = point
        guard let val = AXValueCreate(.cgPoint, &pt) else { return false }
        let result = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, val)
        return result == .success
    }
    
    @discardableResult
    public func setSize(_ sz: CGSize) -> Bool {
        var s = sz
        guard let val = AXValueCreate(.cgSize, &s) else { return false }
        let result = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, val)
        return result == .success
    }
    
    @discardableResult
    public func setFrame(_ rect: CGRect, saveCurrentForRestore: Bool = false) -> Bool {
        if saveCurrentForRestore, let current = frame {
            AXWindow.restoreHistory[id] = current
        }
        // Set position, then size, then position again to handle constraint adjustments
        setPosition(rect.origin)
        setSize(rect.size)
        return setPosition(rect.origin)
    }
    
    public func restorePreviousFrame() -> Bool {
        guard let previous = AXWindow.restoreHistory[id] else {
            return false
        }
        let success = setFrame(previous, saveCurrentForRestore: false)
        if success {
            AXWindow.restoreHistory.removeValue(forKey: id)
        }
        return success
    }
    
    // MARK: - Discovery Helpers
    
    public static func focusedWindow() -> AXWindow? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        
        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        if result == .success, let win = focusedWindow, CFGetTypeID(win) == AXUIElementGetTypeID() {
            return AXWindow(element: win as! AXUIElement)
        }
        
        // Fallback: Check all windows in the front application
        var windowList: AnyObject?
        let listResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList)
        if listResult == .success, let array = windowList as? [AXUIElement], let first = array.first {
            return AXWindow(element: first)
        }
        
        return nil
    }
    
    public static func windowAt(point: CGPoint) -> AXWindow? {
        let systemWide = AXUIElementCreateSystemWide()
        var elementUnderCursor: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &elementUnderCursor)
        
        guard result == .success, let elem = elementUnderCursor else {
            return focusedWindow()
        }
        
        // Find window ancestor
        var current: AXUIElement? = elem
        while let el = current {
            var role: AnyObject?
            if AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role) == .success,
               let roleStr = role as? String, roleStr == (kAXWindowRole as String) {
                return AXWindow(element: el)
            }
            
            // Check kAXWindowAttribute
            var winObj: AnyObject?
            if AXUIElementCopyAttributeValue(el, kAXWindowAttribute as CFString, &winObj) == .success,
               let win = winObj, CFGetTypeID(win) == AXUIElementGetTypeID() {
                return AXWindow(element: win as! AXUIElement)
            }
            
            // Climb to parent
            var parent: AnyObject?
            if AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &parent) == .success,
               let p = parent, CFGetTypeID(p) == AXUIElementGetTypeID() {
                current = (p as! AXUIElement)
            } else {
                break
            }
        }
        
        return focusedWindow()
    }
    
    // MARK: - Screen helpers
    
    public func targetScreen() -> NSScreen? {
        let winFrame = frame ?? CGRect(x: 0, y: 0, width: 800, height: 600)
        let winCenter = CGPoint(x: winFrame.midX, y: winFrame.midY)
        
        for screen in NSScreen.screens {
            let screenAXFrame = AXWindow.screenAXVisibleFrame(screen)
            if screenAXFrame.contains(winCenter) {
                return screen
            }
        }
        
        // Fallback to screen with maximum intersection area
        var bestScreen: NSScreen?
        var maxArea: CGFloat = -1
        for screen in NSScreen.screens {
            let screenAXFrame = AXWindow.screenAXVisibleFrame(screen)
            let intersection = screenAXFrame.intersection(winFrame)
            let area = intersection.isNull ? 0 : (intersection.width * intersection.height)
            if area > maxArea {
                maxArea = area
                bestScreen = screen
            }
        }
        
        return bestScreen ?? NSScreen.main
    }
    
    public static func screenAXVisibleFrame(_ screen: NSScreen) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let cocoaFrame = screen.visibleFrame
        let axY = primaryHeight - (cocoaFrame.origin.y + cocoaFrame.size.height)
        return CGRect(
            x: cocoaFrame.origin.x,
            y: axY,
            width: cocoaFrame.size.width,
            height: cocoaFrame.size.height
        )
    }
}
