import Foundation
import AppKit
import CoreGraphics

@MainActor
public final class AltTabEngine {
    public static let shared = AltTabEngine()
    
    private var tapManager: EventTapManager?
    
    public var isEnabled: Bool = true
    public private(set) var isSwitcherActive: Bool = false
    
    private var allWindows: [SwitcherWindowInfo] = []
    private var filteredWindows: [SwitcherWindowInfo] = []
    private var selectedIndex: Int = 0
    private var searchQuery: String = ""
    
    // Global mouse monitor — installed while the switcher is open so that
    // clicking outside the overlay dismisses it (the panel is non-activating
    // and ignores mouse events, so without this the switcher gets stuck open).
    private var mouseMonitor: Any?
    
    private init() {}
    
    public func start() {
        guard tapManager == nil else { return }
        
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                     (1 << CGEventType.flagsChanged.rawValue)
        
        let manager = EventTapManager(label: "AltTab switcher engine", eventMask: eventMask) { [weak self] proxy, type, event in
            guard let self = self else { return Unmanaged.passRetained(event) }
            return self.handleEvent(proxy: proxy, type: type, event: event)
        }
        manager.start()
        self.tapManager = manager
    }
    
    public func stop() {
        tapManager?.stop()
        self.tapManager = nil
        cancelSwitcher()
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isEnabled else { return Unmanaged.passRetained(event) }
        
        let flags = event.flags
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let prefs = PreferencesManager.shared
        
        if type == .flagsChanged {
            return handleFlagsChanged(flags: flags, event: event)
        }
        
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        
        if !isSwitcherActive {
            return handleKeyDownWhenInactive(keyCode: keyCode, flags: flags, prefs: prefs, event: event)
        } else {
            return handleKeyDownWhenActive(keyCode: keyCode, flags: flags, prefs: prefs, event: event)
        }
    }
    
