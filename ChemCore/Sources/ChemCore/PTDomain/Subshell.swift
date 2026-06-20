public enum Subshell: CaseIterable, Sendable {
    case s, p, d, f

    public var azimuthal: Int {
        switch self { case .s: 0; case .p: 1; case .d: 2; case .f: 3 }
    }
    public var capacity: Int {
        switch self { case .s: 2; case .p: 6; case .d: 10; case .f: 14 }
    }
    public var orbitalCount: Int { 2 * azimuthal + 1 }
    public var label: Character {
        switch self { case .s: "s"; case .p: "p"; case .d: "d"; case .f: "f" }
    }
}

public struct Orbital: Equatable {
    public let n: Int
    public let subshell: Subshell
    public var electrons: Int

    public init(n: Int, subshell: Subshell, electrons: Int) {
        self.n = n; self.subshell = subshell; self.electrons = electrons
    }
}
