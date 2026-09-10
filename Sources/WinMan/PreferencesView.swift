import SwiftUI
import AppKit

public struct PreferencesView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                Text("WinMan Preferences")
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
                    
                    Button("⌥ + ⌘ (Default)") {
                        prefs.setPreset(cmd: true, ctrl: false, opt: true, shift: false)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("⌃ + ⌥") {
                        prefs.setPreset(cmd: false, ctrl: true, opt: true, shift: false)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("⌘ + ⌃") {
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
                
                Toggle("⇧ Shift + Left-Click & Drag (Trackpad-friendly)", isOn: $prefs.resizeWithShift)
                    .toggleStyle(.checkbox)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
            
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
                    prefs.setPreset(cmd: true, ctrl: true, opt: false, shift: false)
                    prefs.resizeWithRightClick = true
                    prefs.resizeWithShift = true
                    prefs.menuBarIconStyle = .monochrome
                    prefs.altTabEnabled = true
                    prefs.altTabShowThumbnails = true
                    prefs.altTabEnableSearch = true
                    prefs.altTabEnableQuickNumbers = true
                    prefs.altTabScope = .allSpaces
                    prefs.altTabThumbnailSize = .medium
                }
                .controlSize(.small)
            }
            
            Spacer()
        }
        .padding(20)
        .frame(width: 530, height: 660)
    }
}

public final class PreferencesWindowController: NSWindowController {
    public static let shared = PreferencesWindowController()
    
    private init() {
        let hostingView = NSHostingView(rootView: PreferencesView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 530, height: 660),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "WinMan Preferences"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func show() {
        guard let window = self.window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
