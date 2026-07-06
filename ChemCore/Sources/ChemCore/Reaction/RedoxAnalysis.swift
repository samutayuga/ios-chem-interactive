import Foundation

public enum OxidationChange: Equatable, Sendable { case oxidised, reduced, unchanged }

public struct ElementRedox: Equatable, Sendable {
    public let symbol: String
    public let before: Int
    public let after: Int
    public let change: OxidationChange
    public let reactantFormula: String
    public let productFormula: String
}

public struct RedoxAnalysis: Equatable, Sendable {
    public let isRedox: Bool
    public let oxidisingAgent: String?
    public let reducingAgent: String?
    public let changes: [ElementRedox]
    public let oxidationStates: [String: [String: Int]]
    public let indeterminate: [String]
    public let narrative: [String]
}

private func signed(_ n: Int) -> String {
    if n > 0 { return "+\(n)" }
    if n < 0 { return "−\(-n)" }   // U+2212 minus
    return "0"
}

private let empty = RedoxAnalysis(isRedox: false, oxidisingAgent: nil, reducingAgent: nil,
                                  changes: [], oxidationStates: [:], indeterminate: [], narrative: [])

/// Oxidation-state analysis of a solved reaction: redox verdict, oxidising/reducing
/// agents, per-element changes, and a template narrative. `name` maps a formula to a
/// display name (nil ⇒ use the formula). Only feasible reactions with products are analysed.
public func analyzeRedox(_ result: ReactionResult,
                         name: (String) -> String? = { _ in nil }) -> RedoxAnalysis {
    guard result.feasible, !result.products.isEmpty else { return empty }

    // Oxidation states per compound; unresolved compounds are recorded and skipped.
    var statesByFormula: [String: [String: Int]] = [:]
    var indeterminate: [String] = []
    for term in result.reactants + result.products {
        if let states = oxidationState(of: term.composition) {
            statesByFormula[term.formula] = states
        } else {
            indeterminate.append(term.formula)
        }
    }

    // element → [(formula, state)] on each side.
    func occurrences(_ terms: [BalancedTerm]) -> [String: [(formula: String, state: Int)]] {
        var map: [String: [(String, Int)]] = [:]
        for t in terms {
            guard let states = statesByFormula[t.formula] else { continue }
            for (sym, s) in states { map[sym, default: []].append((t.formula, s)) }
        }
        return map
    }
    let reactantOcc = occurrences(result.reactants)
    let productOcc = occurrences(result.products)

    var changes: [ElementRedox] = []
    for sym in Set(reactantOcc.keys).intersection(productOcc.keys).sorted() {
        let beforeStates = Set(reactantOcc[sym]!.map(\.state))
        let afterStates = Set(productOcc[sym]!.map(\.state))
        guard beforeStates.count == 1, afterStates.count == 1 else { continue } // ambiguous → skip
        let before = beforeStates.first!, after = afterStates.first!
        guard before != after else { continue }
        changes.append(ElementRedox(
            symbol: sym, before: before, after: after,
            change: after > before ? .oxidised : .reduced,
            reactantFormula: reactantOcc[sym]!.first!.formula,
            productFormula: productOcc[sym]!.first!.formula))
    }

    let isRedox = !changes.isEmpty
    let reducing = changes.first { $0.change == .oxidised }
    let oxidising = changes.first { $0.change == .reduced }

    func display(_ f: String) -> String { name(f) ?? f }
    var narrative: [String] = []
    if !isRedox {
        narrative.append("This is a non-redox reaction — no oxidation states change.")
    } else {
        for c in changes {
            let verb = c.change == .oxidised ? "oxidised" : "reduced"
            let dir = c.change == .oxidised ? "increases" : "decreases"
            narrative.append("\(display(c.reactantFormula)) is \(verb) because \(c.symbol)'s oxidation state \(dir) from \(signed(c.before)) in \(display(c.reactantFormula)) to \(signed(c.after)) in \(display(c.productFormula)).")
        }
        if let ox = oxidising, let red = reducing {
            narrative.append("\(display(ox.reactantFormula)) is the oxidising agent — it oxidises \(display(red.reactantFormula)) and is itself reduced, its oxidation state decreasing from \(signed(ox.before)) to \(signed(ox.after)).")
            narrative.append("\(display(red.reactantFormula)) is the reducing agent — it reduces \(display(ox.reactantFormula)) and is itself oxidised, its oxidation state increasing from \(signed(red.before)) to \(signed(red.after)).")
        }
    }

    return RedoxAnalysis(
        isRedox: isRedox,
        oxidisingAgent: oxidising?.reactantFormula,
        reducingAgent: reducing?.reactantFormula,
        changes: changes,
        oxidationStates: statesByFormula,
        indeterminate: indeterminate,
        narrative: narrative)
}
