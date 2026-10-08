import Foundation
import AppKit
import CoreGraphics

@MainActor
public final class EasyMoveResizeEngine {
    public static let shared = EasyMoveResizeEngine()
    
    private var tapManager: EventTapManager?
    
    private enum DragMode: Equatable {
        case none
        case moving
        case resizing(isRightSide: Bool, isBottomSide: Bool)
    }
    
    private var currentMode: DragMode = .none
    private var activeWindow: AXWindow?
    private var initialMouseLocation: CGPoint = .zero
    private var initialWindowFrame: CGRect = .zero
    private var lastDragUpdate: Date = .distantPast
    
    public var isEnabled: Bool = true
    
    private init() {}
    
    public func start() {
        guard tapManager == nil else { return }
        
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                                     (1 << CGEventType.leftMouseDragged.rawValue) |
                                     (1 << CGEventType.leftMouseUp.rawValue) |
                                     (1 << CGEventType.rightMouseDown.rawValue) |
                                     (1 << CGEventType.rightMouseDragged.rawValue) |
                                     (1 << CGEventType.rightMouseUp.rawValue)
        
        let manager = EventTapManager(label: "Easy-Move-Resize engine", eventMask: eventMask) { [weak self] proxy, type, event in
            guard let self = self else { return Unmanaged.passRetained(event) }
            return self.handleEvent(proxy: proxy, type: type, event: event)
        }
        manager.start()
        self.tapManager = manager
    }
    
    public func stop() {
        tapManager?.stop()
        self.tapManager = nil
        self.currentMode = .none
        self.activeWindow = nil
    }
    
    private func minDragInterval(at location: CGPoint) -> TimeInterval {
        // Find which screen contains the cursor to honor its native refresh rate (e.g. 60Hz vs 120Hz ProMotion)
        for screen in NSScreen.screens {
            let axFrame = AXWindow.screenAXFrame(screen)
            if axFrame.contains(location) {
                let fps = max(60, screen.maximumFramesPerSecond)
                // Use 85% of nominal frame duration to accommodate runloop/timer jitter
                return (1.0 / Double(fps)) * 0.85
            }
        }
        return (1.0 / 120.0) * 0.85
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isEnabled else {
            return Unmanaged.passRetained(event)
        }
        
        // Unconditionally terminate active drag/resize session on mouse up,
        // even if the user released modifier keys before releasing the mouse button.
        if (type == .leftMouseUp || type == .rightMouseUp) && currentMode != .none {
            self.currentMode = .none
            self.activeWindow = nil
            return nil
        }
        
        let flags = event.flags
        let relevantModifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
        let currentFlags = flags.intersection(relevantModifiers)
        
        let prefs = PreferencesManager.shared
        let targetMoveFlags = prefs.moveModifiersMask
        
        let isMoveMatch = (!targetMoveFlags.isEmpty && currentFlags == targetMoveFlags) ||
                          (currentFlags == [.maskCommand, .maskAlternate]) ||
                          (currentFlags == [.maskControl, .maskAlternate])
        
        guard isMoveMatch else {
            if type == .leftMouseDown {
                // Normal click on a window - track focus after activation settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    WindowFocusTracker.shared.updateFrontmostFocus()
                }
            }
            return Unmanaged.passRetained(event)
        }
        
        let mouseLocation = event.location
        
