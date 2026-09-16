import AppKit

// Explicit module-scoped strong reference so AppDelegate is never deallocated prematurely
var appDelegate: AppDelegate?

MainActor.assumeIsolated {
    let app = NSApplication.shared
    appDelegate = AppDelegate()
    app.delegate = appDelegate
    app.run()
}
