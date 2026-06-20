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