        switch type {
        case .leftMouseDown:
            if let window = AXWindow.windowAt(point: mouseLocation), let frame = window.frame {
                self.activeWindow = window
                self.initialMouseLocation = mouseLocation
                self.initialWindowFrame = frame
                window.saveCurrentForRestore()
                self.currentMode = .moving
                return nil // Intercept & swallow event
            }
            return Unmanaged.passRetained(event)
            
        case .rightMouseDown:
            guard prefs.resizeWithRightClick else { break }
            if let window = AXWindow.windowAt(point: mouseLocation), let frame = window.frame {
                self.activeWindow = window
                self.initialMouseLocation = mouseLocation
                self.initialWindowFrame = frame
                window.saveCurrentForRestore()
                let isRight = mouseLocation.x >= frame.midX
                let isBottom = mouseLocation.y >= frame.midY
                self.currentMode = .resizing(isRightSide: isRight, isBottomSide: isBottom)
                return nil // Intercept & swallow event
            }
            return Unmanaged.passRetained(event)
            
        case .leftMouseDragged:
            let now = Date()
            guard now.timeIntervalSince(lastDragUpdate) >= minDragInterval(at: mouseLocation) else { return nil }
            lastDragUpdate = now
            
            switch currentMode {
            case .moving:
                if let window = activeWindow {
                    let dx = mouseLocation.x - initialMouseLocation.x
                    let dy = mouseLocation.y - initialMouseLocation.y
                    var newOrigin = CGPoint(x: initialWindowFrame.origin.x + dx, y: initialWindowFrame.origin.y + dy)
                    
                    let proposedFrame = CGRect(origin: newOrigin, size: initialWindowFrame.size)
                    
                    // Constrain Y so the window titlebar does not get dragged completely above the menu bar:
                    if let screen = window.targetScreen(forFrame: proposedFrame) {
                        let sf = AXWindow.screenAXVisibleFrame(screen)
                        newOrigin.y = max(sf.minY, min(newOrigin.y, sf.maxY - 20))
                    }
                    
                    // Constrain X across the union of ALL screens so the window can move smoothly
                    // between monitors without artificial edge traps or sudden jumps.
                    let allAXFrames = NSScreen.screens.map { AXWindow.screenAXFrame($0) }
                    if let minX = allAXFrames.map({ $0.minX }).min(),
                       let maxX = allAXFrames.map({ $0.maxX }).max() {
                        newOrigin.x = max(minX - initialWindowFrame.width + 40, min(newOrigin.x, maxX - 40))
                    }
                    
                    window.setPosition(newOrigin)
                    return nil
                }
            case .resizing(let isRightSide, let isBottomSide):
                if let window = activeWindow {
                    resizeWindow(window, mouseLocation: mouseLocation, isRight: isRightSide, isBottom: isBottomSide)
                    return nil
                }
            case .none:
                break
            }
            
        case .rightMouseDragged:
            let now = Date()
            guard now.timeIntervalSince(lastDragUpdate) >= minDragInterval(at: mouseLocation) else { return nil }
            lastDragUpdate = now
            
            if case .resizing(let isRightSide, let isBottomSide) = currentMode, let window = activeWindow {
                resizeWindow(window, mouseLocation: mouseLocation, isRight: isRightSide, isBottom: isBottomSide)
                return nil
            }
            
        case .leftMouseUp, .rightMouseUp:
            if currentMode != .none {
                self.currentMode = .none
                self.activeWindow = nil
                return nil
            }
            
        default:
            break
        }
        
        return Unmanaged.passRetained(event)
    }
    
    private func resizeWindow(_ window: AXWindow, mouseLocation: CGPoint, isRight: Bool, isBottom: Bool) {
        let dx = mouseLocation.x - initialMouseLocation.x
        let dy = mouseLocation.y - initialMouseLocation.y
        
        var newX = initialWindowFrame.origin.x
        var newY = initialWindowFrame.origin.y
        var newWidth = initialWindowFrame.width
        var newHeight = initialWindowFrame.height
        
        let minSize: CGFloat = 120
        
        if isRight {
            newWidth = max(minSize, initialWindowFrame.width + dx)
        } else {
            let proposedWidth = initialWindowFrame.width - dx
            if proposedWidth >= minSize {
                newWidth = proposedWidth
                newX = initialWindowFrame.origin.x + dx
            } else {
                newWidth = minSize
                newX = initialWindowFrame.maxX - minSize
            }
        }
        
        if isBottom {
            newHeight = max(minSize, initialWindowFrame.height + dy)
        } else {
            let proposedHeight = initialWindowFrame.height - dy
            if proposedHeight >= minSize {
                newHeight = proposedHeight
                newY = initialWindowFrame.origin.y + dy
            } else {
                newHeight = minSize
                newY = initialWindowFrame.maxY - minSize
            }
        }
        
        let newRect = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
        window.setFrame(newRect, saveCurrentForRestore: false)
    }
}
