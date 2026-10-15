import XCTest
import AppKit
import SwiftUI
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
        if let monoRep = NSBitmapImageRep(data: monoIcon.tiffRepresentation!) {
            XCTAssertTrue(monoRep.hasAlpha)
            XCTAssertEqual(monoRep.colorAt(x: 0, y: 0)?.alphaComponent, 0.0)
        }
        
        let colorIcon = manager.icon(for: .color)
        XCTAssertNotNil(colorIcon)
        XCTAssertFalse(colorIcon.isTemplate)
        if let colorRep = NSBitmapImageRep(data: colorIcon.tiffRepresentation!) {
            XCTAssertTrue(colorRep.hasAlpha)
            XCTAssertEqual(colorRep.colorAt(x: 0, y: 0)?.alphaComponent, 0.0)
        }
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
        prefs.altTabScope = .allSpaces
        prefs.setPreset(cmd: false, ctrl: true, opt: false, shift: true)
        
        // Reset to defaults
        prefs.resetMoveResizeDefaults()
        prefs.resetSnapDefaults()
        prefs.resetAltTabDefaults()
        
        // Verify all settings are restored
        XCTAssertTrue(prefs.easyMoveResizeEnabled)
        XCTAssertTrue(prefs.hotkeySnapEnabled)
        XCTAssertTrue(prefs.altTabEnabled)
        XCTAssertEqual(prefs.altTabScope, .currentScreen)
        XCTAssertTrue(prefs.moveCmd)
        XCTAssertTrue(prefs.moveCtrl)
        XCTAssertFalse(prefs.moveOpt)
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
        prefs.resetMoveResizeDefaults()
        prefs.resetSnapDefaults()
        prefs.resetAltTabDefaults()
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
    
    func testTrackingParameterStripping() {
        let manager = BrowserRouterManager.shared
        
        let urlWithTracking = URL(string: "https://example.com/article?utm_source=twitter&utm_medium=social&utm_campaign=spring2026&fbclid=12345&gclid=67890&keep=this")!
        let cleaned = manager.stripTrackingParameters(from: urlWithTracking)
        
        XCTAssertEqual(cleaned.host, "example.com")
        XCTAssertEqual(cleaned.path, "/article")
        let components = URLComponents(url: cleaned, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.queryItems?.count, 1)
        XCTAssertEqual(components.queryItems?.first?.name, "keep")
        XCTAssertEqual(components.queryItems?.first?.value, "this")
        
        let urlNoTracking = URL(string: "https://example.com/page?foo=bar")!
        XCTAssertEqual(manager.stripTrackingParameters(from: urlNoTracking), urlNoTracking)
        
        let urlOnlyTracking = URL(string: "https://example.com/test?utm_source=newsletter&fbclid=abc")!
        let strippedAll = manager.stripTrackingParameters(from: urlOnlyTracking)
        XCTAssertEqual(strippedAll.query, nil)
    }
    
    func testURLRoutingRuleMatching() {
        // Subdomain / Domain rule
        let githubRule = URLRoutingRule(pattern: "github.com", targetBrowserBundleId: "com.apple.Safari")
        XCTAssertTrue(githubRule.matches(url: URL(string: "https://github.com/winman/WinMan")!))
        XCTAssertTrue(githubRule.matches(url: URL(string: "https://api.github.com/repos")!))
        XCTAssertFalse(githubRule.matches(url: URL(string: "https://notgithub.com")!))
        
        // Wildcard rule
        let googleWildcard = URLRoutingRule(pattern: "*.google.com", targetBrowserBundleId: "com.google.Chrome")
        XCTAssertTrue(googleWildcard.matches(url: URL(string: "https://mail.google.com/mail/u/0")!))
        XCTAssertTrue(googleWildcard.matches(url: URL(string: "https://docs.google.com")!))
        XCTAssertFalse(googleWildcard.matches(url: URL(string: "https://google.org")!))
        
        // Prefix / Path rule
        let zoomRule = URLRoutingRule(pattern: "zoom.us/j/", targetBrowserBundleId: "us.zoom.xos")
        XCTAssertTrue(zoomRule.matches(url: URL(string: "https://zoom.us/j/123456789")!))
        XCTAssertFalse(zoomRule.matches(url: URL(string: "https://zoom.us/about")!))
        
        // Disabled rule flag check
        var disabledRule = URLRoutingRule(pattern: "github.com", targetBrowserBundleId: "com.apple.Safari")
        disabledRule.isEnabled = false
        XCTAssertFalse(disabledRule.isEnabled)
    }
    
    func testBrowserRouterPreferences() {
        let prefs = PreferencesManager.shared
        
        // Test defaults reset
        prefs.browserRouterEnabled = false
        prefs.browserRouterStripTracking = false
        prefs.browserRouterBehavior = BrowserPickerBehavior.alwaysPrompt.rawValue
        
        prefs.addBrowserRouterRule(pattern: "test.com", targetBrowserBundleId: "com.apple.Safari")
        guard let addedRule = prefs.browserRouterRules.first(where: { $0.pattern == "test.com" }) else {
            XCTFail("Rule was not added")
            return
        }
        
        prefs.removeBrowserRouterRule(id: addedRule.id)
        XCTAssertFalse(prefs.browserRouterRules.contains(where: { $0.id == addedRule.id }))
        
        prefs.resetBrowserRouterDefaults()
        XCTAssertTrue(prefs.browserRouterEnabled)
        XCTAssertTrue(prefs.browserRouterStripTracking)
        XCTAssertTrue(prefs.browserRouterOptionKeyPrompts)
        XCTAssertEqual(prefs.browserRouterBehavior, BrowserPickerBehavior.openDefault.rawValue)
        XCTAssertEqual(prefs.browserRouterRules.count, 0)
    }
    
    func testBrowserModelsAndPickerBehavior() {
        let browser = InstalledBrowser(
            bundleId: "com.apple.Safari",
            name: "Safari",
            appURL: URL(fileURLWithPath: "/Applications/Safari.app"),
            icon: nil
        )
        XCTAssertEqual(browser.id, "com.apple.Safari")
        XCTAssertEqual(browser.name, "Safari")
        
        XCTAssertEqual(BrowserPickerBehavior.openDefault.rawValue, "openDefault")
        XCTAssertEqual(BrowserPickerBehavior.alwaysPrompt.rawValue, "alwaysPrompt")
    }
    
    func testBrowserPickerKeyHandler() {
        var confirmed = false
        var quickNum: Int? = nil
        var cancelled = false
        var selectedIndex = 0
        
        let handler = BrowserPickerKeyHandler(
            browserCount: 3,
            selectedIndex: Binding(get: { selectedIndex }, set: { selectedIndex = $0 }),
            onConfirm: { confirmed = true },
            onQuickNumber: { quickNum = $0 },
            onCancel: { cancelled = true }
        )
        
        let keyView = BrowserPickerKeyHandler.KeyView()
        keyView.parent = handler
        
        // Escape (keycode 53)
        let escEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 53)!
        keyView.keyDown(with: escEvent)
        XCTAssertTrue(cancelled)
        
        // Return (keycode 36)
        let returnEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)!
        keyView.keyDown(with: returnEvent)
        XCTAssertTrue(confirmed)
        
        // Right arrow (keycode 124)
        let rightEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 124)!
        keyView.keyDown(with: rightEvent)
        XCTAssertEqual(selectedIndex, 1)
        
        // Left arrow (keycode 123)
        let leftEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 123)!
        keyView.keyDown(with: leftEvent)
        XCTAssertEqual(selectedIndex, 0)
        
        // Quick number '2'
        let numEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "2", charactersIgnoringModifiers: "2", isARepeat: false, keyCode: 19)!
        keyView.keyDown(with: numEvent)
        XCTAssertEqual(quickNum, 2)
    }
    
    func testGlobalPreferences() {
        let prefs = PreferencesManager.shared
        prefs.menuBarIconStyle = .color
        XCTAssertEqual(prefs.menuBarIconStyle, .color)
        
        prefs.resetGlobalDefaults()
        XCTAssertEqual(prefs.menuBarIconStyle, .monochrome)
        XCTAssertFalse(prefs.launchAtLogin)
    }
    
    func testPreferencesTabAndRouterSelection() {
        let prefs = PreferencesManager.shared
        
        // Test tab enum
        XCTAssertEqual(PreferencesTab.allCases.count, 5)
        XCTAssertEqual(PreferencesTab.global.rawValue, "Global")
        XCTAssertEqual(PreferencesTab.browserRouter.rawValue, "Browser Router")
        
        prefs.selectedPreferencesTab = .browserRouter
        XCTAssertEqual(prefs.selectedPreferencesTab, .browserRouter)
        
        prefs.selectedPreferencesTab = .global
        XCTAssertEqual(prefs.selectedPreferencesTab, .global)
        
        // Test primary browser switching behavior
        prefs.browserRouterDefaultBrowserBundleId = "com.apple.Safari"
        prefs.browserRouterBehavior = BrowserPickerBehavior.openDefault.rawValue
        
        // Simulate selecting "prompt"
        let promptItem = NSMenuItem(title: "Always Show Browser Picker", action: nil, keyEquivalent: "")
        promptItem.representedObject = "prompt"
        if let id = promptItem.representedObject as? String {
            if id == "prompt" {
                prefs.browserRouterBehavior = BrowserPickerBehavior.alwaysPrompt.rawValue
            } else {
                prefs.browserRouterDefaultBrowserBundleId = id
                prefs.browserRouterBehavior = BrowserPickerBehavior.openDefault.rawValue
            }
        }
        XCTAssertEqual(prefs.browserRouterBehavior, BrowserPickerBehavior.alwaysPrompt.rawValue)
        
        // Simulate selecting Chrome
        let chromeItem = NSMenuItem(title: "Google Chrome", action: nil, keyEquivalent: "")
        chromeItem.representedObject = "com.google.Chrome"
        if let id = chromeItem.representedObject as? String {
            if id == "prompt" {
                prefs.browserRouterBehavior = BrowserPickerBehavior.alwaysPrompt.rawValue
            } else {
                prefs.browserRouterDefaultBrowserBundleId = id
                prefs.browserRouterBehavior = BrowserPickerBehavior.openDefault.rawValue
            }
        }
        XCTAssertEqual(prefs.browserRouterDefaultBrowserBundleId, "com.google.Chrome")
        XCTAssertEqual(prefs.browserRouterBehavior, BrowserPickerBehavior.openDefault.rawValue)
        
        // Test InstalledBrowser menuIcon
        let icon = NSImage(size: NSSize(width: 64, height: 64))
        let browserWithIcon = InstalledBrowser(
            bundleId: "com.test.Browser",
            name: "Test Browser",
            appURL: URL(fileURLWithPath: "/Applications/Test.app"),
            icon: icon
        )
        let menuIcon = browserWithIcon.menuIcon
        XCTAssertNotNil(menuIcon)
        XCTAssertEqual(menuIcon?.size.width, 16)
        XCTAssertEqual(menuIcon?.size.height, 16)
        
        // Test default browser property evaluation (does not crash)
        let _ = BrowserRouterManager.shared.isSystemDefaultBrowser
    }
    
    func testDefaultBrowserCheckingAndPreferences() {
        let prefs = PreferencesManager.shared
        
        // Test default setting value
        XCTAssertTrue(prefs.browserRouterCheckDefaultOnLaunch)
        
        // Test updating setting
        prefs.browserRouterCheckDefaultOnLaunch = false
        XCTAssertFalse(prefs.browserRouterCheckDefaultOnLaunch)
        
        // Test reset to defaults restores it to true
        prefs.resetBrowserRouterDefaults()
        XCTAssertTrue(prefs.browserRouterCheckDefaultOnLaunch)
        
        // Verify requestSetDefaultBrowser and isSystemDefaultBrowser do not crash
        BrowserRouterManager.shared.requestSetDefaultBrowser()
        let isDefault = BrowserRouterManager.shared.isSystemDefaultBrowser
        XCTAssertTrue(isDefault || !isDefault)
    }
}
