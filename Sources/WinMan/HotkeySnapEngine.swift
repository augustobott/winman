import Foundation
import AppKit
import CoreGraphics

@MainActor
public final class HotkeySnapEngine {
    public static let shared = HotkeySnapEngine()
    
    private var tapManager: EventTapManager?
    
    public var isEnabled: Bool = true
    
    // Key codes
    
    public private(set) var bindings: [HotkeyBinding] = []
    
    private init() {
        setupDefaultBindings()
    }
    
    private func setupDefaultBindings() {
        let ctrlOpt: CGEventFlags = [.maskControl, .maskAlternate]
        let ctrlOptCmd: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
        let cmdOpt: CGEventFlags = [.maskCommand, .maskAlternate]
        
        bindings = [
            // Maximize & Restore
            HotkeyBinding(action: .maximize, keyCode: KeyCode.enter, modifiers: ctrlOpt, displayString: "⌃⌥↵"),
            HotkeyBinding(action: .maximize, keyCode: KeyCode.f, modifiers: cmdOpt, displayString: "⌥⌘F"),
            HotkeyBinding(action: .restore, keyCode: KeyCode.backspace, modifiers: ctrlOpt, displayString: "⌃⌥⌫"),
            HotkeyBinding(action: .restore, keyCode: KeyCode.r, modifiers: cmdOpt, displayString: "⌥⌘R"),
            
            // Halves
            HotkeyBinding(action: .leftHalf, keyCode: KeyCode.leftArrow, modifiers: ctrlOpt, displayString: "⌃⌥←"),
            HotkeyBinding(action: .rightHalf, keyCode: KeyCode.rightArrow, modifiers: ctrlOpt, displayString: "⌃⌥→"),
            HotkeyBinding(action: .topHalf, keyCode: KeyCode.upArrow, modifiers: ctrlOpt, displayString: "⌃⌥↑"),
            HotkeyBinding(action: .bottomHalf, keyCode: KeyCode.downArrow, modifiers: ctrlOpt, displayString: "⌃⌥↓"),
            
            // Quarters
            HotkeyBinding(action: .topLeftQuarter, keyCode: KeyCode.u, modifiers: ctrlOpt, displayString: "⌃⌥U"),
            HotkeyBinding(action: .topRightQuarter, keyCode: KeyCode.i, modifiers: ctrlOpt, displayString: "⌃⌥I"),
            HotkeyBinding(action: .bottomLeftQuarter, keyCode: KeyCode.j, modifiers: ctrlOpt, displayString: "⌃⌥J"),
            HotkeyBinding(action: .bottomRightQuarter, keyCode: KeyCode.k, modifiers: ctrlOpt, displayString: "⌃⌥K"),
            
            // Thirds
            HotkeyBinding(action: .leftThird, keyCode: KeyCode.d, modifiers: ctrlOpt, displayString: "⌃⌥D"),
            HotkeyBinding(action: .centerThird, keyCode: KeyCode.e, modifiers: ctrlOpt, displayString: "⌃⌥E"),
            HotkeyBinding(action: .rightThird, keyCode: KeyCode.f, modifiers: ctrlOpt, displayString: "⌃⌥F"),
            HotkeyBinding(action: .leftTwoThirds, keyCode: KeyCode.g, modifiers: ctrlOpt, displayString: "⌃⌥G"),
            HotkeyBinding(action: .rightTwoThirds, keyCode: KeyCode.t, modifiers: ctrlOpt, displayString: "⌃⌥T"),
            
            // Center & Resize
            HotkeyBinding(action: .center, keyCode: KeyCode.c, modifiers: ctrlOpt, displayString: "⌃⌥C"),
            HotkeyBinding(action: .increaseSize, keyCode: KeyCode.equal, modifiers: ctrlOpt, displayString: "⌃⌥+"),
            HotkeyBinding(action: .decreaseSize, keyCode: KeyCode.minus, modifiers: ctrlOpt, displayString: "⌃⌥-"),
            
            // Displays
            HotkeyBinding(action: .nextScreen, keyCode: KeyCode.rightArrow, modifiers: ctrlOptCmd, displayString: "⌃⌥⌘→"),
            HotkeyBinding(action: .prevScreen, keyCode: KeyCode.leftArrow, modifiers: ctrlOptCmd, displayString: "⌃⌥⌘←")
        ]
    }
    
    public func start() {
        guard tapManager == nil else { return }
        
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let manager = EventTapManager(label: "Hotkey snap engine", eventMask: eventMask) { [weak self] proxy, type, event in
            guard let self = self else { return Unmanaged.passRetained(event) }
            return self.handleKeyEvent(proxy: proxy, type: type, event: event)
        }
        manager.start()
        self.tapManager = manager
    }
    
