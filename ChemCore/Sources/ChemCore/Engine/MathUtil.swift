/// Greatest common divisor (Euclidean). gcd(a, 0) == a.
public func gcd(_ a: Int, _ b: Int) -> Int {
    b == 0 ? a : gcd(b, a % b)
}
