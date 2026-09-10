import Foundation
import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Tracks window focus history across all applications to provide true Most Recently Used (MRU)
/// ordering for the window switcher. The currently focused window is always at index 0,
/// the previously focused window is at index 1, the 2nd to last at index 2, etc.
public final class WindowFocusTracker {
    public static let shared = WindowFocusTracker()
    
    // MRU focus order list: index 0 is the current / most recently focused window,
    // index 1 is the last focused window, index 2 is 2nd to last, etc.
    private(set) var focusOrder: [CGWindowID] = []
    private let lock = NSLock()
    
    private var activeAxObserver: AXObserver?
    private var observedPid: pid_t = 0
    private var isStarted = false
    
    private init() {}
    
    public func start() {
        guard !isStarted else { return }
        isStarted = true
        
        // Listen for application activation events
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Initial recording of frontmost window
        updateFrontmostFocus()
    }
    
    @objc private func handleAppActivated(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            updateFocus(for: app)
        } else {
            updateFrontmostFocus()
        }
    }
    
    public func recordFocus(windowId: CGWindowID) {
        guard windowId != 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        
        focusOrder.removeAll(where: { $0 == windowId })
        focusOrder.insert(windowId, at: 0)
        
        // Keep a reasonable history size
        if focusOrder.count > 250 {
            focusOrder.removeLast(focusOrder.count - 250)
        }
    }
    
    public func removeWindow(windowId: CGWindowID) {
        lock.lock()
        defer { lock.unlock() }
        focusOrder.removeAll(where: { $0 == windowId })
    }
    
    public func updateFrontmostFocus() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        updateFocus(for: frontApp)
    }
    
    public func updateFocus(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard pid != ProcessInfo.processInfo.processIdentifier else { return }
        
        // 1. Query AX focused window
        let appElement = AXUIElementCreateApplication(pid)
        var focusedWin: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWin) == .success,
           let win = focusedWin {
            var wid: CGWindowID = 0
            if _AXUIElementGetWindow(win as! AXUIElement, &wid) == .success && wid != 0 {
                recordFocus(windowId: wid)
                attachAxObserver(to: pid)
                return
            }
        }
        
        // 2. Fallback: Frontmost on-screen layer 0 window from CGWindowList
        if let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            for dict in infoList {
                guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0,
                      let wPid = dict[kCGWindowOwnerPID as String] as? pid_t, wPid == pid,
                      let wid = dict[kCGWindowNumber as String] as? CGWindowID else { continue }
                recordFocus(windowId: wid)
                break
            }
        }
        
        attachAxObserver(to: pid)
    }
    
    private func attachAxObserver(to pid: pid_t) {
        if observedPid == pid && activeAxObserver != nil { return }
        detachAxObserver()
        
        self.observedPid = pid
        var obs: AXObserver?
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        let callback: AXObserverCallback = { observer, element, notification, refcon in
            guard let refcon = refcon else { return }
            let tracker = Unmanaged<WindowFocusTracker>.fromOpaque(refcon).takeUnretainedValue()
            var wid: CGWindowID = 0
            if _AXUIElementGetWindow(element, &wid) == .success && wid != 0 {
                DispatchQueue.main.async {
                    tracker.recordFocus(windowId: wid)
                }
            }
        }
        
        guard AXObserverCreate(pid, callback, &obs) == .success, let observer = obs else { return }
        self.activeAxObserver = observer
        
        let appElement = AXUIElementCreateApplication(pid)
        AXObserverAddNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString, refcon)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }
    
    private func detachAxObserver() {
        if let obs = activeAxObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
            self.activeAxObserver = nil
        }
        self.observedPid = 0
    }
    
    public func sortWindowsByMRU(_ windows: [SwitcherWindowInfo]) -> [SwitcherWindowInfo] {
        lock.lock()
        let order = self.focusOrder
        lock.unlock()
        
        // Build a fallback ranking that interleaves applications.
        // First, discover the application z-order and each window's index within its application.
        var pidOrder: [pid_t] = []
        var windowRankWithinApp: [CGWindowID: Int] = [:]
        var appWindowCounts: [pid_t: Int] = [:]
        
        for win in windows {
            if !pidOrder.contains(win.pid) {
                pidOrder.append(win.pid)
            }
            let count = appWindowCounts[win.pid] ?? 0
            windowRankWithinApp[win.id] = count
            appWindowCounts[win.pid] = count + 1
        }
        
        return windows.sorted { a, b in
            if let rankA = order.firstIndex(of: a.id), let rankB = order.firstIndex(of: b.id) {
                return rankA < rankB
            } else if order.contains(a.id) {
                return true
            } else if order.contains(b.id) {
                return false
            }
            
            // Both are unknown: interleave them.
            // Primary sort: window index within its app (0th windows first, then 1st windows, etc.)
            // Secondary sort: application z-order
            let aWinRank = windowRankWithinApp[a.id] ?? 0
            let bWinRank = windowRankWithinApp[b.id] ?? 0
            if aWinRank != bWinRank {
                return aWinRank < bWinRank
            }
            
            let aPidRank = pidOrder.firstIndex(of: a.pid) ?? 0
            let bPidRank = pidOrder.firstIndex(of: b.pid) ?? 0
            return aPidRank < bPidRank
        }
    }
}
