import Foundation
import AppKit
import ApplicationServices
import CoreServices

@MainActor
public final class BrowserRouterManager: ObservableObject {
    public static let shared = BrowserRouterManager()
    
    @Published public private(set) var installedBrowsers: [InstalledBrowser] = []
    
    /// Comprehensive list of bundle identifiers for known web browsers on macOS.
    public static let knownBrowserBundleIds: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.google.Chrome.beta",
        "com.google.Chrome.dev",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
        "org.mozilla.palemoon",
        "org.mozilla.seamonkey",
        "company.thebrowser.Browser", // Arc
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.nightly",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Canary",
        "com.microsoft.edgemac.Dev",
        "com.microsoft.edgemac.Beta",
        "com.operasoftware.Opera",
        "com.operasoftware.OperaGX",
        "com.operasoftware.OperaNext",
        "com.operasoftware.OperaDeveloper",
        "com.operasoftware.OperaCrypto",
        "app.zen-browser.zen",
        "com.vivaldi.Vivaldi",
        "com.kagi.kagimacOS", // Orion
        "com.duckduckgo.macos.browser",
        "org.torproject.torbrowser",
        "org.chromium.Chromium",
        "com.sigmaos.sigmaos.macos", // SigmaOS
        "net.waterfox.waterfox",
        "io.gitlab.librewolf-community.librewolf",
        "net.mullvad.mullvad-browser",
        "com.pushplaylabs.sidekick",
        "com.ghostery.browser",
        "com.electron.min",
        "org.ladybird.Ladybird",
        "com.tempest.browser",
        "io.island.island",
        "ru.yandex.desktop.yandex-browser",
        "com.maxthon.mac.Maxthon",
        "com.alohabrowser.alohabrowser",
        "com.bookry.wavebox",
        "jp.co.ablaze.floorp",
        "com.mighty.app",
        "net.ungoogled-software.ungoogled-chromium",
        "com.colibri.browser",
        "com.atlas.nyxt",
        "org.qutebrowser.qutebrowser"
    ]
    
    private static let knownBrowserPrefixes: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "company.thebrowser.Browser",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.operasoftware.Opera",
        "org.torproject.torbrowser",
        "app.zen-browser.zen",
        "com.vivaldi.Vivaldi",
        "com.kagi.kagimacOS",
        "com.duckduckgo.macos.browser",
        "org.chromium.Chromium"
    ]
    
    /// Applications and utilities known to register http/https schemes that are NOT web browsers.
    public static let blockedAppBundleIdPrefixes: [String] = [
        "com.winman.WinMan",
        "com.sindresorhus.Velja",
        "com.browserosaurus",
        "com.choosyosx.Choosy",
        "net.kylewm.finicky",
        "net.sprout24.finicky",
        "com.frodev.Bumpr",
        "com.loshadki.OpenIn",
        "com.github.switchbar",
        "com.googlecode.iterm2",
        "com.cmuxterm",
        "com.apple.Terminal",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "dev.warp.Warp",
        "co.zeit.hyper",
        "com.github.wez.wezterm",
        "com.mitchellh.ghostty",
        "com.mediahuman.",
        "com.charliemonroe.Downie",
        "com.openmedia.",
        "com.4kdownload.",
        "org.jdownloader.",
        "org.videolan.vlc",
        "com.colliderli.iina",
        "io.mpv",
        "org.m0k.transmission",
        "org.qbittorrent.",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "ru.keepcoder.Telegram",
        "com.tdesktop.Telegram",
        "net.whatsapp.WhatsApp",
        "com.postmanlabs.mac",
        "com.insomnia.app",
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.apple.TextEdit",
        "com.apple.Notes",
        "com.sublimetext."
    ]
    
    private static let blockedKeywords: [String] = [
        "terminal", "iterm", "cmux", "kitty", "alacritty", "warp", "ghostty", "wezterm",
        "youtube to mp3", "downloader", "converter", "torrent"
    ]
    
    public static func isActualBrowser(bundle: Bundle, appURL: URL) -> Bool {
        guard let bundleId = bundle.bundleIdentifier else { return false }
        let name = bundle.infoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle.infoDictionary?["CFBundleName"] as? String
            ?? appURL.deletingPathExtension().lastPathComponent
        return isActualBrowser(bundleId: bundleId, appName: name)
    }
    
    public static func isActualBrowser(bundleId: String, appName: String) -> Bool {
        let lowerBid = bundleId.lowercased()
        let lowerName = appName.lowercased()
        
        // 1. Check against blocked bundle ID prefixes and identifiers
        for blocked in blockedAppBundleIdPrefixes {
            if lowerBid == blocked.lowercased() || lowerBid.hasPrefix(blocked.lowercased()) {
                return false
            }
        }
        
        // 2. Check against blocked keywords in name or bundle identifier
        for keyword in blockedKeywords {
            if lowerName.contains(keyword) || lowerBid.contains(keyword) {
                return false
            }
        }
        
        // 3. Match against known browser bundle IDs or prefixes
        if knownBrowserBundleIds.contains(bundleId) {
            return true
        }
        for prefix in knownBrowserPrefixes {
            if bundleId.hasPrefix(prefix) {
                return true
            }
        }
        
        // 4. Heuristic: App name or bundle identifier explicitly identifies as a browser / navigator
        if lowerName.contains("browser") || lowerBid.contains("browser") ||
           lowerName.contains("navigator") || lowerBid.contains("navigator") {
            return true
        }
        
        return false
    }
    
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
            "com.duckduckgo.macos.browser",
            "org.torproject.torbrowser"
        ]
        
        for url in appURLs {
            guard let bundle = Bundle(url: url),
                  let bundleId = bundle.bundleIdentifier,
                  bundleId != myBundleId,
                  !seenBundleIds.contains(bundleId) else {
                continue
            }
            
            guard BrowserRouterManager.isActualBrowser(bundle: bundle, appURL: url) else {
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
        
        // Fall back default browser preference if previously set to an invalid app
        let prefs = PreferencesManager.shared
        if prefs.browserRouterDefaultBrowserBundleId != "prompt" {
            let isCurrentValid = list.contains(where: { $0.bundleId == prefs.browserRouterDefaultBrowserBundleId })
            if !isCurrentValid, let firstValid = list.first(where: { $0.bundleId == "com.apple.Safari" }) ?? list.first {
                prefs.browserRouterDefaultBrowserBundleId = firstValid.bundleId
            }
        }
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
