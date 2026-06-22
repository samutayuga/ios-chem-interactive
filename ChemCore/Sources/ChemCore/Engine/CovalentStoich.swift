private func shellTarget(_ ve: Int) -> Int { ve <= 2 ? 2 : 8 }
private func bondsNeeded(_ ve: Int) -> Int { max(0, shellTarget(ve) - ve) }

public func calcStoich(veA: Int, veB: Int) -> (nA: Int, nB: Int, bondOrder: Int) {
    let bA = bondsNeeded(veA), bB = bondsNeeded(veB)
    if bA == 0 || bB == 0 { return (1, 1, 1) }
    let g = gcd(bA, bB)
    return (nA: bB / g, nB: bA / g, bondOrder: g)
}

/// True when two non-metals of the same group but different periods would, by the
/// octet rule alone, form a 1:1 double bond. Orbital-size mismatch makes that simple
/// double bond inefficient, so the structure resolves to one central + two peripheral
/// atoms. The "1:1 double bond" condition is only satisfiable by valence-6 (Group 16)
/// atoms, so groups 14/15/17 are excluded automatically — no hardcoded group check.
public func isOrbitalMismatchDoubleBond(groupA: Int, periodA: Int, veA: Int,
                                        groupB: Int, periodB: Int, veB: Int) -> Bool {
    guard groupA == groupB, periodA != periodB else { return false }
    let base = calcStoich(veA: veA, veB: veB)
    return base.nA == 1 && base.nB == 1 && base.bondOrder == 2
}

/// Covalent stoichiometry with the orbital-mismatch "double-bond rule" applied.
/// When the rule fires, the larger atom (higher period) is central (count 1) and the
/// smaller atom is peripheral (count 2), each bond a double bond. Otherwise this is
/// the pure octet `calcStoich`.
public func covalentStoich(veA: Int, groupA: Int, periodA: Int,
                           veB: Int, groupB: Int, periodB: Int) -> (nA: Int, nB: Int, bondOrder: Int) {
    if isOrbitalMismatchDoubleBond(groupA: groupA, periodA: periodA, veA: veA,
                                   groupB: groupB, periodB: periodB, veB: veB) {
        return periodA > periodB ? (nA: 1, nB: 2, bondOrder: 2)
                                 : (nA: 2, nB: 1, bondOrder: 2)
    }
    return calcStoich(veA: veA, veB: veB)
}

private let iupacOrder: [String: Int] = [
    "B": 1, "Si": 2, "C": 3, "Sb": 4, "As": 5, "P": 6, "N": 7, "H": 8,
    "Te": 9, "Se": 10, "S": 11, "O": 12, "I": 13, "Br": 14, "Cl": 15, "F": 16,
]

/// True when symbol A is written first (lower or equal IUPAC index; unknown symbols rank 0).
public func iupacFirst(_ symbolA: String, _ symbolB: String) -> Bool {
    (iupacOrder[symbolA] ?? 0) <= (iupacOrder[symbolB] ?? 0)
}
