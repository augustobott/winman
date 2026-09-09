import Foundation
import CoreGraphics
import Combine

public final class PreferencesManager: ObservableObject {
    public static let shared = PreferencesManager()
    
    // Dedicated persistent UserDefaults suite
    private let defaults = UserDefaults(suiteName: "com.winman.WinMan") ?? UserDefaults.standard
    
    // Keys
    private let keyEasyMoveResizeEnabled = "easyMoveResizeEnabled"
    private let keyHotkeySnapEnabled = "hotkeySnapEnabled"
    private let keyMoveCmd = "moveModCmd"
    private let keyMoveCtrl = "moveModCtrl"
    private let keyMoveOpt = "moveModOpt"
    private let keyMoveShift = "moveModShift"
    
    private let keyResizeWithRightClick = "resizeWithRightClick"
    private let keyResizeWithShift = "resizeWithShift"
    private let keyMenuBarIconStyle = "menuBarIconStyle"
    
    // Alt-Tab Preferences Keys
    private let keyAltTabEnabled = "altTabEnabled"
    private let keyAltTabShowThumbnails = "altTabShowThumbnails"
    private let keyAltTabEnableSearch = "altTabEnableSearch"
    private let keyAltTabEnableQuickNumbers = "altTabEnableQuickNumbers"
    private let keyAltTabScope = "altTabScope"
    private let keyAltTabThumbnailSize = "altTabThumbnailSize"
    
    public static let iconChangedNotification = Notification.Name("WinManMenuBarIconChanged")
    
    // Engine toggles
    @Published public var easyMoveResizeEnabled: Bool {
        didSet {
            defaults.set(easyMoveResizeEnabled, forKey: keyEasyMoveResizeEnabled)
            defaults.synchronize()
            EasyMoveResizeEngine.shared.isEnabled = easyMoveResizeEnabled
        }
    }
    
    @Published public var hotkeySnapEnabled: Bool {
        didSet {
            defaults.set(hotkeySnapEnabled, forKey: keyHotkeySnapEnabled)
            defaults.synchronize()
            HotkeySnapEngine.shared.isEnabled = hotkeySnapEnabled
        }
    }
    
    // Modifier keys
    @Published public var moveCmd: Bool {
        didSet { defaults.set(moveCmd, forKey: keyMoveCmd); defaults.synchronize() }
    }
    @Published public var moveCtrl: Bool {
        didSet { defaults.set(moveCtrl, forKey: keyMoveCtrl); defaults.synchronize() }
    }
    @Published public var moveOpt: Bool {
        didSet { defaults.set(moveOpt, forKey: keyMoveOpt); defaults.synchronize() }
    }
    @Published public var moveShift: Bool {
        didSet { defaults.set(moveShift, forKey: keyMoveShift); defaults.synchronize() }
    }
    
    @Published public var resizeWithRightClick: Bool {
        didSet { defaults.set(resizeWithRightClick, forKey: keyResizeWithRightClick); defaults.synchronize() }
    }
    @Published public var resizeWithShift: Bool {
        didSet { defaults.set(resizeWithShift, forKey: keyResizeWithShift); defaults.synchronize() }
    }
    
    @Published public var menuBarIconStyle: MenuBarIconStyle {
        didSet {
            defaults.set(menuBarIconStyle.rawValue, forKey: keyMenuBarIconStyle)
            defaults.synchronize()
            NotificationCenter.default.post(name: PreferencesManager.iconChangedNotification, object: nil)
        }
    }
    
    // Alt-Tab Preferences
    @Published public var altTabEnabled: Bool {
        didSet {
            defaults.set(altTabEnabled, forKey: keyAltTabEnabled)
            defaults.synchronize()
            AltTabEngine.shared.isEnabled = altTabEnabled
        }
    }
    @Published public var altTabShowThumbnails: Bool {
        didSet { defaults.set(altTabShowThumbnails, forKey: keyAltTabShowThumbnails); defaults.synchronize() }
    }
    @Published public var altTabEnableSearch: Bool {
        didSet { defaults.set(altTabEnableSearch, forKey: keyAltTabEnableSearch); defaults.synchronize() }
    }
    @Published public var altTabEnableQuickNumbers: Bool {
        didSet { defaults.set(altTabEnableQuickNumbers, forKey: keyAltTabEnableQuickNumbers); defaults.synchronize() }
    }
    @Published public var altTabScope: AltTabScope {
        didSet { defaults.set(altTabScope.rawValue, forKey: keyAltTabScope); defaults.synchronize() }
    }
    @Published public var altTabThumbnailSize: AltTabThumbnailSize {
        didSet { defaults.set(altTabThumbnailSize.rawValue, forKey: keyAltTabThumbnailSize); defaults.synchronize() }
    }
    
