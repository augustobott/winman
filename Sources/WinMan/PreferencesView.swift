import SwiftUI
import AppKit

public struct PreferencesView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @ObservedObject var router = BrowserRouterManager.shared
    @State private var newRulePattern: String = ""
    @State private var newRuleTarget: String = "prompt"
    
    public init() {}
    
    public var body: some View {
        TabView {
            globalTab
                .tabItem { Text("Global") }
            moveResizeTab
                .tabItem { Text("Move & Resize") }
            snapTab
                .tabItem { Text("Snapping") }
            altTab
                .tabItem { Text("Alt-Tab") }
            browserRouterTab
                .tabItem { Text("Browser Router") }
        }
        .padding()
        .frame(width: 580, height: 620)
    }
    
    private var globalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack {
                    Text("Global Settings")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                
                Text("Manage system startup, menu bar appearance, and general application behavior.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                Divider()
                
                // Startup
                VStack(alignment: .leading, spacing: 10) {
                    Text("System Startup")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Toggle("Start WinMan automatically at login", isOn: Binding(
                        get: { prefs.launchAtLogin },
                        set: { prefs.setLaunchAtLogin($0) }
                    ))
                    .toggleStyle(.checkbox)
                    
                    Text("Launches WinMan in the background as a menu bar item when you log into your Mac.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                
                // Menu Bar Icon Style
                VStack(alignment: .leading, spacing: 10) {
                    Text("Menu Bar Icon Style")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Picker("Icon Style:", selection: $prefs.menuBarIconStyle) {
                        ForEach(MenuBarIconStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    
                    Text(prefs.menuBarIconStyle == .monochrome
                         ? "Monochrome icon blends into macOS Tahoe / Sequoia menu bar and adapts to Dark & Light mode automatically."
                         : "Displays the vibrant, colorful application icon in the menu bar.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                
                // System Permissions Status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Permissions Status")
                        .font(.system(size: 14, weight: .semibold))
                    
                    HStack {
                        Image(systemName: AccessibilityManager.shared.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(AccessibilityManager.shared.isTrusted ? .green : .orange)
                        Text("Accessibility:")
                            .font(.subheadline)
                        Text(AccessibilityManager.shared.isTrusted ? "Enabled" : "Required for Window Management")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if !AccessibilityManager.shared.isTrusted {
                            Button("Open Settings") {
                                AccessibilityManager.shared.openAccessibilityPreferences()
                            }
                            .controlSize(.small)
                        }
                    }
                    
                    HStack {
                        Image(systemName: ScreenRecordingManager.shared.isGranted ? "checkmark.circle.fill" : "info.circle.fill")
                            .foregroundColor(ScreenRecordingManager.shared.isGranted ? .green : .secondary)
                        Text("Screen Recording:")
                            .font(.subheadline)
                        Text(ScreenRecordingManager.shared.isGranted ? "Enabled" : "Optional (Alt-Tab previews)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if !ScreenRecordingManager.shared.isGranted {
                            Button("Open Settings") {
                                ScreenRecordingManager.shared.openScreenRecordingPreferences()
                            }
                            .controlSize(.small)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                
                // Version & Reset
                HStack {
                    Text("WinMan v2.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Reset Global Defaults") {
                        prefs.resetGlobalDefaults()
                    }
                    .controlSize(.small)
                }
            }
            .padding(20)
        }
    }
    
    private var moveResizeTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack {
                    Text("Easy Move & Resize")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                
                Text("Customize the modifier keys used to drag and resize windows under your mouse cursor.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                Divider()
                
                // Modifier Keys Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Move Window Modifiers")
                        .font(.system(size: 14, weight: .semibold))
                    
                    HStack(spacing: 20) {
                        Toggle("⌘ Command", isOn: $prefs.moveCmd)
                        Toggle("⌃ Control", isOn: $prefs.moveCtrl)
                        Toggle("⌥ Option", isOn: $prefs.moveOpt)
                        Toggle("⇧ Shift", isOn: $prefs.moveShift)
                    }
                    .toggleStyle(.checkbox)
                    
                    HStack(spacing: 10) {
                        Text("Presets:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("⌥ + ⌘") {
                            prefs.setPreset(cmd: true, ctrl: false, opt: true, shift: false)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("⌃ + ⌥") {
                            prefs.setPreset(cmd: false, ctrl: true, opt: true, shift: false)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("⌘ + ⌃ (Default)") {
                            prefs.setPreset(cmd: true, ctrl: true, opt: false, shift: false)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                
                // Resize Triggers
                VStack(alignment: .leading, spacing: 10) {
                    Text("Resize Window Gestures")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Toggle("Right-Click & Drag with Move Modifiers", isOn: $prefs.resizeWithRightClick)
                        .toggleStyle(.checkbox)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                
                // Status Summary
                HStack {
                    Text("Active Gesture:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(prefs.displayString) + Click & Drag")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.15)))
                    
                    Spacer()
                    
                    Button("Reset Defaults") {
                        prefs.resetMoveResizeDefaults()
                    }
                    .controlSize(.small)
                }
            }
            .padding(20)
        }
    }
    
    private var snapTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack {
                    Text("Snapping & Resizing")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                
                Text("Customize the hotkeys used to snap and resize windows.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                Divider()
                
                // Snap Hotkey Modifiers
                VStack(alignment: .leading, spacing: 10) {
                    Text("Snap Window Modifiers")
                        .font(.system(size: 14, weight: .semibold))
                    
                    HStack(spacing: 20) {
                        Toggle("⌘ Command", isOn: $prefs.snapCmd)
                        Toggle("⌃ Control", isOn: $prefs.snapCtrl)
                        Toggle("⌥ Option", isOn: $prefs.snapOpt)
                        Toggle("⇧ Shift", isOn: $prefs.snapShift)
                    }
                    .toggleStyle(.checkbox)
                    
                    Divider()
                    
                    Text("Customize the base key for each snap action. Modifiers apply to all keys.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(WindowAction.allCases, id: \.self) { action in
                            HStack {
                                Text(action.rawValue)
                                    .font(.caption)
                                Spacer()
                                
                                let binding = Binding<UInt16>(
                                    get: { prefs.snapBindings[action.rawValue] ?? 0 },
                                    set: { prefs.snapBindings[action.rawValue] = $0 }
                                )
                                
                                Picker("", selection: binding) {
                                    Text("Enter").tag(UInt16(36))
                                    Text("Backspace").tag(UInt16(51))
                                    Text("Left Arrow").tag(UInt16(123))
                                    Text("Right Arrow").tag(UInt16(124))
                                    Text("Up Arrow").tag(UInt16(126))
                                    Text("Down Arrow").tag(UInt16(125))
                                    Text("C").tag(UInt16(8))
                                    Text("D").tag(UInt16(2))
                                    Text("E").tag(UInt16(14))
                                    Text("F").tag(UInt16(3))
                                    Text("G").tag(UInt16(5))
                                    Text("H").tag(UInt16(4))
                                    Text("I").tag(UInt16(34))
                                    Text("J").tag(UInt16(38))
                                    Text("K").tag(UInt16(40))
                                    Text("M").tag(UInt16(46))
                                    Text("Q").tag(UInt16(12))
                                    Text("R").tag(UInt16(15))
                                    Text("T").tag(UInt16(17))
                                    Text("U").tag(UInt16(32))
                                    Text("W").tag(UInt16(13))
                                    Text("-").tag(UInt16(27))
                                    Text("=").tag(UInt16(24))
                                    Text("[").tag(UInt16(33))
                                    Text("]").tag(UInt16(30))
                                }
                                .frame(width: 100)
                                .labelsHidden()
                            }
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                
                HStack {
                    Spacer()
                    Button("Reset Defaults") {
                        prefs.resetSnapDefaults()
                    }
                    .controlSize(.small)
                }
            }
            .padding(20)
        }
    }
    
    private var altTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack {
                    Text("Alt-Tab Window Switcher")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                
                Text("Customize the fast application switcher.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                Divider()
                
                // Alt-Tab Window Switcher
                VStack(alignment: .leading, spacing: 10) {
                    Text("Alt-Tab Window Switcher (⌥⇥)")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Toggle("Enable Alt-Tab Window Switcher (⌥⇥)", isOn: $prefs.altTabEnabled)
                        .toggleStyle(.checkbox)
                    
                    if prefs.altTabEnabled {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("Show Windows From:", selection: $prefs.altTabScope) {
                                ForEach(AltTabScope.allCases) { scope in
                                    Text(scope.rawValue).tag(scope)
                                }
                            }
                            
                            Picker("Thumbnail Size:", selection: $prefs.altTabThumbnailSize) {
                                ForEach(AltTabThumbnailSize.allCases) { size in
                                    Text(size.rawValue).tag(size)
                                }
                            }
                            
                            Divider().padding(.vertical, 2)
                            
                            Toggle("Show Live Window Thumbnails", isOn: $prefs.altTabShowThumbnails)
                                .toggleStyle(.checkbox)
                                .onChange(of: prefs.altTabShowThumbnails) { enabled in
                                    if enabled {
                                        // Shows system prompt; falls back to NSAlert + System
                                        // Settings if the prompt is suppressed (LSUIElement apps).
                                        ScreenRecordingManager.shared.requestIfNeeded()
                                    }
                                }
                            
                            if prefs.altTabShowThumbnails && !ScreenRecordingManager.shared.isGranted {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Screen Recording permission required for thumbnails.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Button("Open Settings") {
                                        ScreenRecordingManager.shared.openScreenRecordingPreferences()
                                    }
                                    .font(.caption)
                                    .buttonStyle(.link)
                                }
                                .padding(.leading, 20)
                            }
                            
                            Toggle("Live Search in Switcher (Type to filter)", isOn: $prefs.altTabEnableSearch)
                                .toggleStyle(.checkbox)
                            
                            Toggle("Direct 1-9 Quick Jump Numbers", isOn: $prefs.altTabEnableQuickNumbers)
                                .toggleStyle(.checkbox)
                        }
                        .padding(.leading, 18)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                
                HStack {
                    Spacer()
                    Button("Reset Defaults") {
                        prefs.resetAltTabDefaults()
                    }
                    .controlSize(.small)
                }
            }
            .padding(20)
        }
    }
    
    private var browserRouterTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack {
                    Text("Browser Router")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                
                Text("Route URLs to different browsers automatically based on domain patterns, or show a quick browser picker HUD.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                Divider()
                
                // Main toggle & General Settings
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Browser Router", isOn: $prefs.browserRouterEnabled)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 14, weight: .semibold))
                    
                    if prefs.browserRouterEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            // Primary Browser
                            HStack {
                                Text("Primary Browser:")
                                    .font(.subheadline)
                                Spacer()
                                Picker("", selection: $prefs.browserRouterDefaultBrowserBundleId) {
                                    ForEach(router.installedBrowsers) { browser in
                                        Label {
                                            Text(browser.name)
                                        } icon: {
                                            if let icon = browser.menuIcon {
                                                Image(nsImage: icon)
                                            } else {
                                                Image(systemName: "globe")
                                            }
                                        }
                                        .tag(browser.bundleId)
                                    }
                                }
                                .frame(width: 200)
                                .labelsHidden()
                            }
                            
                            // General Behavior
                            HStack {
                                Text("Default Action:")
                                    .font(.subheadline)
                                Spacer()
                                Picker("", selection: $prefs.browserRouterBehavior) {
                                    Text("Open in Primary Browser").tag(BrowserPickerBehavior.openDefault.rawValue)
                                    Text("Always Show Browser Picker").tag(BrowserPickerBehavior.alwaysPrompt.rawValue)
                                }
                                .frame(width: 220)
                                .labelsHidden()
                            }
                            
                            Divider()
                            
                            Toggle("Hold ⌥ Option when clicking link to show Browser Picker", isOn: $prefs.browserRouterOptionKeyPrompts)
                                .toggleStyle(.checkbox)
                            
                            Toggle("Remove tracking parameters (utm_*, fbclid, gclid, etc.)", isOn: $prefs.browserRouterStripTracking)
                                .toggleStyle(.checkbox)
                        }
                        .padding(.leading, 18)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                
                // URL Routing Rules
                if prefs.browserRouterEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("URL Routing Rules")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text("\(prefs.browserRouterRules.count) rules")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Add domain or path patterns (e.g. *.google.com, github.com, zoom.us/j/) to direct specific links to a browser.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Add rule bar
                        HStack(spacing: 8) {
                            TextField("Domain or path (e.g. *.google.com)", text: $newRulePattern)
                                .textFieldStyle(.roundedBorder)
                            
                            Picker("", selection: $newRuleTarget) {
                                Label("Always Prompt", systemImage: "questionmark.app")
                                    .tag("prompt")
                                ForEach(router.installedBrowsers) { browser in
                                    Label {
                                        Text(browser.name)
                                    } icon: {
                                        if let icon = browser.menuIcon {
                                            Image(nsImage: icon)
                                        } else {
                                            Image(systemName: "globe")
                                        }
                                    }
                                    .tag(browser.bundleId)
                                }
                            }
                            .frame(width: 170)
                            .labelsHidden()
                            
                            Button("Add Rule") {
                                let pattern = newRulePattern.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !pattern.isEmpty {
                                    prefs.addBrowserRouterRule(pattern: pattern, targetBrowserBundleId: newRuleTarget)
                                    newRulePattern = ""
                                }
                            }
                            .disabled(newRulePattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.vertical, 4)
                        
                        // Rules list
                        if prefs.browserRouterRules.isEmpty {
                            Text("No routing rules configured yet.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 6) {
                                ForEach($prefs.browserRouterRules) { $rule in
                                    HStack {
                                        Toggle("", isOn: $rule.isEnabled)
                                            .toggleStyle(.checkbox)
                                            .labelsHidden()
                                        
                                        Text(rule.pattern)
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .foregroundColor(rule.isEnabled ? .primary : .secondary)
                                        
                                        Spacer()
                                        
                                        Picker("", selection: $rule.targetBrowserBundleId) {
                                            Label("Always Prompt", systemImage: "questionmark.app")
                                                .tag("prompt")
                                            ForEach(router.installedBrowsers) { browser in
                                                Label {
                                                    Text(browser.name)
                                                } icon: {
                                                    if let icon = browser.menuIcon {
                                                        Image(nsImage: icon)
                                                    } else {
                                                        Image(systemName: "globe")
                                                    }
                                                }
                                                .tag(browser.bundleId)
                                            }
                                        }
                                        .frame(width: 170)
                                        .labelsHidden()
                                        
                                        Button(action: {
                                            prefs.removeBrowserRouterRule(id: rule.id)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 11))
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.leading, 4)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.textBackgroundColor)))
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                }
                
                HStack {
                    Spacer()
                    Button("Reset Defaults") {
                        prefs.resetBrowserRouterDefaults()
                    }
                    .controlSize(.small)
                }
            }
            .padding(20)
        }
    }
}

@MainActor
public final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = PreferencesWindowController()
    
    private init() {
        let hostingView = NSHostingView(rootView: PreferencesView())
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "WinMan Preferences"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @MainActor
    public static var isPreferencesVisible: Bool {
        PreferencesWindowController.shared.window?.isVisible == true
    }

    @MainActor
    public static var preferencesWindowId: CGWindowID? {
        guard let win = PreferencesWindowController.shared.window else { return nil }
        return CGWindowID(win.windowNumber)
    }

    nonisolated public static func showPreferences() {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                PreferencesWindowController.shared.show()
            }
        } else {
            DispatchQueue.main.async {
                PreferencesWindowController.shared.show()
            }
        }
    }

    nonisolated public static func closePreferences() {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                PreferencesWindowController.shared.window?.performClose(nil)
            }
        } else {
            DispatchQueue.main.async {
                PreferencesWindowController.shared.window?.performClose(nil)
            }
        }
    }

    public func show() {
        guard let window = self.window, let contentView = window.contentView else { return }
        window.setContentSize(contentView.fittingSize)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        WindowFocusTracker.shared.recordFocus(windowId: CGWindowID(window.windowNumber))
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        if let window = self.window {
            WindowFocusTracker.shared.recordFocus(windowId: CGWindowID(window.windowNumber))
        }
    }

    public func windowWillClose(_ notification: Notification) {
        if let window = self.window {
            WindowFocusTracker.shared.removeWindow(windowId: CGWindowID(window.windowNumber))
        }
        UserDefaults.standard.synchronize()
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    }
}
