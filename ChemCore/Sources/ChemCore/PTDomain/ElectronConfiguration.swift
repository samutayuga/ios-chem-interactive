public struct ElectronConfiguration: Equatable {
    public let orbitals: [Orbital]

    /// Renders in standard (n, l) order, e.g. "1s2 2s2 2p6 3s2 3p6 3d6 4s2".
    public var description: String {
        orbitals
            .sorted { ($0.n, $0.subshell.azimuthal) < ($1.n, $1.subshell.azimuthal) }
            .map { "\($0.n)\($0.subshell.label)\($0.electrons)" }
            .joined(separator: " ")
    }

    /// Total number of unpaired electrons (Hund's rule).
    public var unpairedElectrons: Int {
        orbitals.reduce(0) { acc, o in
            let half = o.subshell.orbitalCount
            let unpaired = o.electrons <= half ? o.electrons : 2 * half - o.electrons
            return acc + unpaired
        }
    }

    /// Electrons in a specific (n, subshell), or 0 if absent.
    public func electrons(in n: Int, _ subshell: Subshell) -> Int {
        orbitals.first { $0.n == n && $0.subshell == subshell }?.electrons ?? 0
    }
}

/// Known ground-state anomalies: absolute occupancies for the orbitals that
/// deviate from naive Aufbau. Orbitals set to 0 are dropped after applying.
private let anomalies: [Int: [(n: Int, subshell: Subshell, electrons: Int)]] = [
    24: [(3, .d, 5), (4, .s, 1)],   // Cr
    29: [(3, .d, 10), (4, .s, 1)],  // Cu
    41: [(4, .d, 4), (5, .s, 1)],   // Nb
    42: [(4, .d, 5), (5, .s, 1)],   // Mo
    44: [(4, .d, 7), (5, .s, 1)],   // Ru
    45: [(4, .d, 8), (5, .s, 1)],   // Rh
    46: [(4, .d, 10), (5, .s, 0)],  // Pd
    47: [(4, .d, 10), (5, .s, 1)],  // Ag
    57: [(4, .f, 0), (5, .d, 1)],   // La
    58: [(4, .f, 1), (5, .d, 1)],   // Ce
    64: [(4, .f, 7), (5, .d, 1)],   // Gd
    78: [(5, .d, 9), (6, .s, 1)],   // Pt
    79: [(5, .d, 10), (6, .s, 1)],  // Au
    89: [(5, .f, 0), (6, .d, 1)],   // Ac
    90: [(5, .f, 0), (6, .d, 2)],   // Th
    91: [(5, .f, 2), (6, .d, 1)],   // Pa
    92: [(5, .f, 3), (6, .d, 1)],   // U
    93: [(5, .f, 4), (6, .d, 1)],   // Np
    96: [(5, .f, 7), (6, .d, 1)],   // Cm
]

/// Ground-state electron configuration for atomic number `z`.
public func electronConfiguration(_ z: Int) throws -> ElectronConfiguration {
    try validate(z)
    var orbitals = aufbauFill(z)
    if let overrides = anomalies[z] {
        for o in overrides {
            if let idx = orbitals.firstIndex(where: { $0.n == o.n && $0.subshell == o.subshell }) {
                orbitals[idx].electrons = o.electrons
            } else {
                orbitals.append(Orbital(n: o.n, subshell: o.subshell, electrons: o.electrons))
            }
        }
        orbitals.removeAll { $0.electrons == 0 }
    }
    return ElectronConfiguration(orbitals: orbitals)
}
