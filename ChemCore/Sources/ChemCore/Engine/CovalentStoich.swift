private func shellTarget(_ ve: Int) -> Int { ve <= 2 ? 2 : 8 }
private func bondsNeeded(_ ve: Int) -> Int { max(0, shellTarget(ve) - ve) }

public func calcStoich(veA: Int, veB: Int) -> (nA: Int, nB: Int, bondOrder: Int) {
    let bA = bondsNeeded(veA), bB = bondsNeeded(veB)
    if bA == 0 || bB == 0 { return (1, 1, 1) }
    let g = gcd(bA, bB)
    return (nA: bB / g, nB: bA / g, bondOrder: g)
}

private let iupacOrder: [String: Int] = [
    "B": 1, "Si": 2, "C": 3, "Sb": 4, "As": 5, "P": 6, "N": 7, "H": 8,
    "Te": 9, "Se": 10, "S": 11, "O": 12, "I": 13, "Br": 14, "Cl": 15, "F": 16,
]

/// True when symbol A is written first (lower or equal IUPAC index; unknown symbols rank 0).
public func iupacFirst(_ symbolA: String, _ symbolB: String) -> Bool {
    (iupacOrder[symbolA] ?? 0) <= (iupacOrder[symbolB] ?? 0)
}
