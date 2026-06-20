/// Madelung (n + l) fill order, covering atomic numbers 1...118.
nonisolated(unsafe) let madelungOrder: [(n: Int, subshell: Subshell)] = [
    (1, .s), (2, .s), (2, .p), (3, .s), (3, .p), (4, .s), (3, .d),
    (4, .p), (5, .s), (4, .d), (5, .p), (6, .s), (4, .f), (5, .d),
    (6, .p), (7, .s), (5, .f), (6, .d), (7, .p),
]

/// Naive Aufbau fill (before anomaly corrections), in fill order.
func aufbauFill(_ z: Int) -> [Orbital] {
    var remaining = z
    var orbitals: [Orbital] = []
    for (n, subshell) in madelungOrder {
        if remaining == 0 { break }
        let electrons = min(remaining, subshell.capacity)
        orbitals.append(Orbital(n: n, subshell: subshell, electrons: electrons))
        remaining -= electrons
    }
    return orbitals
}