    public func stop() {
        tapManager?.stop()
        self.tapManager = nil
    }
    
    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isEnabled, type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let relevantModifiersMask: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskShift]
        let currentModifiers = event.flags.intersection(relevantModifiersMask)
        
        for binding in bindings {
            if binding.keyCode == keyCode && binding.modifiers == currentModifiers {
                DispatchQueue.main.async {
                    self.execute(action: binding.action)
                }
                return nil // Intercept & swallow hotkey
            }
        }
        
        return Unmanaged.passRetained(event)
    }
    
    public func execute(action: WindowAction) {
        guard let window = AXWindow.focusedWindow() else {
            print("[WinMan] No active window found to perform action: \(action.rawValue)")
            return
        }
        
        let currentFrame = window.frame
        
        if action == .restore {
            if window.restorePreviousFrame() {
                return
            }
            // Fallback: If no restore history exists, center standard size
            if let screen = window.targetScreen(forFrame: currentFrame) {
                let screenFrame = AXWindow.screenAXVisibleFrame(screen)
                let w = screenFrame.width * 0.75
                let h = screenFrame.height * 0.75
                let x = screenFrame.origin.x + (screenFrame.width - w) / 2
                let y = screenFrame.origin.y + (screenFrame.height - h) / 2
                window.setFrame(CGRect(x: x, y: y, width: w, height: h), saveCurrentForRestore: false)
            }
            return
        }
        
        guard let screen = window.targetScreen(forFrame: currentFrame) else { return }
        let screenFrame = AXWindow.screenAXVisibleFrame(screen)
        
        let x0 = screenFrame.origin.x
        let y0 = screenFrame.origin.y
        let w = screenFrame.width
        let h = screenFrame.height
        
        let halfW = floor(w / 2)
        let otherHalfW = w - halfW
        let halfH = floor(h / 2)
        let otherHalfH = h - halfH
        
        let thirdW = floor(w / 3)
        let twoThirdW = floor(w * 2 / 3)
        
        var targetRect: CGRect?
        
        switch action {
        case .maximize:
            targetRect = screenFrame
            
        case .leftHalf:
            targetRect = CGRect(x: x0, y: y0, width: halfW, height: h)
            
        case .rightHalf:
            targetRect = CGRect(x: x0 + halfW, y: y0, width: otherHalfW, height: h)
            
        case .topHalf:
            targetRect = CGRect(x: x0, y: y0, width: w, height: halfH)
            
        case .bottomHalf:
            targetRect = CGRect(x: x0, y: y0 + halfH, width: w, height: otherHalfH)
            
        case .topLeftQuarter:
            targetRect = CGRect(x: x0, y: y0, width: halfW, height: halfH)
            
        case .topRightQuarter:
            targetRect = CGRect(x: x0 + halfW, y: y0, width: otherHalfW, height: halfH)
            
        case .bottomLeftQuarter:
            targetRect = CGRect(x: x0, y: y0 + halfH, width: halfW, height: otherHalfH)
            
        case .bottomRightQuarter:
            targetRect = CGRect(x: x0 + halfW, y: y0 + halfH, width: otherHalfW, height: otherHalfH)
            
        case .leftThird:
            targetRect = CGRect(x: x0, y: y0, width: thirdW, height: h)
            
        case .centerThird:
            targetRect = CGRect(x: x0 + thirdW, y: y0, width: thirdW, height: h)
            
        case .rightThird:
            targetRect = CGRect(x: x0 + 2 * thirdW, y: y0, width: w - 2 * thirdW, height: h)
            
        case .leftTwoThirds:
            targetRect = CGRect(x: x0, y: y0, width: twoThirdW, height: h)
            
        case .rightTwoThirds:
            targetRect = CGRect(x: x0 + (w - twoThirdW), y: y0, width: twoThirdW, height: h)
            
        case .center:
            if let current = currentFrame {
                let cx = x0 + max(0, (w - current.width) / 2)
                let cy = y0 + max(0, (h - current.height) / 2)
                targetRect = CGRect(x: cx, y: cy, width: min(w, current.width), height: min(h, current.height))
            }
            
        case .increaseSize:
            if let current = currentFrame {
                let nw = min(w, current.width * 1.1)
                let nh = min(h, current.height * 1.1)
                var nx = current.origin.x - (nw - current.width) / 2
                var ny = current.origin.y - (nh - current.height) / 2
                nx = min(max(x0, nx), x0 + w - nw)
                ny = min(max(y0, ny), y0 + h - nh)
                targetRect = CGRect(x: nx, y: ny, width: nw, height: nh)
            }
            
        case .decreaseSize:
            if let current = currentFrame {
                let nw = max(150, min(w, current.width * 0.9))
                let nh = max(150, min(h, current.height * 0.9))
                var nx = current.origin.x + (current.width - nw) / 2
                var ny = current.origin.y + (current.height - nh) / 2
                nx = min(max(x0, nx), x0 + w - nw)
                ny = min(max(y0, ny), y0 + h - nh)
                targetRect = CGRect(x: nx, y: ny, width: nw, height: nh)
            }
            
        case .nextScreen, .prevScreen:
            let screens = NSScreen.screens
            guard screens.count > 1, let currentIndex = screens.firstIndex(of: screen) else { return }
            let nextIndex: Int
            if action == .nextScreen {
                nextIndex = (currentIndex + 1) % screens.count
            } else {
                nextIndex = (currentIndex - 1 + screens.count) % screens.count
            }
            let nextScreen = screens[nextIndex]
            let nextScreenFrame = AXWindow.screenAXVisibleFrame(nextScreen)
            
            if let current = currentFrame {
                // Scale proportional position & size
                let relX = (current.origin.x - screenFrame.origin.x) / screenFrame.width
                let relY = (current.origin.y - screenFrame.origin.y) / screenFrame.height
                let relW = current.width / screenFrame.width
                let relH = current.height / screenFrame.height
                
                let newW = min(nextScreenFrame.width, max(150, relW * nextScreenFrame.width))
                let newH = min(nextScreenFrame.height, max(150, relH * nextScreenFrame.height))
                let newX = nextScreenFrame.origin.x + relX * nextScreenFrame.width
                let newY = nextScreenFrame.origin.y + relY * nextScreenFrame.height
                
                targetRect = CGRect(x: newX, y: newY, width: newW, height: newH)
            }
            
        case .restore:
            break
        }
        
        if let rect = targetRect {
            window.setFrame(rect, saveCurrentForRestore: true)
        }
    }
}
