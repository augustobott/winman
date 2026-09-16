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
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WinManSnapBindingsChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadBindings() }
        }
        reloadBindings()
    }
    
    private func reloadBindings() {
        let prefs = PreferencesManager.shared
        let mods = prefs.snapModifiersMask
        var newBindings: [HotkeyBinding] = []
        
        for action in WindowAction.allCases {
            if let keyCode = prefs.snapBindings[action.rawValue] {
                newBindings.append(HotkeyBinding(
                    action: action,
                    keyCode: CGKeyCode(keyCode),
                    modifiers: mods,
                    displayString: ""
                ))
            }
        }
        
        self.bindings = newBindings
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
    
    @MainActor
    public func execute(action: WindowAction) {
        guard let window = AXWindow.focusedWindow() else {
            print("[WinMan] No active window found to perform action: \(action.rawValue)")
            return
        }
        
        let currentFrame = window.frame
        
        if action == .restore {
            window.restorePreviousFrame()
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
