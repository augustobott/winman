import Foundation
import AppKit
import SwiftUI

public final class SwitcherOverlayController: ObservableObject {
    public static let shared = SwitcherOverlayController()
    
    @Published public var windows: [SwitcherWindowInfo] = []
    @Published public var selectedIndex: Int = 0
    @Published public var searchQuery: String = ""
    @Published public var showQuickNumbers: Bool = true
    @Published public var thumbnailSize: AltTabThumbnailSize = .medium
    @Published public var currentColumnCount: Int = 5
    
    private var panel: NSPanel?
    
    private init() {
        setupPanel()
    }
    
    private func setupPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovableByWindowBackground = false
        
        let hostingView = NSHostingView(rootView: SwitcherOverlayView(controller: self))
        p.contentView = hostingView
        self.panel = p
    }
    
    public func present(windows: [SwitcherWindowInfo], selectedIndex: Int = 0, showNumbers: Bool = true) {
        self.windows = windows
        self.selectedIndex = selectedIndex
        self.searchQuery = ""
        self.showQuickNumbers = showNumbers
        self.thumbnailSize = PreferencesManager.shared.altTabThumbnailSize

        guard let p = panel else { return }

        // Use the screen containing the mouse cursor — this is the standard macOS
        // way to find the display the user is actively working on. It requires no
        // AX calls and is always correct at hotkey-press time.
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
                     ?? NSScreen.main
        guard let screen else { return }
        let screenFrame = screen.visibleFrame

        let tSize = PreferencesManager.shared.altTabThumbnailSize
        let tileW = tSize.tileWidth
        let tileH = tSize.previewHeight + 56
        let spacing: CGFloat = 14
        let padding: CGFloat = 28
        let headerHeight: CGFloat = 40
        let footerHeight: CGFloat = 36

        // Calculate optimal columns and rows for available screen space
        let maxColsForScreen = max(4, Int(floor((screenFrame.width * 0.92 - padding * 2) / (tileW + spacing))))
        let count = max(1, windows.count)

        let columns: Int
        if count <= 6 {
            columns = count
        } else if count <= 12 {
            columns = min(maxColsForScreen, 6)
        } else if count <= 21 {
            columns = min(maxColsForScreen, 7)
        } else {
            columns = min(maxColsForScreen, 8)
        }
        self.currentColumnCount = columns

        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        let maxVisibleRows = max(1, Int(floor((screenFrame.height * 0.85 - padding * 2 - headerHeight - footerHeight) / (tileH + spacing))))
        let visibleRows = min(rows, maxVisibleRows)

        let calculatedWidth = CGFloat(columns) * tileW + CGFloat(columns - 1) * spacing + padding * 2
        let calculatedHeight = CGFloat(visibleRows) * tileH + CGFloat(visibleRows - 1) * spacing + padding * 2 + headerHeight + footerHeight

        let targetWidth = min(screenFrame.width * 0.94, max(560, calculatedWidth))
        let targetHeight = min(screenFrame.height * 0.88, max(260, calculatedHeight))

        let originX = screenFrame.origin.x + (screenFrame.width - targetWidth) / 2
        let originY = screenFrame.origin.y + (screenFrame.height - targetHeight) / 2

        p.setFrame(NSRect(x: originX, y: originY, width: targetWidth, height: targetHeight), display: true)
        p.orderFrontRegardless()
    }


    public func dismiss() {
        panel?.orderOut(nil)
        self.windows = []
        self.searchQuery = ""
    }
    
    public func updateThumbnail(windowId: CGWindowID, thumbnail: NSImage) {
        if let idx = windows.firstIndex(where: { $0.id == windowId }) {
            windows[idx].thumbnail = thumbnail
        }
    }
    
    public var isVisible: Bool {
        return panel?.isVisible ?? false
    }
}

// MARK: - SwiftUI Overlay View

struct SwitcherOverlayView: View {
    @ObservedObject var controller: SwitcherOverlayController
    
    var body: some View {
        let tileWidth = controller.thumbnailSize.tileWidth
        let gridColumns = Array(repeating: GridItem(.fixed(tileWidth), spacing: 14), count: max(1, controller.currentColumnCount))
        
        VStack(spacing: 12) {
            // Header Bar: Window Count & Live Search
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "macwindow.on.rectangle")
                        .foregroundColor(.accentColor)
                    Text("\(controller.windows.count) Open Windows")
                        .font(.system(size: 13, weight: .bold))
                }
                
                Spacer()
                
                if !controller.searchQuery.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        Text(controller.searchQuery)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor).opacity(0.7)))
                } else {
                    Text("Type any key to search...")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .padding(.horizontal, 6)
            
            // Tiles Grid with Auto-Scrolling
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: gridColumns, spacing: 14) {
                        ForEach(Array(controller.windows.enumerated()), id: \.element.id) { index, window in
                            SwitcherTileView(
                                window: window,
                                index: index,
                                isSelected: index == controller.selectedIndex,
                                showNumberBadge: controller.showQuickNumbers && index < 9,
                                previewHeight: controller.thumbnailSize.previewHeight
                            )
                            .id(window.id)
                            .onTapGesture {
                                AltTabEngine.shared.select(at: index)
                            }
                        }
                    }
                    .padding(4)
                }
                .onChange(of: controller.selectedIndex) { newIndex in
                    if newIndex >= 0 && newIndex < controller.windows.count {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(controller.windows[newIndex].id, anchor: .center)
                        }
                    }
                }
            }
            
            // Footer Shortcuts Cheat Sheet
            HStack(spacing: 14) {
                Text("⇥ Cycle")
                Text("↵ Select")
                if controller.showQuickNumbers {
                    Text("1-9 Jump")
                }
                Text("W Close")
                Text("M Minimize")
                Text("F Fullscreen")
                Text("Q Quit")
                Text("Esc Cancel")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 15)
        )
    }
}

// MARK: - Single Window Tile

struct SwitcherTileView: View {
    let window: SwitcherWindowInfo
    let index: Int
    let isSelected: Bool
    let showNumberBadge: Bool
    let previewHeight: CGFloat
    
    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail / Icon Area
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.35))
                    
                    if let thumb = window.thumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(6)
                            .padding(4)
                    } else if let icon = window.appIcon {
                        VStack(spacing: 6) {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: max(48, previewHeight * 0.5), height: max(48, previewHeight * 0.5))
                            
                            Text(window.appName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: previewHeight)
                
                // Number Badge (1-9)
                if showNumberBadge {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentColor))
                        .shadow(color: .black.opacity(0.4), radius: 2)
                        .padding(6)
                }
            }
            
            // App Icon & Titles
            HStack(spacing: 8) {
                if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(window.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Text(window.appName)
                        .font(.system(size: 10, weight: .regular))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 2)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.24) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
        )
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isSelected)
    }
}
