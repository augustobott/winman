import Foundation
import CoreGraphics
import Combine

public final class PreferencesManager: ObservableObject {
    public static let shared = PreferencesManager()
    
    // Dedicated persistent UserDefaults
    private let defaults = UserDefaults.standard
    
    private func persist(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
        defaults.synchronize()
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    }
    
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
            persist(easyMoveResizeEnabled, forKey: keyEasyMoveResizeEnabled)
            EasyMoveResizeEngine.shared.isEnabled = easyMoveResizeEnabled
        }
    }
    
    @Published public var hotkeySnapEnabled: Bool {
        didSet {
            persist(hotkeySnapEnabled, forKey: keyHotkeySnapEnabled)
            HotkeySnapEngine.shared.isEnabled = hotkeySnapEnabled
        }
    }
    
    // Modifier keys
    @Published public var moveCmd: Bool {
        didSet { persist(moveCmd, forKey: keyMoveCmd) }
    }
    @Published public var moveCtrl: Bool {
        didSet { persist(moveCtrl, forKey: keyMoveCtrl) }
    }
    @Published public var moveOpt: Bool {
        didSet { persist(moveOpt, forKey: keyMoveOpt) }
    }
    @Published public var moveShift: Bool {
        didSet { persist(moveShift, forKey: keyMoveShift) }
    }
    
    @Published public var resizeWithRightClick: Bool {
        didSet { persist(resizeWithRightClick, forKey: keyResizeWithRightClick) }
    }
    @Published public var resizeWithShift: Bool {
        didSet { persist(resizeWithShift, forKey: keyResizeWithShift) }
    }
    
    @Published public var menuBarIconStyle: MenuBarIconStyle {
        didSet {
            persist(menuBarIconStyle.rawValue, forKey: keyMenuBarIconStyle)
            NotificationCenter.default.post(name: PreferencesManager.iconChangedNotification, object: nil)
        }
    }
    
    // Alt-Tab Preferences
    @Published public var altTabEnabled: Bool {
        didSet {
            persist(altTabEnabled, forKey: keyAltTabEnabled)
            AltTabEngine.shared.isEnabled = altTabEnabled
        }
    }
    @Published public var altTabShowThumbnails: Bool {
        didSet { persist(altTabShowThumbnails, forKey: keyAltTabShowThumbnails) }
    }
    @Published public var altTabEnableSearch: Bool {
        didSet { persist(altTabEnableSearch, forKey: keyAltTabEnableSearch) }
    }
    @Published public var altTabEnableQuickNumbers: Bool {
        didSet { persist(altTabEnableQuickNumbers, forKey: keyAltTabEnableQuickNumbers) }
    }
    @Published public var altTabScope: AltTabScope {
        didSet { persist(altTabScope.rawValue, forKey: keyAltTabScope) }
    }
    @Published public var altTabThumbnailSize: AltTabThumbnailSize {
        didSet { persist(altTabThumbnailSize.rawValue, forKey: keyAltTabThumbnailSize) }
    }
    
    private init() {
        defaults.register(defaults: [
            keyEasyMoveResizeEnabled: true,
            keyHotkeySnapEnabled: true,
            keyMoveCmd: true,
            keyMoveCtrl: false,
            keyMoveOpt: true,
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
        self.moveCtrl = defaults.object(forKey: keyMoveCtrl) as? Bool ?? false
        self.moveOpt = defaults.object(forKey: keyMoveOpt) as? Bool ?? true
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
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    }
    
    public func resetToDefaults() {
        self.easyMoveResizeEnabled = true
        self.hotkeySnapEnabled = true
        self.setPreset(cmd: true, ctrl: false, opt: true, shift: false)
        self.resizeWithRightClick = true
        self.resizeWithShift = true
        self.menuBarIconStyle = .monochrome
        self.altTabEnabled = true
        self.altTabShowThumbnails = true
        self.altTabEnableSearch = true
        self.altTabEnableQuickNumbers = true
        self.altTabScope = .allSpaces
        self.altTabThumbnailSize = .medium
        defaults.synchronize()
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    }
}
