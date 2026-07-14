import Foundation

/// Metal reactivity, most reactive first (standard school activity series, H included).
public let metalActivitySeries: [String] = [
    "K", "Na", "Li", "Ca", "Mg", "Al", "Zn", "Fe", "Ni", "Sn", "Pb",
    "H", "Cu", "Ag", "Hg", "Au",
]

/// Halogen reactivity, most reactive first.
public let halogenActivitySeries: [String] = ["F", "Cl", "Br", "I"]

/// True when `free` can displace `bound` from a compound: `free` is higher (more
/// reactive) in a shared series. nil when the two share no series.
public func displaces(_ free: String, over bound: String) -> Bool? {
    for series in [metalActivitySeries, halogenActivitySeries] {
        if let f = series.firstIndex(of: free), let b = series.firstIndex(of: bound) {
            return f < b
        }
    }
    return nil
}
