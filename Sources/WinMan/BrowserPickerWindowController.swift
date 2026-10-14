import Foundation
import AppKit
import SwiftUI

@MainActor
public final class BrowserPickerWindowController: NSObject {
    public static let shared = BrowserPickerWindowController()
    
    private var window: NSPanel?
    private var currentURL: URL?
    
    public static func show(for url: URL) {
        shared.present(for: url)
    }
    
    public static func close() {
        shared.dismiss()
    }
    
    private func present(for url: URL) {
        self.currentURL = url
        
        let manager = BrowserRouterManager.shared
        manager.refreshInstalledBrowsers()
        
        let pickerView = BrowserPickerView(url: url) { [weak self] selectedBundleId in
            self?.dismiss()
            if let targetId = selectedBundleId {
                BrowserRouterManager.shared.open(url: url, in: targetId)
            }
        }
        
        let hostingView = NSHostingView(rootView: pickerView)
        
        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 200),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true
            self.window = panel
        }
        
        guard let window = self.window else { return }
        window.contentView = hostingView
        
        let mouseLoc = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSPointInRect(mouseLoc, $0.frame) } ?? NSScreen.main
        
        if let screen = targetScreen {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - (480 / 2)
            let y = screenFrame.midY - (200 / 2)
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func dismiss() {
        window?.orderOut(nil)
        currentURL = nil
    }
}

public struct BrowserPickerView: View {
    public let url: URL
    public let onSelect: (String?) -> Void
    
    @ObservedObject private var manager = BrowserRouterManager.shared
    @State private var selectedIndex: Int = 0
    
    public init(url: URL, onSelect: @escaping (String?) -> Void) {
        self.url = url
        self.onSelect = onSelect
    }
    
    private var browsers: [InstalledBrowser] {
        manager.installedBrowsers
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // URL Header
            HStack(spacing: 8) {
                Image(systemName: "safari.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(url.host ?? url.absoluteString)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { onSelect(nil) }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // Browsers list / grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(browsers.prefix(9).enumerated()), id: \.element.bundleId) { index, browser in
                        BrowserTileView(
                            browser: browser,
                            index: index,
                            isSelected: selectedIndex == index
                        )
                        .onTapGesture {
                            onSelect(browser.bundleId)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
            
            // Footer Shortcut Guide
            HStack {
                Text("Press 1–\(min(browsers.count, 9)) or click to open • Esc to cancel")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(18)
        .frame(minWidth: 420, maxWidth: 580)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        )
        .onAppear {
            let defaultId = PreferencesManager.shared.browserRouterDefaultBrowserBundleId
            if let idx = browsers.firstIndex(where: { $0.bundleId == defaultId }) {
                selectedIndex = idx
            }
        }
        .background(
            BrowserPickerKeyHandler(
                browserCount: min(browsers.count, 9),
                selectedIndex: $selectedIndex,
                onConfirm: {
                    if selectedIndex < browsers.count {
                        onSelect(browsers[selectedIndex].bundleId)
                    }
                },
                onQuickNumber: { number in
                    let idx = number - 1
                    if idx < browsers.count {
                        onSelect(browsers[idx].bundleId)
                    }
                },
                onCancel: {
                    onSelect(nil)
                }
            )
        )
    }
}

struct BrowserTileView: View {
    let browser: InstalledBrowser
    let index: Int
    let isSelected: Bool
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                if let icon = browser.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "globe")
                        .resizable()
                        .frame(width: 44, height: 44)
                        .foregroundColor(.accentColor)
                }
                
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
                    .offset(x: 4, y: -4)
            }
            
            Text(browser.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .frame(width: 68)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.20) : (isHovered ? Color.primary.opacity(0.08) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

public struct BrowserPickerKeyHandler: NSViewRepresentable {
    public let browserCount: Int
    @Binding public var selectedIndex: Int
    public let onConfirm: () -> Void
    public let onQuickNumber: (Int) -> Void
    public let onCancel: () -> Void
    
    public init(browserCount: Int, selectedIndex: Binding<Int>, onConfirm: @escaping () -> Void, onQuickNumber: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        self.browserCount = browserCount
        self._selectedIndex = selectedIndex
        self.onConfirm = onConfirm
        self.onQuickNumber = onQuickNumber
        self.onCancel = onCancel
    }
    
    public func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.parent = self
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    
    public func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.parent = self
    }
    
    public class KeyView: NSView {
        var parent: BrowserPickerKeyHandler?
        
        public override var acceptsFirstResponder: Bool { true }
        
        public override func keyDown(with event: NSEvent) {
            guard let parent = self.parent else {
                super.keyDown(with: event)
                return
            }
            
            switch event.keyCode {
            case 53: // Esc
                parent.onCancel()
            case 36, 76: // Enter / Return
                parent.onConfirm()
            case 123: // Left Arrow
                if parent.selectedIndex > 0 {
                    parent.selectedIndex -= 1
                }
            case 124: // Right Arrow
                if parent.selectedIndex < parent.browserCount - 1 {
                    parent.selectedIndex += 1
                }
            default:
                if let chars = event.characters, let num = Int(chars), num >= 1, num <= parent.browserCount {
                    parent.onQuickNumber(num)
                } else {
                    super.keyDown(with: event)
                }
            }
        }
    }
}
