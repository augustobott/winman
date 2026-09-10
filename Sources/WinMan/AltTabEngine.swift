import Foundation
import AppKit
import CoreGraphics

public final class AltTabEngine {
    public static let shared = AltTabEngine()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    public var isEnabled: Bool = true
    public private(set) var isSwitcherActive: Bool = false
    
    private var allWindows: [SwitcherWindowInfo] = []
    private var filteredWindows: [SwitcherWindowInfo] = []
    private var selectedIndex: Int = 0
    private var searchQuery: String = ""
    
    // Key codes
    private struct KeyCode {
        static let tab: CGKeyCode = 48
        static let escape: CGKeyCode = 53
        static let enter: CGKeyCode = 36
        static let backspace: CGKeyCode = 51
        
        static let leftArrow: CGKeyCode = 123
        static let rightArrow: CGKeyCode = 124
        static let downArrow: CGKeyCode = 125
        static let upArrow: CGKeyCode = 126
        
        static let w: CGKeyCode = 13
        static let m: CGKeyCode = 46
        static let f: CGKeyCode = 3
        static let q: CGKeyCode = 12
        static let h: CGKeyCode = 4
        
        // Numbers 1-9
        static let num1: CGKeyCode = 18
        static let num2: CGKeyCode = 19
        static let num3: CGKeyCode = 20
        static let num4: CGKeyCode = 21
        static let num5: CGKeyCode = 23
        static let num6: CGKeyCode = 22
        static let num7: CGKeyCode = 26
        static let num8: CGKeyCode = 28
        static let num9: CGKeyCode = 25
    }
    
    private init() {}
    
