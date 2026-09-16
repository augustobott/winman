import Foundation
import AppKit

import Combine

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
        public func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == statusItem?.menu {
            rebuildMenu()
        }
    }
    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        
        let trusted = AccessibilityManager.shared.checkAndPrompt()
        
        // NOTE: Screen Recording permission is requested inside startEngines(),
        // which is only called once Accessibility is confirmed granted.
        // This ensures the two system permission prompts never appear simultaneously.
        
        // Handle sleep/wake cycles which can silently invalidate CGEvent taps
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWakeNotification),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccessibilityRevoked),
            name: NSNotification.Name("AccessibilityRevoked"),
            object: nil
        )

        if trusted {
            startEngines()
        } else {
            print("[WinMan] Waiting for Accessibility permissions to be granted...")
            // Poll occasionally until granted
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AccessibilityManager.shared.isTrusted {
                    print("[WinMan] Accessibility permission granted!")
                    timer.invalidate()
                    Task { @MainActor [weak self] in
                        self?.permissionTimer = nil
                        self?.startEngines()
                        self?.rebuildMenu()
                    }
                }
            }
        }
    }
    
    @objc private func handleAccessibilityRevoked() {
        print("[WinMan] Accessibility revoked! Stopping engines...")
        stopEngines()
        
        // Start polling again so we recover if they re-grant it
        if permissionTimer == nil {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AccessibilityManager.shared.isTrusted {
                    print("[WinMan] Accessibility permission re-granted!")
                    timer.invalidate()
                    Task { @MainActor [weak self] in
                        self?.permissionTimer = nil
                        self?.startEngines()
                    }
                }
            }
        }
    }
    
    @objc private func handleWakeNotification() {
        print("[WinMan] System woke from sleep. Restarting engines...")
        // Give the window server a moment to settle before recreating event taps
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.stopEngines()
            if AccessibilityManager.shared.isTrusted {
                self.startEngines()
            }
        }
    }
    
    private func stopEngines() {
        WindowFocusTracker.shared.stop()
        EasyMoveResizeEngine.shared.stop()
        HotkeySnapEngine.shared.stop()
        AltTabEngine.shared.stop()
    }
    
    private func startEngines() {
        cancellables.removeAll()
        WindowFocusTracker.shared.start()
        
        let prefs = PreferencesManager.shared
        EasyMoveResizeEngine.shared.isEnabled = prefs.easyMoveResizeEnabled
        EasyMoveResizeEngine.shared.start()
        
        HotkeySnapEngine.shared.isEnabled = prefs.hotkeySnapEnabled
        HotkeySnapEngine.shared.start()
        
        AltTabEngine.shared.isEnabled = prefs.altTabEnabled
        AltTabEngine.shared.start()
        
        prefs.$easyMoveResizeEnabled.sink { enabled in
            EasyMoveResizeEngine.shared.isEnabled = enabled
        }.store(in: &cancellables)
        
        prefs.$hotkeySnapEnabled.sink { enabled in
            HotkeySnapEngine.shared.isEnabled = enabled
        }.store(in: &cancellables)
        
        prefs.$altTabEnabled.sink { enabled in
            AltTabEngine.shared.isEnabled = enabled
        }.store(in: &cancellables)
        
        // Request Screen Recording permission here — after Accessibility is confirmed granted —
        // so both system prompts never appear simultaneously. Defer by 1s so any Accessibility
        // prompt (or its TCC-triggered relaunch) has fully settled before the next dialog fires.
        if prefs.altTabShowThumbnails && !ScreenRecordingManager.shared.isGranted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ScreenRecordingManager.shared.requestIfNeeded()
            }
        }
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusBarIcon()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIconChanged),
            name: PreferencesManager.iconChangedNotification,
            object: nil
        )
        
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
        rebuildMenu()
    }
    
    @objc private func handleIconChanged() {
        updateStatusBarIcon()
        rebuildMenu()
    }
    
    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        let style = PreferencesManager.shared.menuBarIconStyle
        let icon = MenuBarIconManager.shared.icon(for: style)
        button.image = icon
        button.imagePosition = .imageOnly
        button.title = ""
        button.toolTip = "WinMan - Window Manager"
    }
    
    public func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
    
    private func rebuildMenu() {
        guard let menu = statusItem?.menu else { return }
        menu.removeAllItems()
        
        // Header
        let titleItem = NSMenuItem(title: "WinMan", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        // Permission Status — Accessibility
        let isTrusted = AccessibilityManager.shared.isTrusted
        if isTrusted {
            let permItem = NSMenuItem(title: "✓ Accessibility Enabled", action: nil, keyEquivalent: "")
            permItem.isEnabled = false
            menu.addItem(permItem)
        } else {
            let permItem = NSMenuItem(
                title: "⚠️ Accessibility Permission Required...",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            permItem.target = self
            menu.addItem(permItem)
        }
        
        // Permission Status — Screen Recording (only shown when thumbnails are on)
        if PreferencesManager.shared.altTabShowThumbnails {
            if ScreenRecordingManager.shared.isGranted {
                let srItem = NSMenuItem(title: "✓ Screen Recording Enabled", action: nil, keyEquivalent: "")
                srItem.isEnabled = false
                menu.addItem(srItem)
            } else {
                let srItem = NSMenuItem(
                    title: "⚠️ Screen Recording Required for Thumbnails...",
                    action: #selector(openScreenRecordingSettings),
                    keyEquivalent: ""
                )
                srItem.target = self
                menu.addItem(srItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Features toggles
        let prefs = PreferencesManager.shared
        let easyMoveItem = NSMenuItem(
            title: "Easy Move & Resize (\(prefs.shortDisplayString) Drag)",
            action: #selector(toggleEasyMoveResize),
            keyEquivalent: ""
        )
        easyMoveItem.target = self
        easyMoveItem.state = prefs.easyMoveResizeEnabled ? .on : .off
        menu.addItem(easyMoveItem)
        
        // Modifiers Submenu
        let modMenu = NSMenu()
        let p1 = NSMenuItem(title: "⌘ + ⌃ (Cmd + Ctrl)", action: #selector(setPresetCmdCtrl), keyEquivalent: "")
        p1.target = self
        p1.state = (prefs.moveCmd && prefs.moveCtrl && !prefs.moveOpt && !prefs.moveShift) ? .on : .off
        modMenu.addItem(p1)
        
        let p2 = NSMenuItem(title: "⌥ + ⌘ (Option + Cmd)", action: #selector(setPresetOptCmd), keyEquivalent: "")
        p2.target = self
        p2.state = (prefs.moveCmd && !prefs.moveCtrl && prefs.moveOpt && !prefs.moveShift) ? .on : .off
        modMenu.addItem(p2)
        
        let p3 = NSMenuItem(title: "⌃ + ⌥ (Control + Option)", action: #selector(setPresetCtrlOpt), keyEquivalent: "")
        p3.target = self
        p3.state = (!prefs.moveCmd && prefs.moveCtrl && prefs.moveOpt && !prefs.moveShift) ? .on : .off
        modMenu.addItem(p3)
        
        modMenu.addItem(NSMenuItem.separator())
        let customizeItem = NSMenuItem(title: "Configure Modifiers...", action: #selector(openPreferences), keyEquivalent: "")
        customizeItem.target = self
        modMenu.addItem(customizeItem)
        
        let modSubmenuItem = NSMenuItem(title: "  Modifiers: \(prefs.displayString)", action: nil, keyEquivalent: "")
        modSubmenuItem.submenu = modMenu
        menu.addItem(modSubmenuItem)
        
        let hotkeysItem = NSMenuItem(
            title: "Hotkey Snapping (⌃⌥ Keys)",
            action: #selector(toggleHotkeys),
            keyEquivalent: ""
        )
        hotkeysItem.target = self
        hotkeysItem.state = prefs.hotkeySnapEnabled ? .on : .off
        menu.addItem(hotkeysItem)
        
        let altTabItem = NSMenuItem(
            title: "Alt-Tab Switcher (⌥⇥)",
            action: #selector(toggleAltTab),
            keyEquivalent: ""
        )
        altTabItem.target = self
        altTabItem.state = prefs.altTabEnabled ? .on : .off
        menu.addItem(altTabItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quick Actions Submenu
        let actionsItem = NSMenuItem(title: "Window Actions", action: nil, keyEquivalent: "")
        let actionsSubmenu = NSMenu()
        
        for binding in HotkeySnapEngine.shared.bindings {
            let actionItem = NSMenuItem(
                title: "\(binding.action.rawValue) (\(binding.displayString))",
                action: #selector(performMenuAction(_:)),
                keyEquivalent: ""
            )
            actionItem.target = self
            actionItem.representedObject = binding.action
            actionsSubmenu.addItem(actionItem)
        }
        
        actionsItem.submenu = actionsSubmenu
        menu.addItem(actionsItem)
        
        // Menu Bar Icon Submenu
        let iconSubmenu = NSMenu()
        let monoItem = NSMenuItem(title: "Monochrome (macOS Tahoe)", action: #selector(setIconMonochrome), keyEquivalent: "")
        monoItem.target = self
        monoItem.state = (prefs.menuBarIconStyle == .monochrome) ? .on : .off
        iconSubmenu.addItem(monoItem)
        
        let colorItem = NSMenuItem(title: "Vibrant Color", action: #selector(setIconColor), keyEquivalent: "")
        colorItem.target = self
        colorItem.state = (prefs.menuBarIconStyle == .color) ? .on : .off
        iconSubmenu.addItem(colorItem)
        
        let iconMenuItem = NSMenuItem(title: "Menu Bar Icon", action: nil, keyEquivalent: "")
        iconMenuItem.submenu = iconSubmenu
        menu.addItem(iconMenuItem)
        
        // Preferences Window
        let prefItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefItem.target = self
        menu.addItem(prefItem)
        
        // Shortcuts Guide
        let guideItem = NSMenuItem(
            title: "Shortcuts & Mouse Gestures...",
            action: #selector(showShortcutsGuide),
            keyEquivalent: ""
        )
        guideItem.target = self
        menu.addItem(guideItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit WinMan",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @objc private func openAccessibilitySettings() {
        AccessibilityManager.shared.openAccessibilityPreferences()
        AccessibilityManager.shared.checkAndPrompt()
    }
    
    @objc private func openScreenRecordingSettings() {
        // The menu item only appears when permission is NOT granted.
        // At this point the TCC dialog has already been shown (and dismissed/denied),
        // so calling CGRequestScreenCaptureAccess() again would be silently ignored.
        // Instead, show an NSAlert with instructions and open System Settings directly.
        ScreenRecordingManager.shared.showManualPermissionAlert()
    }
    
    @objc private func toggleEasyMoveResize() {
        PreferencesManager.shared.easyMoveResizeEnabled.toggle()
    }
    
    @objc private func toggleHotkeys() {
        PreferencesManager.shared.hotkeySnapEnabled.toggle()
    }
    
    @objc private func toggleAltTab() {
        PreferencesManager.shared.altTabEnabled.toggle()
    }
    
    @objc private func performMenuAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? WindowAction else { return }
        HotkeySnapEngine.shared.execute(action: action)
    }
    
    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }
    
    @objc private func setPresetCmdCtrl() {
        PreferencesManager.shared.setPreset(cmd: true, ctrl: true, opt: false, shift: false)
        rebuildMenu()
    }
    
    @objc private func setPresetOptCmd() {
        PreferencesManager.shared.setPreset(cmd: true, ctrl: false, opt: true, shift: false)
        rebuildMenu()
    }
    
    @objc private func setPresetCtrlOpt() {
        PreferencesManager.shared.setPreset(cmd: false, ctrl: true, opt: true, shift: false)
        rebuildMenu()
    }
    
    @objc private func setIconMonochrome() {
        PreferencesManager.shared.menuBarIconStyle = .monochrome
    }
    
    @objc private func setIconColor() {
        PreferencesManager.shared.menuBarIconStyle = .color
    }
    
    @objc private func showShortcutsGuide() {
        let prefs = PreferencesManager.shared
        let modStr = prefs.displayString
        let alert = NSAlert()
        alert.messageText = "WinMan Quick Reference"
        alert.informativeText = """
        ALT-TAB WINDOW SWITCHER:
        • ⌥⇥ (Hold Option, press Tab): Open switcher overlay & cycle windows
        • ⇧⌥⇥ : Cycle backwards | Arrow keys: Navigate grid
        • Release Option : Focus and bring selected window to front
        • 1-9 : Direct jump to window by index
        • Type letters : Live search & filter open windows
        • W : Close window | M : Minimize | F : Fullscreen | Q : Quit app | Esc : Cancel
        
        MOUSE GESTURES (Easy-Move-Resize):
        • \(modStr) + Left-Click & Drag: Move window under mouse
        • \(modStr) + Right-Click & Drag: Resize window from nearest edge/corner
        • \(modStr) + ⇧ + Left-Click & Drag: Resize window (trackpad-friendly)
        
        KEYBOARD SHORTCUTS (Rectangle Snapping):
        • ⌃⌥↵ or ⌥⌘F : Maximize window
        • ⌃⌥⌫ or ⌥⌘R : Restore previous window size
        • ⌃⌥← / ⌃⌥→ : Left / Right half
        • ⌃⌥↑ / ⌃⌥↓ : Top / Bottom half
        • ⌃⌥U / ⌃⌥I : Top-Left / Top-Right quarter
        • ⌃⌥J / ⌃⌥K : Bottom-Left / Bottom-Right quarter
        • ⌃⌥D / ⌃⌥E / ⌃⌥F : Left / Center / Right third
        • ⌃⌥G / ⌃⌥T : Left / Right two-thirds
        • ⌃⌥C : Center window
        • ⌃⌥+ / ⌃⌥- : Make larger / smaller
        • ⌃⌥⌘→ / ⌃⌥⌘← : Move to next / previous display
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private var isIntentionalQuit = false

    @objc private func quitApp() {
        isIntentionalQuit = true
        NSApplication.shared.terminate(nil)
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        if !isIntentionalQuit {
            // Workaround for macOS TCC "Quit & Reopen" bug with LSUIElement apps.
            // If the system (TCC) terminates us to apply Screen Recording permissions,
            // we spawn a detached shell process to ensure we relaunch after a brief delay.
            let bundlePath = Bundle.main.bundlePath
            let script = "sleep 0.5; open \"$1\""
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", script, "--", bundlePath]
            try? process.run()
        }
    }
}