    private init() {
        defaults.register(defaults: [
            keyEasyMoveResizeEnabled: true,
            keyHotkeySnapEnabled: true,
            keyMoveCmd: true,
            keyMoveCtrl: true,
            keyMoveOpt: false,
            keyMoveShift: false,
            keyResizeWithRightClick: true,
            keyResizeWithShift: true,
            keyMenuBarIconStyle: MenuBarIconStyle.monochrome.rawValue,
            keyAltTabEnabled: true,
            keyAltTabShowThumbnails: true,
            keyAltTabEnableSearch: true,
            keyAltTabEnableQuickNumbers: true,
            keyAltTabScope: AltTabScope.allSpaces.rawValue,
            keyAltTabThumbnailSize: AltTabThumbnailSize.medium.rawValue
        ])
        
        self.easyMoveResizeEnabled = defaults.object(forKey: keyEasyMoveResizeEnabled) as? Bool ?? true
        self.hotkeySnapEnabled = defaults.object(forKey: keyHotkeySnapEnabled) as? Bool ?? true
        
        self.moveCmd = defaults.object(forKey: keyMoveCmd) as? Bool ?? true
        self.moveCtrl = defaults.object(forKey: keyMoveCtrl) as? Bool ?? true
        self.moveOpt = defaults.object(forKey: keyMoveOpt) as? Bool ?? false
        self.moveShift = defaults.object(forKey: keyMoveShift) as? Bool ?? false
        self.resizeWithRightClick = defaults.object(forKey: keyResizeWithRightClick) as? Bool ?? true
        self.resizeWithShift = defaults.object(forKey: keyResizeWithShift) as? Bool ?? true
        
        let savedStyle = defaults.string(forKey: keyMenuBarIconStyle) ?? MenuBarIconStyle.monochrome.rawValue
        self.menuBarIconStyle = MenuBarIconStyle(rawValue: savedStyle) ?? .monochrome
        
        self.altTabEnabled = defaults.object(forKey: keyAltTabEnabled) as? Bool ?? true
        self.altTabShowThumbnails = defaults.object(forKey: keyAltTabShowThumbnails) as? Bool ?? true
        self.altTabEnableSearch = defaults.object(forKey: keyAltTabEnableSearch) as? Bool ?? true
        self.altTabEnableQuickNumbers = defaults.object(forKey: keyAltTabEnableQuickNumbers) as? Bool ?? true
        
        let savedScope = defaults.string(forKey: keyAltTabScope) ?? AltTabScope.allSpaces.rawValue
        self.altTabScope = AltTabScope(rawValue: savedScope) ?? .allSpaces
        
        let savedSize = defaults.string(forKey: keyAltTabThumbnailSize) ?? AltTabThumbnailSize.medium.rawValue
        self.altTabThumbnailSize = AltTabThumbnailSize(rawValue: savedSize) ?? .medium
    }
    
    public var moveModifiersMask: CGEventFlags {
        var flags: CGEventFlags = []
        if moveCmd { flags.insert(.maskCommand) }
        if moveCtrl { flags.insert(.maskControl) }
        if moveOpt { flags.insert(.maskAlternate) }
        if moveShift { flags.insert(.maskShift) }
        return flags
    }
    
    public var displayString: String {
        var parts: [String] = []
        if moveCtrl { parts.append("⌃ Control") }
        if moveOpt { parts.append("⌥ Option") }
        if moveShift { parts.append("⇧ Shift") }
        if moveCmd { parts.append("⌘ Command") }
        return parts.isEmpty ? "None" : parts.joined(separator: " + ")
    }
    
    public var shortDisplayString: String {
        var parts: [String] = []
        if moveCtrl { parts.append("⌃") }
        if moveOpt { parts.append("⌥") }
        if moveShift { parts.append("⇧") }
        if moveCmd { parts.append("⌘") }
        return parts.isEmpty ? "None" : parts.joined(separator: "")
    }
    
    public func setPreset(cmd: Bool, ctrl: Bool, opt: Bool, shift: Bool) {
        self.moveCmd = cmd
        self.moveCtrl = ctrl
        self.moveOpt = opt
        self.moveShift = shift
        defaults.synchronize()
    }
}
