// ChemInteractive/Theme/ReactionLedgerFormat.swift
import ChemCore

enum LedgerOutcome: Equatable {
    case reaction(ReactionResult)
    case noReaction(String)
    case notClassified(String)
    case cannotBalance(String)
}

enum ReactionLedgerFormat {
    static let notClassifiedNudge =
        "These two don’t form a reaction this lab can predict. Try an acid + base, a metal + salt, or a fuel + O₂."

    static func outcome(_ result: Result<ReactionResult, ReactionError>?) -> LedgerOutcome? {
        guard let result else { return nil }
        switch result {
        case .success(let r):
            return r.feasible ? .reaction(r) : .noReaction(r.messages.first ?? "No reaction occurs.")
        case .failure(let e):
            switch e {
            case .unknownReactionClass, .noProducts: return .notClassified(notClassifiedNudge)
            case .unbalanceable, .missingAtomicMass: return .cannotBalance("This reaction can’t be balanced here.")
            }
        }
    }

    static func classLabel(_ c: ReactionClass) -> String {
        switch c {
        case .synthesis: return "Synthesis"
        case .doubleDisplacement: return "Double displacement"
        case .singleDisplacement: return "Single displacement"
        case .combustion: return "Combustion"
        case .none: return "Not classified"
        }
    }

    static func equation(_ r: ReactionResult) -> String {
        let lhs = r.reactants.map(term).joined(separator: " + ")
        let rhs = r.products.map(term).joined(separator: " + ")
        return "\(lhs) → \(rhs)"
    }
    private static func term(_ t: BalancedTerm) -> String {
        t.coeff > 1 ? "\(t.coeff)\(t.formula)" : t.formula
    }

    static func productLines(_ r: ReactionResult) -> [String] {
        zip(r.products, r.yields).map { p, y in
            "\(p.coeff) \(p.formula) — \(num(y.moles)) mol · \(num(y.mass)) g"
        }
    }

    static func footer(_ r: ReactionResult) -> String {
        let lim: String
        switch r.limiting {
        case .a:    lim = "limiting: \(r.reactants[0].formula)"
        case .b:    lim = "limiting: \(r.reactants[1].formula)"
        case .both: lim = "stoichiometric — no limiting reactant"
        }
        if r.excess.moles > 0 {
            let exFormula = r.limiting == .a ? r.reactants[1].formula : r.reactants[0].formula
            return "\(lim) · \(exFormula) excess \(num(r.excess.moles)) mol"
        }
        return lim
    }

    private static func num(_ v: Double) -> String { String(format: "%.2f", v) }

    static func redoxBadge(_ a: RedoxAnalysis) -> String {
        a.isRedox ? "Redox" : "Non-redox"
    }

    static func redoxAgents(_ a: RedoxAnalysis) -> String? {
        guard a.isRedox, let ox = a.oxidisingAgent, let red = a.reducingAgent else { return nil }
        return "Oxidising: \(ox) · Reducing: \(red)"
    }
}