    public func start() {
        guard eventTap == nil else { return }
        
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                     (1 << CGEventType.flagsChanged.rawValue)
        
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let engine = Unmanaged<AltTabEngine>.fromOpaque(refcon).takeUnretainedValue()
                return engine.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: observer
        ) else {
            print("[WinMan] Failed to create AltTab event tap.")
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[WinMan] AltTab switcher engine active.")
    }
    
    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
                self.runLoopSource = nil
            }
            self.eventTap = nil
        }
        cancelSwitcher()
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        guard isEnabled else {
            return Unmanaged.passRetained(event)
        }
        
        let flags = event.flags
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let prefs = PreferencesManager.shared
        
        // Handle Modifier Key Release (Commit Selection)
        if type == .flagsChanged {
            if isSwitcherActive {
                // If Option was released, commit selection
                let optionHeld = flags.contains(.maskAlternate)
                if !optionHeld {
                    DispatchQueue.main.async {
                        self.commitSelection()
                    }
                    return nil
                }
            }
            return Unmanaged.passRetained(event)
        }
        
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        
        let hasOption = flags.contains(.maskAlternate)
        let hasShift = flags.contains(.maskShift)
        
        // State 1: Switcher NOT active -> Detect Option + Tab trigger
        if !isSwitcherActive {
            if hasOption && keyCode == KeyCode.tab {
                self.isSwitcherActive = true // Set synchronously to prevent race conditions with key repeats
                DispatchQueue.main.async {
                    self.openSwitcher(reverse: hasShift)
                }
                return nil
            }
            return Unmanaged.passRetained(event)
        }
        
        // State 2: Switcher IS active -> Handle navigation, search, actions
        
        // Cycle Tab
        if keyCode == KeyCode.tab {
            DispatchQueue.main.async {
                self.cycleSelection(reverse: hasShift)
            }
            return nil
        }
        
        // Arrow Navigation
        if keyCode == KeyCode.rightArrow || keyCode == KeyCode.downArrow {
            DispatchQueue.main.async {
                self.cycleSelection(reverse: false)
            }
            return nil
        }
        if keyCode == KeyCode.leftArrow || keyCode == KeyCode.upArrow {
            DispatchQueue.main.async {
                self.cycleSelection(reverse: true)
            }
            return nil
        }
        
        // Enter / Commit
        if keyCode == KeyCode.enter {
            DispatchQueue.main.async {
                self.commitSelection()
            }
            return nil
        }
        
        // Escape / Cancel
        if keyCode == KeyCode.escape {
            DispatchQueue.main.async {
                self.cancelSwitcher()
            }
            return nil
        }
        
        // Direct 1-9 Jump
        if prefs.altTabEnableQuickNumbers, let numberIndex = numberIndex(from: keyCode) {
            DispatchQueue.main.async {
                self.selectAndCommit(index: numberIndex)
            }
            return nil
        }
        
        // In-Switcher Actions
        if keyCode == KeyCode.w {
            DispatchQueue.main.async {
                self.closeSelectedWindow()
            }
            return nil
        }
        if keyCode == KeyCode.m {
            DispatchQueue.main.async {
                self.minimizeSelectedWindow()
            }
            return nil
        }
        if keyCode == KeyCode.f {
            DispatchQueue.main.async {
                self.fullscreenSelectedWindow()
            }
            return nil
        }
        if keyCode == KeyCode.q {
            DispatchQueue.main.async {
                self.quitSelectedApp()
            }
            return nil
        }
        
        // Live Search Handling
        if prefs.altTabEnableSearch {
            if keyCode == KeyCode.backspace {
                DispatchQueue.main.async {
                    guard !self.searchQuery.isEmpty else { return }
                    self.searchQuery.removeLast()
                    self.applySearchFilter()
                }
                return nil
            } else if let chars = event.characters, let firstChar = chars.first {
                if firstChar.isLetter || firstChar.isNumber || firstChar == " " {
                    DispatchQueue.main.async {
                        self.searchQuery.append(firstChar)
                        self.applySearchFilter()
                    }
                    return nil
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Switcher Actions
    
    private func openSwitcher(reverse: Bool) {
        WindowFocusTracker.shared.updateFrontmostFocus()
        let prefs = PreferencesManager.shared
        let windows = WindowListManager.shared.fetchOpenWindows(scope: prefs.altTabScope)
        guard !windows.isEmpty else { return }
        
        self.allWindows = windows
        self.filteredWindows = windows
        self.searchQuery = ""
        
        if reverse {
            self.selectedIndex = max(0, windows.count - 1)
        } else {
            self.selectedIndex = windows.count > 1 ? 1 : 0
        }
        
        self.isSwitcherActive = true
        SwitcherOverlayController.shared.present(
            windows: filteredWindows,
            selectedIndex: selectedIndex,
            showNumbers: PreferencesManager.shared.altTabEnableQuickNumbers
        )
        
        // Highlight would-be-selected window on desktop in real time
        if selectedIndex < filteredWindows.count {
            WindowHighlightPanel.shared.highlight(bounds: filteredWindows[selectedIndex].bounds)
        }
        
        // Load live thumbnails asynchronously in background
        if prefs.altTabShowThumbnails {
            WindowListManager.shared.loadThumbnailsAsync(for: allWindows) { [weak self] wid, thumb in
                guard let self = self else { return }
                if let idx = self.allWindows.firstIndex(where: { $0.id == wid }) {
                    self.allWindows[idx].thumbnail = thumb
                }
                if let idx = self.filteredWindows.firstIndex(where: { $0.id == wid }) {
                    self.filteredWindows[idx].thumbnail = thumb
                }
                SwitcherOverlayController.shared.updateThumbnail(windowId: wid, thumbnail: thumb)
            }
        }
    }
    
    private func cycleSelection(reverse: Bool) {
        guard !filteredWindows.isEmpty else { return }
        if reverse {
            selectedIndex = (selectedIndex - 1 + filteredWindows.count) % filteredWindows.count
        } else {
            selectedIndex = (selectedIndex + 1) % filteredWindows.count
        }
        SwitcherOverlayController.shared.selectedIndex = selectedIndex
        
        // Update would-be-selected window highlight in real time
        if selectedIndex < filteredWindows.count {
            WindowHighlightPanel.shared.highlight(bounds: filteredWindows[selectedIndex].bounds)
        }
    }
    
    public func select(at index: Int) {
        guard index >= 0 && index < filteredWindows.count else { return }
        self.selectedIndex = index
        SwitcherOverlayController.shared.selectedIndex = index
        WindowHighlightPanel.shared.highlight(bounds: filteredWindows[index].bounds)
    }
    
    private func selectAndCommit(index: Int) {
        guard index >= 0 && index < filteredWindows.count else { return }
        self.selectedIndex = index
        commitSelection()
    }
    
    private func commitSelection() {
        guard isSwitcherActive else { return }
        isSwitcherActive = false
        WindowHighlightPanel.shared.dismiss()
        SwitcherOverlayController.shared.dismiss()
        
        if selectedIndex >= 0 && selectedIndex < filteredWindows.count {
            let target = filteredWindows[selectedIndex]
            WindowFocusTracker.shared.recordFocus(windowId: target.id)
            WindowListManager.shared.activate(window: target)
        }
    }
    
    private func cancelSwitcher() {
        guard isSwitcherActive else { return }
        isSwitcherActive = false
        WindowHighlightPanel.shared.dismiss()
        SwitcherOverlayController.shared.dismiss()
    }
    
    private func closeSelectedWindow() {
        guard selectedIndex >= 0 && selectedIndex < filteredWindows.count else { return }
        let win = filteredWindows[selectedIndex]
        WindowFocusTracker.shared.removeWindow(windowId: win.id)
        WindowListManager.shared.close(window: win)
        
        allWindows.removeAll { $0.id == win.id }
        applySearchFilter()
        
        if filteredWindows.isEmpty {
            cancelSwitcher()
        }
    }
    
    private func minimizeSelectedWindow() {
        guard selectedIndex >= 0 && selectedIndex < filteredWindows.count else { return }
        let win = filteredWindows[selectedIndex]
        WindowListManager.shared.minimize(window: win)
        
        allWindows.removeAll { $0.id == win.id }
        applySearchFilter()
        
        if filteredWindows.isEmpty {
            cancelSwitcher()
        }
    }
    
    private func fullscreenSelectedWindow() {
        guard selectedIndex >= 0 && selectedIndex < filteredWindows.count else { return }
        let win = filteredWindows[selectedIndex]
        WindowListManager.shared.toggleFullscreen(window: win)
        commitSelection()
    }
    
    private func quitSelectedApp() {
        guard selectedIndex >= 0 && selectedIndex < filteredWindows.count else { return }
        let win = filteredWindows[selectedIndex]
        WindowListManager.shared.quit(window: win)
        
        allWindows.removeAll { $0.pid == win.pid }
        applySearchFilter()
        
        if filteredWindows.isEmpty {
            cancelSwitcher()
        }
    }
    
    private func applySearchFilter() {
        if searchQuery.isEmpty {
            filteredWindows = allWindows
        } else {
            filteredWindows = allWindows.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                $0.appName.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        if selectedIndex >= filteredWindows.count {
            selectedIndex = max(0, filteredWindows.count - 1)
        }
        
        SwitcherOverlayController.shared.windows = filteredWindows
        SwitcherOverlayController.shared.searchQuery = searchQuery
        SwitcherOverlayController.shared.selectedIndex = selectedIndex
        
        if !filteredWindows.isEmpty && selectedIndex < filteredWindows.count {
            WindowHighlightPanel.shared.highlight(bounds: filteredWindows[selectedIndex].bounds)
        } else {
            WindowHighlightPanel.shared.dismiss()
        }
    }
    
    private func numberIndex(from keyCode: CGKeyCode) -> Int? {
        switch keyCode {
        case KeyCode.num1: return 0
        case KeyCode.num2: return 1
        case KeyCode.num3: return 2
        case KeyCode.num4: return 3
        case KeyCode.num5: return 4
        case KeyCode.num6: return 5
        case KeyCode.num7: return 6
        case KeyCode.num8: return 7
        case KeyCode.num9: return 8
        default: return nil
        }
    }
}

// Helper extension to read characters from CGEvent
private extension CGEvent {
    var characters: String? {
        var length = 0
        self.keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &length, unicodeString: nil)
        guard length > 0 else { return nil }
        var buffer = [UniChar](repeating: 0, count: length)
        self.keyboardGetUnicodeString(maxStringLength: length, actualStringLength: &length, unicodeString: &buffer)
        return String(utf16CodeUnits: buffer, count: length)
    }
}
