import Foundation
import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var permissionTimer: Timer?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        
        let trusted = AccessibilityManager.shared.checkAndPrompt()
        if trusted {
            startEngines()
        } else {
            print("[WinMan] Waiting for Accessibility permissions to be granted...")
            // Poll occasionally until granted
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AccessibilityManager.shared.isTrusted {
                    print("[WinMan] Accessibility permission granted!")
                    self?.startEngines()
                    self?.rebuildMenu()
                    timer.invalidate()
                    self?.permissionTimer = nil
                }
            }
        }
    }
    
    private func startEngines() {
        WindowFocusTracker.shared.start()
        
        let prefs = PreferencesManager.shared
        EasyMoveResizeEngine.shared.isEnabled = prefs.easyMoveResizeEnabled
        EasyMoveResizeEngine.shared.start()
        
        HotkeySnapEngine.shared.isEnabled = prefs.hotkeySnapEnabled
        HotkeySnapEngine.shared.start()
        
        AltTabEngine.shared.isEnabled = prefs.altTabEnabled
        AltTabEngine.shared.start()
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
        statusItem.menu = menu
        rebuildMenu()
    }
    
    @objc private func handleIconChanged() {
        updateStatusBarIcon()
        rebuildMenu()
    }
    
    private func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }
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
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()
        
        // Header
        let titleItem = NSMenuItem(title: "WinMan", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        // Permission Status
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
    
    @objc private func toggleEasyMoveResize() {
        PreferencesManager.shared.easyMoveResizeEnabled.toggle()
        rebuildMenu()
    }
    
    @objc private func toggleHotkeys() {
        PreferencesManager.shared.hotkeySnapEnabled.toggle()
        rebuildMenu()
    }
    
    @objc private func toggleAltTab() {
        PreferencesManager.shared.altTabEnabled.toggle()
        rebuildMenu()
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
    
    @objc private func quitApp() {
        UserDefaults.standard.synchronize()
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        NSApplication.shared.terminate(nil)
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        UserDefaults.standard.synchronize()
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    }
}
