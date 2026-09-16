import Foundation
import CoreGraphics
import Combine

@MainActor
public final class PreferencesManager: ObservableObject {
    public static let shared = PreferencesManager()
    
    // Dedicated persistent UserDefaults
    private let defaults = UserDefaults.standard
    private var isBatchUpdating = false
    
    private func persist(_ value: Any?, forKey key: String) {
        guard !isBatchUpdating else { return }
        defaults.set(value, forKey: key)
    }
    
    private func validateModifiers() {
        guard !isBatchUpdating else { return }
        if !moveCmd && !moveCtrl && !moveOpt && !moveShift {
            moveOpt = true
        }
    }
    
    // Keys
    private let keyEasyMoveResizeEnabled = "easyMoveResizeEnabled"
    private let keyHotkeySnapEnabled = "hotkeySnapEnabled"
    private let keyMoveCmd = "moveModCmd"
    private let keyMoveCtrl = "moveModCtrl"
    private let keyMoveOpt = "moveModOpt"
    private let keyMoveShift = "moveModShift"
    
    private let keyResizeWithRightClick = "resizeWithRightClick"
    private let keyMenuBarIconStyle = "menuBarIconStyle"
    
    // Alt-Tab Preferences Keys
    private let keyAltTabEnabled = "altTabEnabled"
    private let keyAltTabShowThumbnails = "altTabShowThumbnails"
    private let keyAltTabEnableSearch = "altTabEnableSearch"
    private let keyAltTabEnableQuickNumbers = "altTabEnableQuickNumbers"
    private let keyAltTabScope = "altTabScope"
    private let keyAltTabThumbnailSize = "altTabThumbnailSize"
    
    // Snap Hotkey Config
    private let keySnapCmd = "snapModCmd"
    private let keySnapCtrl = "snapModCtrl"
    private let keySnapOpt = "snapModOpt"
    private let keySnapShift = "snapModShift"
    private let keySnapBindings = "snapBindings"
    
    public static let iconChangedNotification = Notification.Name("WinManMenuBarIconChanged")
    
    private static let defaultSnapBindings: [String: UInt16] = [
        WindowAction.maximize.rawValue: 36, // Enter
        WindowAction.restore.rawValue: 51, // Backspace
        WindowAction.leftHalf.rawValue: 123, // Left Arrow
        WindowAction.rightHalf.rawValue: 124, // Right Arrow
        WindowAction.topHalf.rawValue: 126, // Up Arrow
        WindowAction.bottomHalf.rawValue: 125, // Down Arrow
        WindowAction.topLeftQuarter.rawValue: 32, // U
        WindowAction.topRightQuarter.rawValue: 34, // I
        WindowAction.bottomLeftQuarter.rawValue: 38, // J
        WindowAction.bottomRightQuarter.rawValue: 40, // K
        WindowAction.leftThird.rawValue: 2, // D
        WindowAction.centerThird.rawValue: 14, // E
        WindowAction.rightThird.rawValue: 3, // F
        WindowAction.leftTwoThirds.rawValue: 5, // G
        WindowAction.rightTwoThirds.rawValue: 17, // T
        WindowAction.center.rawValue: 8, // C
        WindowAction.increaseSize.rawValue: 24, // =
        WindowAction.decreaseSize.rawValue: 27, // -
        WindowAction.nextScreen.rawValue: 33, // [
        WindowAction.prevScreen.rawValue: 30 // ]
    ]
    
    @Published public var snapCmd: Bool { didSet { persist(snapCmd, forKey: keySnapCmd); notifySnapBindingsChanged() } }
    @Published public var snapCtrl: Bool { didSet { persist(snapCtrl, forKey: keySnapCtrl); notifySnapBindingsChanged() } }
    @Published public var snapOpt: Bool { didSet { persist(snapOpt, forKey: keySnapOpt); notifySnapBindingsChanged() } }
    @Published public var snapShift: Bool { didSet { persist(snapShift, forKey: keySnapShift); notifySnapBindingsChanged() } }
    @Published public var snapBindings: [String: UInt16] {
        didSet {
            defaults.set(snapBindings, forKey: keySnapBindings)
            notifySnapBindingsChanged()
        }
    }
    
