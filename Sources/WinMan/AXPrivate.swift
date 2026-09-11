import Foundation
import ApplicationServices
import CoreGraphics

// MARK: - Undocumented macOS Accessibility SPI

/// Private Apple Accessibility SPI used to query the underlying CoreGraphics window ID
/// for an Accessibility UI element (`AXUIElement`).
///
/// Warning: Because this is an undocumented internal symbol, it may fail or be unavailable
/// on future macOS releases. Callers must always implement appropriate fallbacks (e.g. geometric
/// frame matching, title matching, or CGWindowList correlation).
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

extension AXUIElement {
    /// Safe helper to query the `CGWindowID` of an `AXUIElement` using the private SPI.
    /// Returns `nil` if the lookup fails or returns 0.
    func copyWindowID() -> CGWindowID? {
        var wid: CGWindowID = 0
        guard _AXUIElementGetWindow(self, &wid) == .success, wid != 0 else {
            return nil
        }
        return wid
    }
}
