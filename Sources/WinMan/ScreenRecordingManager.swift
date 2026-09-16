import Foundation
import AppKit
import CoreGraphics

/// Manages the Screen Recording permission lifecycle required for window thumbnails.
///
/// macOS 10.15+ requires explicit Screen Recording permission before any app can
/// capture window contents via `CGWindowListCreateImage`. Without it the API
/// returns a blank (transparent) image with no error — the failure is completely silent.
///
/// For LSUIElement (menu bar) apps, `CGRequestScreenCaptureAccess()` may be silently
/// suppressed by macOS because there is no key window to attach the permission dialog to.
/// The reliable fallback is to open System Settings directly and show an NSAlert explaining
/// what the user needs to do.
@MainActor
public final class ScreenRecordingManager {
    public static let shared = ScreenRecordingManager()
    private init() {}

    /// Whether Screen Recording permission is currently granted.
    public var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Requests Screen Recording permission if it has not already been granted.
    ///
    /// Calls the native macOS TCC dialog via `CGRequestScreenCaptureAccess()`.
    /// If the user has already denied access, the dialog won't reappear — use
    /// `showManualPermissionAlert()` or `openScreenRecordingPreferences()` in that case.
    ///
    /// - Returns: `true` if permission is already granted (no action taken).
    @discardableResult
    public func requestIfNeeded() -> Bool {
        guard !CGPreflightScreenCaptureAccess() else { return true }
        CGRequestScreenCaptureAccess()
        return false
    }

    /// Shows an NSAlert explaining how to grant Screen Recording access manually,
    /// then opens System Settings to the correct pane.
    public func showManualPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = """
            WinMan needs Screen Recording permission to show live window previews \
            in the Alt-Tab switcher.

            Click "Open Settings" below, then find WinMan in the list and toggle \
            it on. WinMan will relaunch automatically.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")

        if alert.runModal() == .alertFirstButtonReturn {
            openScreenRecordingPreferences()
        }
    }

    /// Opens the Screen Recording pane in System Settings.
    /// Uses the correct URL scheme for macOS 13+ (Ventura and later).
    public func openScreenRecordingPreferences() {
        // macOS 13+ uses a new URL scheme for Privacy & Security settings.
        // The old com.apple.preference.security format silently fails on Ventura+.
        let urls: [String] = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ]
        for str in urls {
            if let url = URL(string: str), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
