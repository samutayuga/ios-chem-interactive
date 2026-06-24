public enum BondingType: String, Equatable, Sendable {
    case ionic = "Ionic", covalent = "Covalent", metallic = "Metallic"
}

/// Reaction-arrow glyph for the bridge between the two reactant slots.
/// `nil` (not yet classified) shows a plus; ionic and metallic syntheses
/// go to completion (`→`); covalent molecular synthesis often reaches
/// equilibrium (`⇌`).
public func reactionGlyph(for bonding: BondingType?) -> String {
    switch bonding {
    case .none:                return "+"
    case .ionic?, .metallic?:  return "→"
    case .covalent?:           return "⇌"
    }
}

public func determineBonding(_ a: ElementClass, _ b: ElementClass) -> BondingType {
    if a == .metal && b == .metal { return .metallic }
    if (a == .metalloid || a == .nonMetal) && (b == .metalloid || b == .nonMetal) { return .covalent }
    return .ionic
}

public func bondingType(aClass: ElementClass, bClass: ElementClass,
                        aPolyatomic: Bool, bPolyatomic: Bool) -> BondingType {
    if aPolyatomic || bPolyatomic { return .ionic }
    return determineBonding(aClass, bClass)
}
