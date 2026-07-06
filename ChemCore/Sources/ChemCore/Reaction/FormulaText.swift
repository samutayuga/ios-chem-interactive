import Foundation

private let subscriptDigits: [Character: Character] = [
    "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
    "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
]

/// Unicode subscript for a count; empty string when n <= 1.
public func formulaSubscript(_ n: Int) -> String {
    guard n > 1 else { return "" }
    return String(String(n).map { subscriptDigits[$0] ?? $0 })
}

/// gcd-reduced crossover subscripts from ionic charges (magnitudes crossed over).
public func crossoverSubscripts(cationCharge: Int, anionCharge: Int) -> (cationSub: Int, anionSub: Int) {
    let cc = abs(cationCharge)
    let ac = abs(anionCharge)
    let g = max(1, gcd(cc, ac))
    return (cationSub: ac / g, anionSub: cc / g)
}

/// Assemble a two-part formula. The second part is parenthesised only when it is a
/// polyatomic ion carrying a subscript > 1 (e.g. "(NH₄)₂SO₄", but "NaOH").
public func binaryFormula(first: String, firstCount: Int,
                          second: String, secondCount: Int,
                          secondIsPolyatomic: Bool) -> String {
    let firstPart = firstIsWrapped(first) && firstCount > 1
        ? "(\(first))\(formulaSubscript(firstCount))"
        : "\(first)\(formulaSubscript(firstCount))"
    let secondPart = secondIsPolyatomic && secondCount > 1
        ? "(\(second))\(formulaSubscript(secondCount))"
        : "\(second)\(formulaSubscript(secondCount))"
    return firstPart + secondPart
}

/// A leading polyatomic cation (e.g. NH₄) needs parentheses when it repeats.
private func firstIsWrapped(_ symbol: String) -> Bool {
    symbol.count > 2 && symbol.contains { $0.isNumber || subscriptDigits.values.contains($0) }
}