    private func handleFlagsChanged(flags: CGEventFlags, event: CGEvent) -> Unmanaged<CGEvent>? {
        if isSwitcherActive {
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
    
    private func handleKeyDownWhenInactive(keyCode: CGKeyCode, flags: CGEventFlags, prefs: PreferencesManager, event: CGEvent) -> Unmanaged<CGEvent>? {
        let hasOption = flags.contains(.maskAlternate)
        let hasShift = flags.contains(.maskShift)
        
        if hasOption && keyCode == KeyCode.tab {
            self.isSwitcherActive = true
            DispatchQueue.main.async {
                self.openSwitcher(reverse: hasShift)
            }
            return nil
        }
        return Unmanaged.passRetained(event)
    }
    
    private func handleKeyDownWhenActive(keyCode: CGKeyCode, flags: CGEventFlags, prefs: PreferencesManager, event: CGEvent) -> Unmanaged<CGEvent>? {
        let hasShift = flags.contains(.maskShift)
        
        if handleNavigation(keyCode: keyCode, hasShift: hasShift) { return nil }
        
        if handleDirectJump(keyCode: keyCode, prefs: prefs) { return nil }
        
        if handleWindowActions(keyCode: keyCode, flags: flags) { return nil }
        
        if handleLiveSearch(keyCode: keyCode, event: event, prefs: prefs) { return nil }
        
        return nil
    }
    
    private func handleNavigation(keyCode: CGKeyCode, hasShift: Bool) -> Bool {
        if keyCode == KeyCode.tab {
            DispatchQueue.main.async { self.cycleSelection(reverse: hasShift) }
            return true
        }
        if keyCode == KeyCode.rightArrow {
            DispatchQueue.main.async { self.navigateGrid(deltaX: 1, deltaY: 0) }
            return true
        }
        if keyCode == KeyCode.leftArrow {
            DispatchQueue.main.async { self.navigateGrid(deltaX: -1, deltaY: 0) }
            return true
        }
        if keyCode == KeyCode.downArrow {
            DispatchQueue.main.async { self.navigateGrid(deltaX: 0, deltaY: 1) }
            return true
        }
        if keyCode == KeyCode.upArrow {
            DispatchQueue.main.async { self.navigateGrid(deltaX: 0, deltaY: -1) }
            return true
        }
        if keyCode == KeyCode.enter {
            DispatchQueue.main.async { self.commitSelection() }
            return true
        }
        if keyCode == KeyCode.escape {
            DispatchQueue.main.async { self.cancelSwitcher() }
            return true
        }
        return false
    }
    
    private func handleDirectJump(keyCode: CGKeyCode, prefs: PreferencesManager) -> Bool {
        if prefs.altTabEnableQuickNumbers && searchQuery.isEmpty, let numberIndex = numberIndex(from: keyCode) {
            DispatchQueue.main.async { self.selectAndCommit(index: numberIndex) }
            return true
        }
        return false
    }
    
    private func handleWindowActions(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        let hasCmdOrCtrl = flags.contains(.maskCommand) || flags.contains(.maskControl)
        if !hasCmdOrCtrl {
            if keyCode == KeyCode.w { DispatchQueue.main.async { self.closeSelectedWindow() }; return true }
            if keyCode == KeyCode.m { DispatchQueue.main.async { self.minimizeSelectedWindow() }; return true }
            if keyCode == KeyCode.h { DispatchQueue.main.async { self.hideSelectedApp() }; return true }
            if keyCode == KeyCode.f { DispatchQueue.main.async { self.fullscreenSelectedWindow() }; return true }
            if keyCode == KeyCode.q { DispatchQueue.main.async { self.quitSelectedApp() }; return true }
        }
        return false
    }
    
    private func handleLiveSearch(keyCode: CGKeyCode, event: CGEvent, prefs: PreferencesManager) -> Bool {
        if prefs.altTabEnableSearch {
            if keyCode == KeyCode.backspace {
                DispatchQueue.main.async {
                    guard !self.searchQuery.isEmpty else { return }
                    self.searchQuery.removeLast()
                    self.applySearchFilter()
                }
                return true
            } else if let chars = event.characters, let firstChar = chars.first {
                if firstChar.isLetter || firstChar.isNumber || firstChar == " " {
                    DispatchQueue.main.async {
                        self.searchQuery.append(firstChar)
                        self.applySearchFilter()
                    }
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - Switcher Actions
    
    private func openSwitcher(reverse: Bool) {
        WindowFocusTracker.shared.updateFrontmostFocus()
        let prefs = PreferencesManager.shared
        let windows = WindowListManager.shared.fetchOpenWindows(scope: prefs.altTabScope)
        guard !windows.isEmpty else {
            self.isSwitcherActive = false
            return
        }
        
        self.allWindows = windows
        self.filteredWindows = windows
        self.searchQuery = ""
        
        if reverse {
            self.selectedIndex = max(0, windows.count - 1)
        } else {
            self.selectedIndex = windows.count > 1 ? 1 : 0
        }
        
        self.isSwitcherActive = true
        
        // Install a global mouse monitor so clicking outside the overlay dismisses it.
        // The switcher panel is non-activating and ignores mouse events — without this
        // a click on another window would activate that window but leave the overlay stuck.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.cancelSwitcher()
        }
        
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
    
    private func navigateGrid(deltaX: Int, deltaY: Int) {
        guard !filteredWindows.isEmpty else { return }
        let count = filteredWindows.count
        let cols = max(1, SwitcherOverlayController.shared.currentColumnCount)
        
        var newIndex = selectedIndex
        if deltaX != 0 {
            newIndex = (selectedIndex + deltaX + count) % count
        } else if deltaY != 0 {
            let target = selectedIndex + (deltaY * cols)
            if target >= 0 && target < count {
                newIndex = target
            } else if target >= count {
                let col = selectedIndex % cols
                newIndex = min(col, count - 1)
            } else if target < 0 {
                let col = selectedIndex % cols
                let lastRowStart = (count - 1) / cols * cols
                let candidate = lastRowStart + col
                newIndex = candidate < count ? candidate : count - 1
            }
        }
        
        select(at: newIndex)
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
    
    private func removeMouseMonitor() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
    
    private func commitSelection() {
        guard isSwitcherActive else { return }
        isSwitcherActive = false
        removeMouseMonitor()
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
        removeMouseMonitor()
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
    
    private func hideSelectedApp() {
        guard selectedIndex >= 0 && selectedIndex < filteredWindows.count else { return }
        let win = filteredWindows[selectedIndex]
        WindowListManager.shared.hide(window: win)
        
        allWindows.removeAll { $0.pid == win.pid }
        applySearchFilter()
        
        if filteredWindows.isEmpty {
            cancelSwitcher()
        }
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
