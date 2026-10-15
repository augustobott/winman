import Foundation
import AppKit
import ApplicationServices
import CoreServices

@MainActor
public final class BrowserRouterManager: ObservableObject {
    public static let shared = BrowserRouterManager()
    
    @Published public private(set) var installedBrowsers: [InstalledBrowser] = []
    
    private let trackingQueryKeys: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id", "utm_name",
        "fbclid", "gclid", "gclsrc", "dclid", "msclkid", "mc_eid", "igshid", "twclid", "si",
        "_hsenc", "_hsmi", "vero_id", "yclid", "wickedid"
    ]
    
    private init() {
        refreshInstalledBrowsers()
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWorkspaceActivation),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWorkspaceActivation),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleWorkspaceActivation() {
        objectWillChange.send()
    }
    
    public func refreshInstalledBrowsers() {
        guard let testURL = URL(string: "https://apple.com") else { return }
        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: testURL)
        let myBundleId = Bundle.main.bundleIdentifier ?? "com.winman.WinMan"
        
        var list: [InstalledBrowser] = []
        var seenBundleIds = Set<String>()
        
        let priorityOrder = [
            "com.apple.Safari",
            "com.google.Chrome",
            "org.mozilla.firefox",
            "company.thebrowser.Browser", // Arc
            "com.brave.Browser",
            "com.microsoft.edgemac",
            "com.operasoftware.Opera",
            "app.zen-browser.zen",
            "com.vivaldi.Vivaldi",
            "com.kagi.kagimacOS", // Orion
            "com.duckduckgo.macos.browser"
        ]
        
        for url in appURLs {
            guard let bundle = Bundle(url: url),
                  let bundleId = bundle.bundleIdentifier,
                  bundleId != myBundleId,
                  !seenBundleIds.contains(bundleId) else {
                continue
            }
            
            seenBundleIds.insert(bundleId)
            
            let name = bundle.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle.infoDictionary?["CFBundleName"] as? String
                ?? url.deletingPathExtension().lastPathComponent
            
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            list.append(InstalledBrowser(bundleId: bundleId, name: name, appURL: url, icon: icon))
        }
        
        // Sort priority browsers first, then alphabetically
        list.sort { a, b in
            let idxA = priorityOrder.firstIndex(of: a.bundleId) ?? 999
            let idxB = priorityOrder.firstIndex(of: b.bundleId) ?? 999
            if idxA != idxB {
                return idxA < idxB
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        
        self.installedBrowsers = list
    }
    
    public func stripTrackingParameters(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return url
        }
        guard let items = components.queryItems, !items.isEmpty else {
            return url
        }
        
        let filtered = items.filter { item in
            !trackingQueryKeys.contains(item.name.lowercased())
        }
        
        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.url ?? url
    }
    
    public func handle(url: URL) {
        let prefs = PreferencesManager.shared
        guard prefs.browserRouterEnabled else {
            open(url: url, in: prefs.browserRouterDefaultBrowserBundleId)
            return
        }
        
        let processedURL = prefs.browserRouterStripTracking ? stripTrackingParameters(from: url) : url
        
        // 1. Check modifier key override (Option key held when clicking / triggering)
        if prefs.browserRouterOptionKeyPrompts && NSEvent.modifierFlags.contains(.option) {
            BrowserPickerWindowController.show(for: processedURL)
            return
        }
        
        // 2. Evaluate routing rules
        for rule in prefs.browserRouterRules where rule.isEnabled {
            if rule.matches(url: processedURL) {
                open(url: processedURL, in: rule.targetBrowserBundleId)
                return
            }
        }
        
        // 3. Check general picker behavior
        if prefs.browserRouterBehavior == BrowserPickerBehavior.alwaysPrompt.rawValue {
            BrowserPickerWindowController.show(for: processedURL)
            return
        }
        
        // 4. Default browser fallback
        open(url: processedURL, in: prefs.browserRouterDefaultBrowserBundleId)
    }
    
    public func open(url: URL, in bundleId: String) {
        if bundleId == "prompt" {
            BrowserPickerWindowController.show(for: url)
            return
        }
        
        let cleanURL = PreferencesManager.shared.browserRouterStripTracking ? stripTrackingParameters(from: url) : url
        
        if let browser = installedBrowsers.first(where: { $0.bundleId == bundleId }) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open([cleanURL], withApplicationAt: browser.appURL, configuration: config, completionHandler: nil)
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open([cleanURL], withApplicationAt: appURL, configuration: config, completionHandler: nil)
        } else if let safari = installedBrowsers.first(where: { $0.bundleId == "com.apple.Safari" }) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open([cleanURL], withApplicationAt: safari.appURL, configuration: config, completionHandler: nil)
        } else {
            NSWorkspace.shared.open(cleanURL)
        }
    }
    
    public func openFromClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty else {
            return
        }
        
        var urlString = string
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            if urlString.contains(".") && !urlString.contains(" ") {
                urlString = "https://" + urlString
            }
        }
        
        guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
            return
        }
        
        handle(url: url)
    }
    
    public var isSystemDefaultBrowser: Bool {
        guard let testURL = URL(string: "https://apple.com") else { return false }
        guard let defaultAppURL = NSWorkspace.shared.urlForApplication(toOpen: testURL) else { return false }
        let myBundleId = Bundle.main.bundleIdentifier ?? "com.winman.WinMan"
        if let bundle = Bundle(url: defaultAppURL), let bundleId = bundle.bundleIdentifier {
            return bundleId.caseInsensitiveCompare(myBundleId) == .orderedSame
        }
        let appName = defaultAppURL.deletingPathExtension().lastPathComponent
        return appName.caseInsensitiveCompare("WinMan") == .orderedSame
    }
    
    public func requestSetDefaultBrowser() {
        let myBundleId = (Bundle.main.bundleIdentifier ?? "com.winman.WinMan") as CFString
        LSSetDefaultHandlerForURLScheme("http" as CFString, myBundleId)
        LSSetDefaultHandlerForURLScheme("https" as CFString, myBundleId)
        LSSetDefaultRoleHandlerForContentType("public.html" as CFString, .all, myBundleId)
    }
    
    public func openDefaultBrowserSettings() {
        requestSetDefaultBrowser()
        
        if #available(macOS 13.0, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension"),
               NSWorkspace.shared.open(url) {
                return
            }
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.general"),
           NSWorkspace.shared.open(url) {
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
    
    public func promptDefaultBrowserWarning(force: Bool = false) {
        guard !isSystemDefaultBrowser else { return }
        
        let prefs = PreferencesManager.shared
        if !force && (!prefs.browserRouterEnabled || !prefs.browserRouterCheckDefaultOnLaunch) {
            return
        }
        
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.messageText = "WinMan is Not Your Default Web Browser"
        alert.informativeText = """
            WinMan needs to be set as your default web browser to intercept and route links clicked in other apps (such as Mail, Messages, and Slack) according to your rules.

            In System Settings → Desktop & Dock, scroll to "Default web browser" and select WinMan.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings…")
        alert.addButton(withTitle: "Not Now")
        
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Do not check on startup"
        
        let response = alert.runModal()
        
        if alert.suppressionButton?.state == .on {
            prefs.browserRouterCheckDefaultOnLaunch = false
        }
        
        if response == .alertFirstButtonReturn {
            openDefaultBrowserSettings()
        }
    }
    
    public func promptDefaultBrowserWarningIfNeeded() {
        promptDefaultBrowserWarning(force: false)
    }
}
