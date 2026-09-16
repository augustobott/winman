import SwiftUI
import AppKit

public struct PreferencesView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    
    public init() {}
    
        public var body: some View {
        TabView {
            moveResizeTab
                .tabItem { Text("Move & Resize") }
            snapTab
                .tabItem { Text("Snapping") }
            altTab
                .tabItem { Text("Alt-Tab") }
        }
        .padding()
        .frame(width: 550, height: 600)
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