    private func notifySnapBindingsChanged() {
        if !isBatchUpdating {
            NotificationCenter.default.post(name: NSNotification.Name("WinManSnapBindingsChanged"), object: nil)
        }
    }
    
    // Engine toggles
    @Published public var easyMoveResizeEnabled: Bool {
        didSet {
            persist(easyMoveResizeEnabled, forKey: keyEasyMoveResizeEnabled)
            
        }
    }
    
    @Published public var hotkeySnapEnabled: Bool {
        didSet {
            persist(hotkeySnapEnabled, forKey: keyHotkeySnapEnabled)
            
        }
    }
    
    // Modifier keys
    @Published public var moveCmd: Bool {
        didSet {
            validateModifiers()
            persist(moveCmd, forKey: keyMoveCmd)
        }
    }
    @Published public var moveCtrl: Bool {
        didSet {
            validateModifiers()
            persist(moveCtrl, forKey: keyMoveCtrl)
        }
    }
    @Published public var moveOpt: Bool {
        didSet {
            validateModifiers()
            persist(moveOpt, forKey: keyMoveOpt)
        }
    }
    @Published public var moveShift: Bool {
        didSet {
            validateModifiers()
            persist(moveShift, forKey: keyMoveShift)
        }
    }
    
    @Published public var resizeWithRightClick: Bool {
        didSet { persist(resizeWithRightClick, forKey: keyResizeWithRightClick) }
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
            keyMenuBarIconStyle: MenuBarIconStyle.monochrome.rawValue,
            keyAltTabEnabled: true,
            keyAltTabShowThumbnails: true,
            keyAltTabEnableSearch: true,
            keyAltTabEnableQuickNumbers: true,
            keyAltTabScope: AltTabScope.currentScreen.rawValue,
            keyAltTabThumbnailSize: AltTabThumbnailSize.medium.rawValue
        ])
        
        self.easyMoveResizeEnabled = defaults.object(forKey: keyEasyMoveResizeEnabled) as? Bool ?? true
        self.hotkeySnapEnabled = defaults.object(forKey: keyHotkeySnapEnabled) as? Bool ?? true
        
        self.moveCmd = defaults.object(forKey: keyMoveCmd) as? Bool ?? true
        self.moveCtrl = defaults.object(forKey: keyMoveCtrl) as? Bool ?? true
        self.moveOpt = defaults.object(forKey: keyMoveOpt) as? Bool ?? false
        self.moveShift = defaults.object(forKey: keyMoveShift) as? Bool ?? false
        self.resizeWithRightClick = defaults.object(forKey: keyResizeWithRightClick) as? Bool ?? true
        
        let savedStyle = defaults.string(forKey: keyMenuBarIconStyle) ?? MenuBarIconStyle.monochrome.rawValue
        self.menuBarIconStyle = MenuBarIconStyle(rawValue: savedStyle) ?? .monochrome
        
        self.altTabEnabled = defaults.object(forKey: keyAltTabEnabled) as? Bool ?? true
        self.altTabShowThumbnails = defaults.object(forKey: keyAltTabShowThumbnails) as? Bool ?? false
        self.altTabEnableSearch = defaults.object(forKey: keyAltTabEnableSearch) as? Bool ?? false
        self.altTabEnableQuickNumbers = defaults.object(forKey: keyAltTabEnableQuickNumbers) as? Bool ?? false
        
        let savedScope = defaults.string(forKey: keyAltTabScope) ?? AltTabScope.allSpaces.rawValue
        self.altTabScope = AltTabScope(rawValue: savedScope) ?? .allSpaces
        
        let savedSize = defaults.string(forKey: keyAltTabThumbnailSize) ?? AltTabThumbnailSize.medium.rawValue
        self.altTabThumbnailSize = AltTabThumbnailSize(rawValue: savedSize) ?? .medium
        
        self.snapCmd = defaults.object(forKey: keySnapCmd) as? Bool ?? false
        self.snapCtrl = defaults.object(forKey: keySnapCtrl) as? Bool ?? true
        self.snapOpt = defaults.object(forKey: keySnapOpt) as? Bool ?? true
        self.snapShift = defaults.object(forKey: keySnapShift) as? Bool ?? false
        
        if let saved = defaults.dictionary(forKey: keySnapBindings) as? [String: UInt16] {
            self.snapBindings = saved
        } else {
            self.snapBindings = PreferencesManager.defaultSnapBindings
        }
    }
    
    public var moveModifiersMask: CGEventFlags {
        var flags: CGEventFlags = []
        if moveCmd { flags.insert(.maskCommand) }
        if moveCtrl { flags.insert(.maskControl) }
        if moveOpt { flags.insert(.maskAlternate) }
        if moveShift { flags.insert(.maskShift) }
        return flags
    }
    
    public var snapModifiersMask: CGEventFlags {
        var flags: CGEventFlags = []
        if snapCmd { flags.insert(.maskCommand) }
        if snapCtrl { flags.insert(.maskControl) }
        if snapOpt { flags.insert(.maskAlternate) }
        if snapShift { flags.insert(.maskShift) }
        return flags
    }
    
    public var snapDisplayString: String {
        var parts: [String] = []
        if snapCtrl { parts.append("⌃ Control") }
        if snapOpt { parts.append("⌥ Option") }
        if snapShift { parts.append("⇧ Shift") }
        if snapCmd { parts.append("⌘ Command") }
        return parts.isEmpty ? "None" : parts.joined(separator: " + ")
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
        isBatchUpdating = true
        self.moveCmd = cmd
        self.moveCtrl = ctrl
        self.moveOpt = opt
        self.moveShift = shift
        defaults.set(cmd, forKey: keyMoveCmd)
        defaults.set(ctrl, forKey: keyMoveCtrl)
        defaults.set(opt, forKey: keyMoveOpt)
        defaults.set(shift, forKey: keyMoveShift)
        isBatchUpdating = false
    }
    
    public func resetMoveResizeDefaults() {
        isBatchUpdating = true
        self.easyMoveResizeEnabled = true
        self.moveCmd = true
        self.moveCtrl = true
        self.moveOpt = false
        self.moveShift = false
        self.resizeWithRightClick = true
        self.menuBarIconStyle = .monochrome
        
        defaults.set(true, forKey: keyEasyMoveResizeEnabled)
        defaults.set(true, forKey: keyMoveCmd)
        defaults.set(true, forKey: keyMoveCtrl)
        defaults.set(false, forKey: keyMoveOpt)
        defaults.set(false, forKey: keyMoveShift)
        defaults.set(true, forKey: keyResizeWithRightClick)
        defaults.set(MenuBarIconStyle.monochrome.rawValue, forKey: keyMenuBarIconStyle)
        
        isBatchUpdating = false
    }

    public func resetSnapDefaults() {
        isBatchUpdating = true
        self.hotkeySnapEnabled = true
        self.snapCmd = false
        self.snapCtrl = true
        self.snapOpt = true
        self.snapShift = false
        self.snapBindings = PreferencesManager.defaultSnapBindings
        
        defaults.set(true, forKey: keyHotkeySnapEnabled)
        defaults.set(false, forKey: keySnapCmd)
        defaults.set(true, forKey: keySnapCtrl)
        defaults.set(true, forKey: keySnapOpt)
        defaults.set(false, forKey: keySnapShift)
        defaults.set(PreferencesManager.defaultSnapBindings, forKey: keySnapBindings)
        
        isBatchUpdating = false
        notifySnapBindingsChanged()
    }
    
    public func resetAltTabDefaults() {
        isBatchUpdating = true
        self.altTabEnabled = true
        self.altTabShowThumbnails = false
        self.altTabEnableSearch = false
        self.altTabEnableQuickNumbers = false
        self.altTabScope = .currentScreen
        self.altTabThumbnailSize = .medium
        
        defaults.set(true, forKey: keyAltTabEnabled)
        defaults.set(false, forKey: keyAltTabShowThumbnails)
        defaults.set(false, forKey: keyAltTabEnableSearch)
        defaults.set(false, forKey: keyAltTabEnableQuickNumbers)
        defaults.set(AltTabScope.currentScreen.rawValue, forKey: keyAltTabScope)
        defaults.set(AltTabThumbnailSize.medium.rawValue, forKey: keyAltTabThumbnailSize)
        
        isBatchUpdating = false
    }
}
