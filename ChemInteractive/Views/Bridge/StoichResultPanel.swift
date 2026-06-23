// ChemInteractive/Views/Bridge/StoichResultPanel.swift
import SwiftUI
import ChemCore

/// Renders a StoichResult: balanced equation, limiting reactant, yield, excess.
struct StoichResultPanel: View {
    let result: StoichResult
    let symbolA: String
    let symbolB: String
    let productFormula: String

    private func fmt(_ v: Double) -> String { String(format: "%.3g", v) }

    private var limitingSymbol: String? {
        switch result.limiting {
        case .a: return symbolA
        case .b: return symbolB
        case .both: return nil
        }
    }

    private var equationText: String {
        let e = result.equation
        func term(_ coeff: Int, _ sym: String, _ molecularity: Int) -> String {
            let unit = molecularity == 2 ? "\(sym)₂" : sym
            return coeff == 1 ? unit : "\(coeff)\(unit)"
        }
        let lhs = "\(term(e.coeffA, symbolA, e.molecularityA)) + \(term(e.coeffB, symbolB, e.molecularityB))"
        let rhs = e.coeffProduct == 1 ? productFormula : "\(e.coeffProduct)\(productFormula)"
        return "\(lhs) → \(rhs)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(equationText).font(.callout.weight(.semibold))
            if let lim = limitingSymbol {
                Text("Limiting reactant: \(lim)").font(.caption)
            } else {
                Text("Stoichiometric (no limiting reactant)").font(.caption)
            }
            Text("Theoretical yield: \(fmt(result.yield.moles)) mol (\(fmt(result.yield.mass)) g) \(productFormula)")
                .font(.caption)
            if result.excess.moles > 0 {
                let sym = result.limiting == .a ? symbolB : symbolA
                Text("Excess: \(fmt(result.excess.moles)) mol (\(fmt(result.excess.mass)) g) \(sym) remaining")
                    .font(.caption)
            }
            ForEach(result.diatomicMessages, id: \.self) { msg in
                Text(msg).font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
