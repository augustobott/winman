import Foundation
import CoreGraphics

public enum WindowAction: String, CaseIterable {
    case maximize = "Maximize"
    case restore = "Restore"
    case leftHalf = "Left Half"
    case rightHalf = "Right Half"
    case topHalf = "Top Half"
    case bottomHalf = "Bottom Half"
    case topLeftQuarter = "Top Left Quarter"
    case topRightQuarter = "Top Right Quarter"
    case bottomLeftQuarter = "Bottom Left Quarter"
    case bottomRightQuarter = "Bottom Right Quarter"
    case leftThird = "Left Third"
    case centerThird = "Center Third"
    case rightThird = "Right Third"
    case leftTwoThirds = "Left Two Thirds"
    case rightTwoThirds = "Right Two Thirds"
    case center = "Center Window"
    case increaseSize = "Make Larger"
    case decreaseSize = "Make Smaller"
    case nextScreen = "Next Display"
    case prevScreen = "Previous Display"
}

public struct HotkeyBinding {
    public let action: WindowAction
    public let keyCode: CGKeyCode
    public let modifiers: CGEventFlags
    public let displayString: String
    
    public init(action: WindowAction, keyCode: CGKeyCode, modifiers: CGEventFlags, displayString: String) {
        self.action = action
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayString = displayString
    }
}

public enum AltTabScope: String, CaseIterable, Identifiable {
    case allSpaces = "All Spaces & Displays (All Open Windows)"
    case currentScreen = "Current Screen Only"
    
    public var id: String { rawValue }
}

public enum AltTabThumbnailSize: String, CaseIterable, Identifiable {
    case compact = "Compact (170pt)"
    case medium = "Medium (220pt - Default)"
    case large = "Large (280pt)"
    
    public var id: String { rawValue }
    
    public var tileWidth: CGFloat {
        switch self {
        case .compact: return 170
        case .medium: return 220
        case .large: return 280
        }
    }
    
    public var previewHeight: CGFloat {
        switch self {
        case .compact: return 85
        case .medium: return 120
        case .large: return 160
        }
    }
}

