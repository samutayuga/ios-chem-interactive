public enum Block: String, Equatable {
    case s = "S", p = "P", d = "D", f = "F"

    public init(_ subshell: Subshell) {
        switch subshell {
        case .s: self = .s; case .p: self = .p; case .d: self = .d; case .f: self = .f
        }
    }
}

/// Subshell of the differentiating electron (naive Aufbau).
func naiveBlock(_ z: Int) throws -> Subshell {
    try validate(z)
    return aufbauFill(z).last!.subshell
}

/// The block of the periodic table.
public func block(_ z: Int) throws -> Block {
    Block(try naiveBlock(z))
}

/// The period (row), from the highest principal quantum number in the naive fill.
public func period(_ z: Int) throws -> Int {
    try validate(z)
    return aufbauFill(z).map(\.n).max()!
}

/// The group (column) 1...18. f-block elements are assigned group 3 by convention.
public func group(_ z: Int) throws -> Int {
    try validate(z)
    if z == 1 { return 1 }   // Hydrogen
    if z == 2 { return 18 }  // Helium
    let config = try electronConfiguration(z)
    let p = try period(z)
    switch try naiveBlock(z) {
    case .s: return config.electrons(in: p, .s)
    case .p: return 12 + config.electrons(in: p, .p)
    case .d: return config.electrons(in: p - 1, .d) + config.electrons(in: p, .s)
    case .f: return 3
    }
}

public enum Category: String, Equatable {
    case alkaliMetal = "AlkaliMetal"
    case alkalineEarthMetal = "AlkalineEarthMetal"
    case transitionMetal = "TransitionMetal"
    case postTransitionMetal = "PostTransitionMetal"
    case metalloid = "Metalloid"
    case reactiveNonmetal = "ReactiveNonmetal"
    case nobleGas = "NobleGas"
    case halogen = "Halogen"
    case lanthanide = "Lanthanide"
    case actinide = "Actinide"
}

public enum ElementClass: String, Equatable, Sendable {
    case metal = "Metal"
    case nonMetal = "NonMetal"
    case metalloid = "Metalloid"
}

// The 7 metalloids per spec: B Si Ge As Sb Te Po (used by element_class).
private let classMetalloids: Set<Int> = [5, 14, 32, 33, 51, 52, 84]
// Category metalloids: B Si Ge As Sb Te At (note At(85), not Po).
private let categoryMetalloids: Set<Int> = [5, 14, 32, 33, 51, 52, 85]
private let postTransition: Set<Int> = [13, 31, 49, 50, 81, 82, 83, 84, 113, 114, 115, 116]

/// Broad Metal / NonMetal / Metalloid classification derived from atomic number.
public func elementClass(_ z: Int) throws -> ElementClass {
    let g = try group(z)
    if z == 1 { return .nonMetal }
    if g == 17 || g == 18 { return .nonMetal }
    if (57...71).contains(z) || (89...103).contains(z) { return .metal }
    if classMetalloids.contains(z) { return .metalloid }
    let p = try period(z)
    if p == 2 && (14...16).contains(g) { return .nonMetal }
    if p == 3 && (15...16).contains(g) { return .nonMetal }
    if p == 4 && g == 16 { return .nonMetal }
    return .metal
}

/// Best-effort element category derived from group, block, and atomic number.
public func category(_ z: Int) throws -> Category {
    try validate(z)
    let g = try group(z)
    let b = try block(z)
    if (57...71).contains(z) { return .lanthanide }
    if (89...103).contains(z) { return .actinide }
    if g == 18 { return .nobleGas }
    if g == 1 && z != 1 { return .alkaliMetal }
    if g == 2 { return .alkalineEarthMetal }
    if g == 17 { return .halogen }
    if b == .d { return .transitionMetal }
    if categoryMetalloids.contains(z) { return .metalloid }
    if postTransition.contains(z) { return .postTransitionMetal }
    return .reactiveNonmetal
}

/// Best-effort common oxidation states derived from the group.
public func oxidationStates(_ z: Int) throws -> [Int] {
    try validate(z)
    switch try group(z) {
    case 1: return [1]
    case 2: return [2]
    case 3...12: return [2, 3]
    case 13: return [3]
    case 14: return [-4, 4]
    case 15: return [-3, 3, 5]
    case 16: return [-2]
    case 17: return [-1]
    default: return [0]
    }
}
