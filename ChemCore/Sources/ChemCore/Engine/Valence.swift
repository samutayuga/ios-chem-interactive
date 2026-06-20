import Foundation

public func groupToValenceFallback(_ group: Int) -> Int {
    if group <= 2 { return group }
    if group >= 13 { return group - 10 }
    return 0
}

public func isTransitionMetal(_ group: Int) -> Bool {
    group >= 3 && group <= 12
}

public func parseValenceElectrons(config: String, group: Int) -> Int {
    // Strip a noble-gas prefix e.g. "[Ne] 3s2" -> "3s2".
    let stripped = config
        .replacingOccurrences(of: #"\[[A-Z][a-z]?\]\s*"#, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespaces)
    if stripped.isEmpty { return groupToValenceFallback(group) }

    var subshells: [(n: Int, count: Int)] = []
    for token in stripped.split(whereSeparator: { $0.isWhitespace }) {
        if let m = token.wholeMatch(of: /^(\d)[spdf](\d+)$/),
           let n = Int(m.1), let count = Int(m.2) {
            subshells.append((n, count))
        }
    }
    if subshells.isEmpty { return groupToValenceFallback(group) }

    let maxN = subshells.map(\.n).max()!
    return subshells.filter { $0.n == maxN }.reduce(0) { $0 + $1.count }
}
