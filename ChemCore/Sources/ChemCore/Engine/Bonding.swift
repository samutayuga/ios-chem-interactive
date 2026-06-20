public enum BondingType: String, Equatable {
    case ionic = "Ionic", covalent = "Covalent", metallic = "Metallic"
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
