import Foundation
import AppKit
import ApplicationServices

public final class AccessibilityManager {
    public static let shared = AccessibilityManager()
    
    private init() {}
    
    public var isTrusted: Bool {
        return AXIsProcessTrusted()
    }
    
    @discardableResult
    public func checkAndPrompt() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    public func openAccessibilityPreferences() {
        let prefString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: prefString) {
            NSWorkspace.shared.open(url)
        }
    }
}
