import Foundation

/// Exact rational, always stored reduced with a positive denominator.
public struct Fraction: Equatable, Sendable {
    public let num: Int
    public let den: Int

    public init(_ num: Int, _ den: Int = 1) {
        precondition(den != 0, "Fraction denominator must be non-zero")
        let sign = den < 0 ? -1 : 1
        let n = num * sign
        let d = abs(den)
        if n == 0 { self.num = 0; self.den = 1; return }
        let g = gcd(abs(n), d)
        self.num = n / g
        self.den = d / g
    }

    public var isZero: Bool { num == 0 }

    public static func + (a: Fraction, b: Fraction) -> Fraction {
        Fraction(a.num * b.den + b.num * a.den, a.den * b.den)
    }

    public static func * (a: Fraction, b: Fraction) -> Fraction {
        Fraction(a.num * b.num, a.den * b.den)
    }
}
