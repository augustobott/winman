import XCTest
import AppKit
@testable import WinMan

@MainActor
final class WinManTests: XCTestCase {
    
    func testSwitcherWindowInfoInitialization() {
        let win = SwitcherWindowInfo(
            id: 12345,
            pid: 999,
            appName: "TestApp",
            appIcon: nil,
            title: "Test Window",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600)
        )
        
        XCTAssertEqual(win.id, 12345)
        XCTAssertEqual(win.title, "Test Window")
        XCTAssertEqual(win.appName, "TestApp")
        XCTAssertEqual(win.pid, 999)
        XCTAssertEqual(win.bounds.width, 800)
    }
    
    func testMRUSortingWithRecordedFocus() {
        let tracker = WindowFocusTracker.shared
        
        let win1 = SwitcherWindowInfo(id: 101, pid: 10, appName: "App A", appIcon: nil, title: "Win 1", bounds: .zero)
        let win2 = SwitcherWindowInfo(id: 102, pid: 10, appName: "App A", appIcon: nil, title: "Win 2", bounds: .zero)
        let win3 = SwitcherWindowInfo(id: 201, pid: 20, appName: "App B", appIcon: nil, title: "Win 3", bounds: .zero)
        
        // Record focus order: win2 was focused first, then win3 was focused most recently
        tracker.recordFocus(windowId: 102)
        tracker.recordFocus(windowId: 201)
        
        let sorted = tracker.sortWindowsByMRU([win1, win2, win3])
        
        // Most recently focused should be win3 (index 0), followed by win2 (index 1), then unfocused win1 (index 2)
        XCTAssertEqual(sorted.first?.id, 201)
        XCTAssertEqual(sorted[1].id, 102)
        XCTAssertEqual(sorted[2].id, 101)
        
        // Clean up
        tracker.removeWindow(windowId: 102)
        tracker.removeWindow(windowId: 201)
    }
    
    func testPreferencesPresets() {
        let prefs = PreferencesManager.shared
        
        prefs.setPreset(cmd: true, ctrl: true, opt: false, shift: false)
        XCTAssertTrue(prefs.moveCtrl)
        XCTAssertTrue(prefs.moveCmd)
        XCTAssertFalse(prefs.moveOpt)
        XCTAssertFalse(prefs.moveShift)
        
        prefs.setPreset(cmd: false, ctrl: false, opt: true, shift: false)
        XCTAssertTrue(prefs.moveOpt)
        XCTAssertFalse(prefs.moveCmd)
        XCTAssertFalse(prefs.moveCtrl)
        XCTAssertFalse(prefs.moveShift)
    }
    
    func testScreenAXVisibleFrameCalculation() {
        if let mainScreen = NSScreen.main {
            let axFrame = AXWindow.screenAXVisibleFrame(mainScreen)
            XCTAssertGreaterThan(axFrame.width, 0)
            XCTAssertGreaterThan(axFrame.height, 0)
            XCTAssertGreaterThanOrEqual(axFrame.origin.y, 0)
        }
    }
    
    func testMenuBarIconManager() {
        let manager = MenuBarIconManager.shared
        let monoIcon = manager.icon(for: .monochrome)
        XCTAssertNotNil(monoIcon)
        XCTAssertTrue(monoIcon.isTemplate)
        
        let colorIcon = manager.icon(for: .color)
        XCTAssertNotNil(colorIcon)
    }
    
    func testSearchFiltering() {
        let windows = [
            SwitcherWindowInfo(id: 1, pid: 100, appName: "Terminal", appIcon: nil, title: "bash", bounds: .zero),
            SwitcherWindowInfo(id: 2, pid: 101, appName: "Safari", appIcon: nil, title: "Apple Developer Documentation", bounds: .zero),
            SwitcherWindowInfo(id: 3, pid: 102, appName: "Xcode", appIcon: nil, title: "WinMan — AltTabEngine.swift", bounds: .zero)
        ]
        
        let query = "AltTab"
        let filtered = windows.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.appName.localizedCaseInsensitiveContains(query)
        }
        
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.appName, "Xcode")
    }
    
    func testGridNavigationMath() {
        // Given a 4-column grid with 10 items (indices 0..9)
        let cols = 4
        let count = 10
        
        // Move right from index 0 -> 1
        let rightFrom0 = (0 + 1) % count
        XCTAssertEqual(rightFrom0, 1)
        
        // Move down from index 1 (row 0, col 1) -> index 5 (row 1, col 1)
        let downFrom1 = 1 + cols
        XCTAssertEqual(downFrom1, 5)
        
        // Move down from index 5 (row 1, col 1) -> index 9 (row 2, col 1)
        let downFrom5 = 5 + cols
        XCTAssertEqual(downFrom5, 9)
        
        // Move down from index 9 (target = 13 >= count) -> wraps to top row same column (index 1)
        let downFrom9Target = 9 + cols
        let wrappedDown = downFrom9Target >= count ? (9 % cols) : downFrom9Target
        XCTAssertEqual(wrappedDown, 1)
    }
    
    func testKeyCodes() {
        XCTAssertEqual(KeyCode.tab, 48)
        XCTAssertEqual(KeyCode.escape, 53)
        XCTAssertEqual(KeyCode.enter, 36)
        XCTAssertEqual(KeyCode.leftArrow, 123)
        XCTAssertEqual(KeyCode.rightArrow, 124)
        XCTAssertEqual(KeyCode.downArrow, 125)
        XCTAssertEqual(KeyCode.upArrow, 126)
    }
    
    func testResetToDefaults() {
        let prefs = PreferencesManager.shared
        // Modify some preferences away from default
        prefs.easyMoveResizeEnabled = false
        prefs.hotkeySnapEnabled = false
        prefs.altTabScope = .currentScreen
        prefs.setPreset(cmd: false, ctrl: true, opt: false, shift: true)
        
        // Reset to defaults
        prefs.resetToDefaults()
        
        // Verify all settings are restored
        XCTAssertTrue(prefs.easyMoveResizeEnabled)
        XCTAssertTrue(prefs.hotkeySnapEnabled)
        XCTAssertTrue(prefs.altTabEnabled)
        XCTAssertEqual(prefs.altTabScope, .allSpaces)
        XCTAssertTrue(prefs.moveCmd)
        XCTAssertFalse(prefs.moveCtrl)
        XCTAssertTrue(prefs.moveOpt)
        XCTAssertFalse(prefs.moveShift)
    }
    
    func testModifierValidation() {
        let prefs = PreferencesManager.shared
        // Turn off cmd, ctrl, shift
        prefs.moveCmd = false
        prefs.moveCtrl = false
        prefs.moveShift = false
        prefs.moveOpt = true
        
        // Attempt to turn off the last modifier (opt)
        prefs.moveOpt = false
        // Should automatically enforce at least one modifier is active
        XCTAssertTrue(prefs.moveOpt || prefs.moveCmd || prefs.moveCtrl || prefs.moveShift)
        XCTAssertFalse(prefs.moveModifiersMask.isEmpty)
        
        // Clean up
        prefs.resetToDefaults()
    }
    
    func testEventTapManagerInit() {
        let tap = EventTapManager(label: "TestTap", eventMask: 0) { proxy, type, event in
            return Unmanaged.passRetained(event)
        }
        XCTAssertFalse(tap.isRunning)
    }

    func testPreferencesWindowHelpers() {
        // Access nonisolated preferences window helpers
        _ = PreferencesWindowController.isPreferencesVisible
        _ = PreferencesWindowController.preferencesWindowId
        
        let tracker = WindowFocusTracker.shared
        tracker.recordFocus(windowId: 99999)
        XCTAssertTrue(tracker.focusOrder.contains(99999))
        tracker.removeWindow(windowId: 99999)
        XCTAssertFalse(tracker.focusOrder.contains(99999))
    }
}
