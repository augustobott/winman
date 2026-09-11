import Foundation
import CoreGraphics

// MARK: - Reusable CoreGraphics Event Tap Wrapper

/// Manages the lifecycle of a `CGEventTap` on the main run loop.
/// Automatically handles creation, run loop registration, event forwarding,
/// and automatic re-enabling if disabled by the system due to timeout or user input.
@MainActor
public final class EventTapManager {
    public typealias EventHandler = (CGEventTapProxy, CGEventType, CGEvent) -> Unmanaged<CGEvent>?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let label: String
    private let eventMask: CGEventMask
    private let handler: EventHandler
    
    public init(label: String, eventMask: CGEventMask, handler: @escaping EventHandler) {
        self.label = label
        self.eventMask = eventMask
        self.handler = handler
    }
    
    public var isRunning: Bool {
        return eventTap != nil
    }
    
    public func start() {
        guard eventTap == nil else { return }
        
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return MainActor.assumeIsolated {
                    manager.handleEvent(proxy: proxy, type: type, event: event)
                }
            },
            userInfo: observer
        ) else {
            print("[WinMan] Failed to create \(label) event tap. Check Accessibility permissions.")
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[WinMan] \(label) active.")
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
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        return handler(proxy, type, event)
    }
}
