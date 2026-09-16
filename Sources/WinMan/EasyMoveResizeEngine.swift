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
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isEnabled else {
            return Unmanaged.passRetained(event)
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
            if isMoveMatch {
                if let window = AXWindow.windowAt(point: mouseLocation), let frame = window.frame {
                    self.activeWindow = window
                    self.initialMouseLocation = mouseLocation
                    self.initialWindowFrame = frame
                    window.saveCurrentForRestore()
                    
                    // Left Click = Move
                    self.currentMode = .moving
                    
                    return nil // Intercept & swallow event
                }
            }
            
        case .rightMouseDown:
            if prefs.resizeWithRightClick && isMoveMatch {
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
            }
            
        case .leftMouseDragged:
            let now = Date()
            guard now.timeIntervalSince(lastDragUpdate) > 1.0 / 60.0 else { return nil }
            lastDragUpdate = now
            
            switch currentMode {
            case .moving:
                if let window = activeWindow {
                    let dx = mouseLocation.x - initialMouseLocation.x
                    let dy = mouseLocation.y - initialMouseLocation.y
                    var newOrigin = CGPoint(x: initialWindowFrame.origin.x + dx, y: initialWindowFrame.origin.y + dy)
                    
                    if let screen = window.targetScreen() {
                        let sf = AXWindow.screenAXVisibleFrame(screen)
                        // Don't allow dragging completely above the menu bar or below the screen
                        newOrigin.y = max(sf.minY, min(newOrigin.y, sf.maxY - 20))
                        // Don't allow dragging completely off the left/right edges
                        newOrigin.x = max(sf.minX - initialWindowFrame.width + 40, min(newOrigin.x, sf.maxX - 40))
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
            guard now.timeIntervalSince(lastDragUpdate) > 1.0 / 60.0 else { return nil }
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
