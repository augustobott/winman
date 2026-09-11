import AppKit

// Explicit module-scoped strong reference so AppDelegate is never deallocated prematurely
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let appDelegate = AppDelegate()
    app.delegate = appDelegate
    app.run()
}
