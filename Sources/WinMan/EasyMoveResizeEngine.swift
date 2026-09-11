import Foundation
import AppKit
import CoreGraphics

@MainActor
public final class EasyMoveResizeEngine {
    public static let shared = EasyMoveResizeEngine()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    private enum DragMode: Equatable {
        case none
        case moving
        case resizing(isRightSide: Bool, isBottomSide: Bool)
    }
    
    private var currentMode: DragMode = .none
    private var activeWindow: AXWindow?
    private var initialMouseLocation: CGPoint = .zero
    private var initialWindowFrame: CGRect = .zero
    
    public var isEnabled: Bool = true
    
    private init() {}
    
    public func start() {
        guard eventTap == nil else { return }
        
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                                     (1 << CGEventType.leftMouseDragged.rawValue) |
                                     (1 << CGEventType.leftMouseUp.rawValue) |
                                     (1 << CGEventType.rightMouseDown.rawValue) |
                                     (1 << CGEventType.rightMouseDragged.rawValue) |
                                     (1 << CGEventType.rightMouseUp.rawValue)
        
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let engine = Unmanaged<EasyMoveResizeEngine>.fromOpaque(refcon).takeUnretainedValue()
                return MainActor.assumeIsolated {
                    engine.handleEvent(proxy: proxy, type: type, event: event)
                }
            },
            userInfo: observer
        ) else {
            print("[WinMan] Failed to create mouse event tap. Check Accessibility permissions.")
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[WinMan] Easy-Move-Resize engine active.")
    }
    
    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
                self.runLoopSource = nil
            }
            self.eventTap = nil
        }
        self.currentMode = .none
        self.activeWindow = nil
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Automatically re-enable if timed out
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
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
        
        let isShiftResizeMatch = (prefs.resizeWithShift && !prefs.moveShift) && (
            (!targetMoveFlags.isEmpty && currentFlags == targetMoveFlags.union(.maskShift)) ||
            (currentFlags == [.maskCommand, .maskAlternate, .maskShift]) ||
            (currentFlags == [.maskControl, .maskAlternate, .maskShift])
        )
        
        guard isMoveMatch || isShiftResizeMatch else {
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
            if isMoveMatch || isShiftResizeMatch {
                if let window = AXWindow.windowAt(point: mouseLocation), let frame = window.frame {
                    self.activeWindow = window
                    self.initialMouseLocation = mouseLocation
                    self.initialWindowFrame = frame
                    
                    if isShiftResizeMatch {
                        // Shift + Left Click = Resize relative to quadrant
                        let isRight = mouseLocation.x >= frame.midX
                        let isBottom = mouseLocation.y >= frame.midY
                        self.currentMode = .resizing(isRightSide: isRight, isBottomSide: isBottom)
                    } else {
                        // Left Click = Move
                        self.currentMode = .moving
                    }
                    return nil // Intercept & swallow event
                }
            } else {
                // Normal click on a window - track focus after activation settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    WindowFocusTracker.shared.updateFrontmostFocus()
                }
            }
            
        case .rightMouseDown:
            if prefs.resizeWithRightClick && isMoveMatch {
                if let window = AXWindow.windowAt(point: mouseLocation), let frame = window.frame {
                    self.activeWindow = window
                    self.initialMouseLocation = mouseLocation
                    self.initialWindowFrame = frame
                    
                    let isRight = mouseLocation.x >= frame.midX
                    let isBottom = mouseLocation.y >= frame.midY
                    self.currentMode = .resizing(isRightSide: isRight, isBottomSide: isBottom)
                    return nil // Intercept & swallow event
                }
            }
            
        case .leftMouseDragged:
            switch currentMode {
            case .moving:
                if let window = activeWindow {
                    let dx = mouseLocation.x - initialMouseLocation.x
                    let dy = mouseLocation.y - initialMouseLocation.y
                    let newOrigin = CGPoint(x: initialWindowFrame.origin.x + dx, y: initialWindowFrame.origin.y + dy)
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
