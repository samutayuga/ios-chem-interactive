import Foundation

private func lcm(_ a: Int, _ b: Int) -> Int { a == 0 || b == 0 ? 0 : abs(a / gcd(a, b) * b) }

/// Balance a reaction to the smallest positive integer coefficients, ordered
/// reactants-then-products. Returns nil when no all-positive solution exists.
public func balance(reactants: [[String: Int]], products: [[String: Int]]) -> [Int]? {
    let species = reactants + products
    let n = species.count
    guard n >= 2 else { return nil }

    // Distinct elements → matrix rows. Reactants positive, products negative.
    let elements = Array(Set(species.flatMap { $0.keys })).sorted()
    var m: [[Fraction]] = elements.map { el in
        (0..<n).map { j in
            let count = species[j][el] ?? 0
            let sign = j < reactants.count ? 1 : -1
            return Fraction(sign * count)
        }
    }

    // Gaussian elimination to reduced row echelon form.
    var pivotCols: [Int] = []
    var row = 0
    for col in 0..<n {
        guard let pivot = (row..<m.count).first(where: { !m[$0][col].isZero }) else { continue }
        m.swapAt(row, pivot)
        let inv = Fraction(m[row][col].den, m[row][col].num)
        m[row] = m[row].map { $0 * inv }
        for r in 0..<m.count where r != row && !m[r][col].isZero {
            let factor = m[r][col]
            m[r] = zip(m[r], m[row]).map { $0 + (Fraction(-factor.num, factor.den) * $1) }
        }
        pivotCols.append(col)
        row += 1
        if row == m.count { break }
    }

    // Exactly one free column → unique ratio. Otherwise reject.
    let freeCols = (0..<n).filter { !pivotCols.contains($0) }
    guard freeCols.count == 1, let free = freeCols.first else { return nil }

    // Set free variable = 1; pivots = -matrix[pivotRow][free].
    var solution = [Fraction](repeating: Fraction(0), count: n)
    solution[free] = Fraction(1)
    for (rowIndex, col) in pivotCols.enumerated() {
        solution[col] = Fraction(-m[rowIndex][free].num, m[rowIndex][free].den)
    }

    // Scale to integers: multiply by LCM of denominators.
    let denLCM = solution.reduce(1) { lcm($0, $1.den) }
    var ints = solution.map { $0.num * (denLCM / $0.den) }

    // Normalise sign so coefficients are positive, then divide by GCD.
    if ints.contains(where: { $0 < 0 }) && ints.allSatisfy({ $0 <= 0 }) {
        ints = ints.map { -$0 }
    }
    guard ints.allSatisfy({ $0 > 0 }) else { return nil }
    let g = ints.reduce(0) { gcd($0, $1) }
    guard g > 0 else { return nil }
    return ints.map { $0 / g }
}
