import Foundation
import AppKit
import CoreGraphics
import ApplicationServices

public final class WindowListManager {
    public static let shared = WindowListManager()
    
    // Thumbnail cache with timestamp
    private var thumbnailCache: [CGWindowID: (image: NSImage, timestamp: Date)] = [:]
    private let cacheQueue = DispatchQueue(label: "com.winman.thumbnailCache")
    
    private init() {}
    
    public func fetchOpenWindows(scope: AltTabScope = .allSpaces) -> [SwitcherWindowInfo] {
        let options: CGWindowListOption = (scope == .allSpaces)
            ? [.optionAll, .excludeDesktopElements]
            : [.optionOnScreenOnly, .excludeDesktopElements]
        
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        let currentPid = ProcessInfo.processInfo.processIdentifier
        var windows: [SwitcherWindowInfo] = []
        var seenWindowIds = Set<CGWindowID>()
        
        // Cache running applications by PID
        let runningApps = Dictionary(uniqueKeysWithValues: NSWorkspace.shared.runningApplications.map { ($0.processIdentifier, $0) })
        
        // Fast pass: collect valid windows
        for dict in infoList {
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let windowId = dict[kCGWindowNumber as String] as? CGWindowID else { continue }
            guard let pid = dict[kCGWindowOwnerPID as String] as? pid_t else { continue }
            guard pid != currentPid else { continue }
            guard !seenWindowIds.contains(windowId) else { continue }
            
            // Check alpha
            if let alpha = dict[kCGWindowAlpha as String] as? Double, alpha < 0.05 {
                continue
            }
            
            // Check bounds: minimum real window size
            guard let boundsDict = dict[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width >= 100, bounds.height >= 80 else {
                continue
            }
            
            // Check app
            guard let app = runningApps[pid], app.activationPolicy == .regular else { continue }
            
            seenWindowIds.insert(windowId)
            
            let appName = app.localizedName ?? (dict[kCGWindowOwnerName as String] as? String ?? "App")
            let winTitle = dict[kCGWindowName as String] as? String ?? ""
            let displayTitle = winTitle.isEmpty ? appName : winTitle
            let appIcon = app.icon
            
            // Check cache for recent thumbnail (< 4 seconds old)
            var cachedThumb: NSImage? = nil
            cacheQueue.sync {
                if let entry = thumbnailCache[windowId], Date().timeIntervalSince(entry.timestamp) < 4.0 {
                    cachedThumb = entry.image
                }
            }
            
            let winInfo = SwitcherWindowInfo(
                id: windowId,
                pid: pid,
                appName: appName,
                appIcon: appIcon,
                title: displayTitle,
                bounds: bounds,
                thumbnail: cachedThumb,
                isMinimized: false,
                axElement: nil
            )
            windows.append(winInfo)
        }
        
        // Sort windows by Most Recently Used (MRU order):
        // Current window is listed first (index 0), then the last focused (index 1), then 2nd to last (index 2), etc.
        return WindowFocusTracker.shared.sortWindowsByMRU(windows)
    }
    
    public func loadThumbnailsAsync(for windows: [SwitcherWindowInfo], completion: @escaping (CGWindowID, NSImage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            for win in windows {
                // Check if already in cache
                var needsCapture = true
                self.cacheQueue.sync {
                    if let entry = self.thumbnailCache[win.id], Date().timeIntervalSince(entry.timestamp) < 4.0 {
                        needsCapture = false
                        DispatchQueue.main.async {
                            completion(win.id, entry.image)
                        }
                    }
                }
                
                guard needsCapture else { continue }
                
                if let cgImage = CGWindowListCreateImage(
                    win.bounds,
                    .optionIncludingWindow,
                    win.id,
                    [.boundsIgnoreFraming]
                ) {
                    let thumb = NSImage(cgImage: cgImage, size: win.bounds.size)
                    self.cacheQueue.sync {
                        self.thumbnailCache[win.id] = (thumb, Date())
                    }
                    DispatchQueue.main.async {
                        completion(win.id, thumb)
                    }
                }
            }
        }
    }
    
    // MARK: - Window Actions
    
    public func activate(window: SwitcherWindowInfo) {
        WindowFocusTracker.shared.recordFocus(windowId: window.id)
        
        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return }
        app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        
        let appElement = AXUIElementCreateApplication(window.pid)
        var winList: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &winList) == .success,
           let axWindows = winList as? [AXUIElement] {
            var targetAXWin: AXUIElement? = nil
            for win in axWindows {
                var wid: CGWindowID = 0
                if _AXUIElementGetWindow(win, &wid) == .success && wid == window.id {
                    targetAXWin = win
                    break
                }
            }
            if targetAXWin == nil {
                for win in axWindows {
                    var titleVal: AnyObject?
                    if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleVal) == .success,
                       let t = titleVal as? String, t == window.title {
                        targetAXWin = win
                        break
                    }
                }
            }
            let el = targetAXWin ?? axWindows.first
            if let el = el {
                AXUIElementPerformAction(el, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, el)
            }
        }
    }
    
    public func close(window: SwitcherWindowInfo) {
        let appElement = AXUIElementCreateApplication(window.pid)
        var winList: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &winList) == .success,
           let axWindows = winList as? [AXUIElement], let first = axWindows.first {
            var closeButton: AnyObject?
            if AXUIElementCopyAttributeValue(first, kAXCloseButtonAttribute as CFString, &closeButton) == .success,
               let btn = closeButton {
                AXUIElementPerformAction((btn as! AXUIElement), kAXPressAction as CFString)
            }
        }
    }
    
    public func minimize(window: SwitcherWindowInfo) {
        let appElement = AXUIElementCreateApplication(window.pid)
        var winList: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &winList) == .success,
           let axWindows = winList as? [AXUIElement], let first = axWindows.first {
            AXUIElementSetAttributeValue(first, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        }
    }
    
    public func toggleFullscreen(window: SwitcherWindowInfo) {
        let appElement = AXUIElementCreateApplication(window.pid)
        var winList: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &winList) == .success,
           let axWindows = winList as? [AXUIElement], let first = axWindows.first {
            var fullScreenBtn: AnyObject?
            if AXUIElementCopyAttributeValue(first, kAXFullScreenButtonAttribute as CFString, &fullScreenBtn) == .success,
               let btn = fullScreenBtn {
                AXUIElementPerformAction((btn as! AXUIElement), kAXPressAction as CFString)
            }
        }
    }
    
    public func quit(window: SwitcherWindowInfo) {
        NSRunningApplication(processIdentifier: window.pid)?.terminate()
    }
    
    public func hide(window: SwitcherWindowInfo) {
        NSRunningApplication(processIdentifier: window.pid)?.hide()
    }
}
