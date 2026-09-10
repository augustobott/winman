import Foundation
import AppKit
import CoreGraphics
import ApplicationServices

public final class WindowListManager {
    public static let shared = WindowListManager()
    
    // Thumbnail cache with timestamp.
    // Capped at `maxThumbnailCacheSize` entries; oldest entry is evicted when the cap is reached.
    private var thumbnailCache: [CGWindowID: (image: NSImage, timestamp: Date)] = [:]
    private var thumbnailCacheOrder: [CGWindowID] = []   // insertion-order for eviction
    private static let maxThumbnailCacheSize = 100
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
            
            // Filter out known dummy/ghost windows placed at offscreen coordinates (e.g. dummy windows at (0, 1390))
            if bounds.origin.x == 0 && bounds.origin.y >= 1390 && bounds.width <= 500 && bounds.height <= 500 {
                continue
            }

            // For windows marked as not on screen, filter out small auxiliary popups, dropdowns, and search bubbles
            let isOnScreen = dict[kCGWindowIsOnscreen as String] as? Bool ?? false
            if !isOnScreen && (bounds.width < 300 || bounds.height < 150) {
                continue
            }
            
            // Check app
            guard let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular else { continue }
            
            seenWindowIds.insert(windowId)
            
            let appName = app.localizedName ?? (dict[kCGWindowOwnerName as String] as? String ?? "App")
            let winTitle = dict[kCGWindowName as String] as? String ?? ""
            let displayTitle = winTitle.isEmpty ? appName : winTitle
            let appIcon = app.bundleURL.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? app.icon
            
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
                
                // Using .null for screenBounds captures ONLY the specified window rather than the composite screen rectangle.
                if let cgImage = CGWindowListCreateImage(
                    .null,
                    .optionIncludingWindow,
                    win.id,
                    [.boundsIgnoreFraming]
                ) {
                    let thumb = NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
                    self.cacheQueue.sync {
                        // Evict the oldest entry if the cache is at its limit.
                        if self.thumbnailCache[win.id] == nil {
                            if self.thumbnailCacheOrder.count >= WindowListManager.maxThumbnailCacheSize,
                               let oldest = self.thumbnailCacheOrder.first {
                                self.thumbnailCache.removeValue(forKey: oldest)
                                self.thumbnailCacheOrder.removeFirst()
                            }
                            self.thumbnailCacheOrder.append(win.id)
                        }
                        self.thumbnailCache[win.id] = (thumb, Date())
                    }
                    DispatchQueue.main.async {
                        completion(win.id, thumb)
                    }
                }
            }
        }
    }
    
    // MARK: - AX Window Lookup

    /// Returns the `AXUIElement` for the specific window identified by `window.id`.
    /// Matches by `CGWindowID` first (precise), then by window bounds/frame (geometric match),
    /// then falls back to title matching (best-effort).
    /// Returns `nil` when no match is found.
    private func targetAXWindow(for window: SwitcherWindowInfo) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(window.pid)
        var winList: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &winList) == .success,
              let axWindows = winList as? [AXUIElement], !axWindows.isEmpty else { return nil }

        // 1. Precise match by CGWindowID
        for axWin in axWindows {
            var wid: CGWindowID = 0
            if _AXUIElementGetWindow(axWin, &wid) == .success && wid == window.id {
                return axWin
            }
        }

        // 2. Geometric match by window bounds (position & size)
        // AX coordinates and CGWindowList bounds share the same Quartz coordinate space.
        for axWin in axWindows {
            let axWindowObj = AXWindow(element: axWin)
            if let axFrame = axWindowObj.frame {
                let originDelta = abs(axFrame.origin.x - window.bounds.origin.x) + abs(axFrame.origin.y - window.bounds.origin.y)
                let sizeDelta = abs(axFrame.size.width - window.bounds.size.width) + abs(axFrame.size.height - window.bounds.size.height)
                if originDelta < 15 && sizeDelta < 15 {
                    return axWin
                }
            }
        }

        // 3. Best-effort fallback: match by title
        for axWin in axWindows {
            var titleVal: AnyObject?
            if AXUIElementCopyAttributeValue(axWin, kAXTitleAttribute as CFString, &titleVal) == .success,
               let t = titleVal as? String, !t.isEmpty {
                if t == window.title || window.title.contains(t) || t.contains(window.title) {
                    return axWin
                }
            }
        }

        return nil
    }

    // MARK: - Window Actions

    public func activate(window: SwitcherWindowInfo) {
        WindowFocusTracker.shared.recordFocus(windowId: window.id)
        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return }

        let appElement = AXUIElementCreateApplication(window.pid)
        var axWinToRaise = targetAXWindow(for: window)

        // Fallback for activate: if no exact match, grab the app's first AX window
        if axWinToRaise == nil {
            var winList: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &winList) == .success,
               let axWindows = winList as? [AXUIElement] {
                axWinToRaise = axWindows.first
            }
        }

        // Activate the application process without disrupting other windows
        app.activate(options: [.activateIgnoringOtherApps])

        // Raise and focus the specific window via AX.
        if let axWin = axWinToRaise {
            AXUIElementPerformAction(axWin, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, axWin)
            AXUIElementSetAttributeValue(appElement, kAXMainWindowAttribute as CFString, axWin)
        }
    }

    public func close(window: SwitcherWindowInfo) {
        guard let axWin = targetAXWindow(for: window) else { return }
        var closeButton: AnyObject?
        if AXUIElementCopyAttributeValue(axWin, kAXCloseButtonAttribute as CFString, &closeButton) == .success,
           let btn = closeButton, CFGetTypeID(btn) == AXUIElementGetTypeID() {
            AXUIElementPerformAction(btn as! AXUIElement, kAXPressAction as CFString)
        }
    }

    public func minimize(window: SwitcherWindowInfo) {
        guard let axWin = targetAXWindow(for: window) else { return }
        AXUIElementSetAttributeValue(axWin, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    public func toggleFullscreen(window: SwitcherWindowInfo) {
        guard let axWin = targetAXWindow(for: window) else { return }
        var fullScreenBtn: AnyObject?
        if AXUIElementCopyAttributeValue(axWin, kAXFullScreenButtonAttribute as CFString, &fullScreenBtn) == .success,
           let btn = fullScreenBtn, CFGetTypeID(btn) == AXUIElementGetTypeID() {
            AXUIElementPerformAction(btn as! AXUIElement, kAXPressAction as CFString)
        }
    }

    public func quit(window: SwitcherWindowInfo) {
        NSRunningApplication(processIdentifier: window.pid)?.terminate()
    }

    public func hide(window: SwitcherWindowInfo) {
        NSRunningApplication(processIdentifier: window.pid)?.hide()
    }
}
