import Foundation
import AppKit

public struct InstalledBrowser: Identifiable, Hashable, Sendable {
    public var id: String { bundleId }
    public let bundleId: String
    public let name: String
    public let appURL: URL
    public let icon: NSImage?
    
    public init(bundleId: String, name: String, appURL: URL, icon: NSImage? = nil) {
        self.bundleId = bundleId
        self.name = name
        self.appURL = appURL
        self.icon = icon
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bundleId)
    }
    
    public static func == (lhs: InstalledBrowser, rhs: InstalledBrowser) -> Bool {
        lhs.bundleId == rhs.bundleId
    }
    
    public var menuIcon: NSImage? {
        guard let img = icon?.copy() as? NSImage else { return nil }
        img.size = NSSize(width: 16, height: 16)
        return img
    }
}

public enum BrowserPickerBehavior: String, CaseIterable, Codable, Sendable {
    case openDefault = "openDefault"
    case alwaysPrompt = "alwaysPrompt"
}

public struct URLRoutingRule: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var pattern: String
    public var targetBrowserBundleId: String
    public var isEnabled: Bool
    
    public init(id: UUID = UUID(), pattern: String, targetBrowserBundleId: String, isEnabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.targetBrowserBundleId = targetBrowserBundleId
        self.isEnabled = isEnabled
    }
    
    public func matches(url: URL) -> Bool {
        guard isEnabled else { return false }
        
        var cleanPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanPattern.isEmpty else { return false }
        
        // Strip scheme if present
        if cleanPattern.hasPrefix("https://") {
            cleanPattern = String(cleanPattern.dropFirst(8))
        } else if cleanPattern.hasPrefix("http://") {
            cleanPattern = String(cleanPattern.dropFirst(7))
        }
        
        guard let host = url.host?.lowercased() else { return false }
        
        if let slashIndex = cleanPattern.firstIndex(of: "/") {
            let patternHost = String(cleanPattern[..<slashIndex])
            let patternPath = String(cleanPattern[slashIndex...])
            
            // Check host
            let hostMatches: Bool
            if patternHost.hasPrefix("*.") {
                let suffix = String(patternHost.dropFirst(2))
                hostMatches = (host == suffix || host.hasSuffix("." + suffix))
            } else {
                hostMatches = (host == patternHost || host.hasSuffix("." + patternHost))
            }
            guard hostMatches else { return false }
            
            // Check path and query
            let fullURLPathAndQuery = (url.path + (url.query != nil ? "?" + (url.query ?? "") : "")).lowercased()
            return fullURLPathAndQuery.hasPrefix(patternPath) || fullURLPathAndQuery.contains(patternPath)
        } else {
            // Pure host pattern
            if cleanPattern.hasPrefix("*.") {
                let suffix = String(cleanPattern.dropFirst(2))
                return host == suffix || host.hasSuffix("." + suffix)
            }
            if cleanPattern.hasPrefix("www.") {
                let stripped = String(cleanPattern.dropFirst(4))
                return host == cleanPattern || host == stripped || host.hasSuffix("." + stripped)
            }
            return host == cleanPattern || host.hasSuffix("." + cleanPattern)
        }
    }
}
