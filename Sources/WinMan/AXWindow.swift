import Foundation
import AppKit
import ApplicationServices


public final class AXWindow {
    public let element: AXUIElement
    
    // Cache for window frame history to support Restore / Unmaximize (capped to prevent memory growth)
    private static var restoreHistory: [CGWindowID: CGRect] = [:]
    private static var restoreHistoryOrder: [CGWindowID] = []
    
    public init(element: AXUIElement) {
        self.element = element
    }
    
    private var _cachedId: CGWindowID?
    
    public var id: CGWindowID {
        if let cached = _cachedId { return cached }
        
        var wid: CGWindowID = 0
        if _AXUIElementGetWindow(element, &wid) == .success && wid != 0 {
            _cachedId = wid
            return wid
        }
        
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        
        if let frame = self.frame {
            let options = CGWindowListOption([.optionOnScreenOnly, .excludeDesktopElements])
            if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
                for winDict in windowList {
                    if let winPid = winDict[kCGWindowOwnerPID as String] as? Int32, winPid == pid {
                        if let boundsDict = winDict[kCGWindowBounds as String] as? [String: Any],
                           let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                            if abs(bounds.origin.x - frame.origin.x) < 2 &&
                               abs(bounds.origin.y - frame.origin.y) < 2 &&
                               abs(bounds.width - frame.width) < 2 &&
                               abs(bounds.height - frame.height) < 2 {
                                if let wId = winDict[kCGWindowNumber as String] as? NSNumber {
                                    let matched = CGWindowID(wId.uint32Value)
                                    _cachedId = matched
                                    return matched
                                }
                            }
                        }
                    }
                }
            }
        }
        
        let hashId = CGWindowID(truncatingIfNeeded: CFHash(element) ^ UInt(bitPattern: Int(pid)))
        _cachedId = hashId
        return hashId
    }
    
    public var frame: CGRect? {
        let attributes: CFArray = [kAXPositionAttribute, kAXSizeAttribute] as CFArray
        var values: CFArray?
        let result = AXUIElementCopyMultipleAttributeValues(element, attributes, [], &values)
        
        guard result == .success, let array = values as? [AnyObject], array.count == 2 else { return nil }
        
        var point = CGPoint.zero
        var size = CGSize.zero
        
        let posVal = array[0]
        let szVal = array[1]
        
        guard CFGetTypeID(posVal) == AXValueGetTypeID(), CFGetTypeID(szVal) == AXValueGetTypeID() else { return nil }
        
        AXValueGetValue(posVal as! AXValue, .cgPoint, &point)
        AXValueGetValue(szVal as! AXValue, .cgSize, &size)
        
        return CGRect(origin: point, size: size)
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
    
    public func saveCurrentForRestore() {
        if let current = frame {
            let winId = id
            if AXWindow.restoreHistory[winId] == nil {
                if AXWindow.restoreHistoryOrder.count >= 100 {
                    let oldest = AXWindow.restoreHistoryOrder.removeFirst()
                    AXWindow.restoreHistory.removeValue(forKey: oldest)
                }
                AXWindow.restoreHistoryOrder.append(winId)
                AXWindow.restoreHistory[winId] = current
            }
        }
    }

    @discardableResult
    public func setFrame(_ rect: CGRect, saveCurrentForRestore: Bool = false) -> Bool {
        if saveCurrentForRestore {
            self.saveCurrentForRestore()
        }
        // Set position, then size, then position again to handle constraint adjustments
        setPosition(rect.origin)
        setSize(rect.size)
        return setPosition(rect.origin)
    }
    
    @discardableResult
    public func restorePreviousFrame() -> Bool {
        let winId = id
        guard let previous = AXWindow.restoreHistory[winId] else {
            return false
        }
        let success = setFrame(previous, saveCurrentForRestore: false)
        if success {
            AXWindow.restoreHistory.removeValue(forKey: winId)
            if let idx = AXWindow.restoreHistoryOrder.firstIndex(of: winId) {
                AXWindow.restoreHistoryOrder.remove(at: idx)
            }
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
    
    public func targetScreen(forFrame customFrame: CGRect? = nil) -> NSScreen? {
        let winFrame = customFrame ?? frame ?? CGRect(x: 0, y: 0, width: 800, height: 600)
        let winCenter = CGPoint(x: winFrame.midX, y: winFrame.midY)
        
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return NSScreen.main }
        
        let primaryHeight = screens.first?.frame.height ?? 0
        
        // Single pass: map screens to their AX frames once
        let screenAXFrames: [(screen: NSScreen, axFrame: CGRect)] = screens.map { screen in
            let cocoaFrame = screen.visibleFrame
            let axY = primaryHeight - (cocoaFrame.origin.y + cocoaFrame.size.height)
            let axFrame = CGRect(
                x: cocoaFrame.origin.x,
                y: axY,
                width: cocoaFrame.size.width,
                height: cocoaFrame.size.height
            )
            return (screen, axFrame)
        }
        
        // 1. Check center point containment
        for item in screenAXFrames {
            if item.axFrame.contains(winCenter) {
                return item.screen
            }
        }
        
        // 2. Fallback: Screen with maximum intersection area
        var bestScreen: NSScreen?
        var maxArea: CGFloat = 0
        for item in screenAXFrames {
            let intersection = item.axFrame.intersection(winFrame)
            let area = intersection.isNull ? 0 : (intersection.width * intersection.height)
            if area > maxArea {
                maxArea = area
                bestScreen = item.screen
            }
        }
        
        return bestScreen
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
