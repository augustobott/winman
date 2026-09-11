import CoreGraphics

/// Common virtual key codes (ANSI keyboard layout)
enum KeyCode {
    // Navigation / Control
    static let tab: CGKeyCode = 48
    static let escape: CGKeyCode = 53
    static let enter: CGKeyCode = 36
    static let backspace: CGKeyCode = 51
    
    // Arrow keys
    static let leftArrow: CGKeyCode = 123
    static let rightArrow: CGKeyCode = 124
    static let downArrow: CGKeyCode = 125
    static let upArrow: CGKeyCode = 126
    
    // Letters
    static let c: CGKeyCode = 8
    static let d: CGKeyCode = 2
    static let e: CGKeyCode = 14
    static let f: CGKeyCode = 3
    static let g: CGKeyCode = 5
    static let h: CGKeyCode = 4
    static let i: CGKeyCode = 34
    static let j: CGKeyCode = 38
    static let k: CGKeyCode = 40
    static let m: CGKeyCode = 46
    static let q: CGKeyCode = 12
    static let r: CGKeyCode = 15
    static let t: CGKeyCode = 17
    static let u: CGKeyCode = 32
    static let w: CGKeyCode = 13
    
    // Symbols / Operators
    static let minus: CGKeyCode = 27
    static let equal: CGKeyCode = 24
    
    // Numbers 1-9
    static let num1: CGKeyCode = 18
    static let num2: CGKeyCode = 19
    static let num3: CGKeyCode = 20
    static let num4: CGKeyCode = 21
    static let num5: CGKeyCode = 23
    static let num6: CGKeyCode = 22
    static let num7: CGKeyCode = 26
    static let num8: CGKeyCode = 28
    static let num9: CGKeyCode = 25
}
