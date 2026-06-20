import SwiftUI
import ChemCore

extension Color {
    /// Opaque color from a 0xRRGGBB literal, in sRGB.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: 1
        )
    }
}

enum Theme {
    static let bg      = Color(hex: 0x1a0a2e)
    static let cation  = Color(hex: 0x00ff88)
    static let anion   = Color(hex: 0xff4080)
    static let accent  = Color(hex: 0x7040ff)
    static let surface = Color(hex: 0x2a1a4e)
    static let muted   = Color(hex: 0x4a3a6e)
    static let text    = Color(hex: 0xe0d0ff)
}

/// Wikipedia-style category palette, calibrated for the dark bg (from elementColor.ts).
func categoryColor(_ category: ChemCore.Category) -> Color {
    switch category {
    case .alkaliMetal:         return Color(hex: 0xff8080)
    case .alkalineEarthMetal:  return Color(hex: 0xffd280)
    case .transitionMetal:     return Color(hex: 0xe8b84b)
    case .postTransitionMetal: return Color(hex: 0x7ec8e8)
    case .metalloid:           return Color(hex: 0xa8d8a8)
    case .reactiveNonmetal:    return Color(hex: 0x80d8e8)
    case .halogen:             return Color(hex: 0xc8e830)
    case .nobleGas:            return Color(hex: 0xc8aaff)
    case .lanthanide, .actinide: return Color(hex: 0xe0d0ff)
    }
}

/// Class color used for the symbol glyph + token border (from elementColor.ts).
func elementClassColor(_ cls: ElementClass) -> Color {
    switch cls {
    case .metal:     return Color(hex: 0xffa040)
    case .nonMetal:  return Color(hex: 0x50d8f0)
    case .metalloid: return Color(hex: 0xa8d8a8)
    }
}

/// Orbital subshell colors for electron-configuration display (from ElementToken.tsx).
func orbitalColor(_ subshell: Character) -> Color {
    switch subshell {
    case "s": return Color(hex: 0x80cfff)
    case "p": return Color(hex: 0x88ff99)
    case "d": return Color(hex: 0xffc060)
    case "f": return Color(hex: 0xff90d0)
    default:  return .white
    }
}

enum BondHintKind {
    case ionic, covalent, metallic, none

    /// Tint applied behind a tray token; nil for `.none` (disabled).
    var tint: Color? {
        switch self {
        case .ionic:    return Color(hex: 0x3b82f6).opacity(0.35)  // blue-500
        case .covalent: return Color(hex: 0x22c55e).opacity(0.35)  // green-500
        case .metallic: return Color(hex: 0xf97316).opacity(0.35)  // orange-500
        case .none:     return nil
        }
    }
}

/// Prospective bond type of `token` against the already-placed `first` element.
/// Ported from ElementTray.tsx `bondHint`.
func bondHint(firstClass: ElementClass, firstIsPolyatomic: Bool,
              tokenClass: ElementClass, tokenCategory: ChemCore.Category) -> BondHintKind {
    if tokenCategory == .nobleGas { return BondHintKind.none }
    if firstIsPolyatomic { return .ionic }
    if firstClass == .metal && tokenClass == .metal { return .metallic }
    if firstClass == .nonMetal && tokenClass == .nonMetal { return .covalent }
    if (firstClass == .metalloid || firstClass == .nonMetal)
        && (tokenClass == .metalloid || tokenClass == .nonMetal) { return .covalent }
    return .ionic
}
