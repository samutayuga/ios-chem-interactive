// ChemInteractive/Views/Bridge/StoichResultPanel.swift
import SwiftUI
import ChemCore

/// The balanced reaction equation, on its own. Per-reactant detail (limiting,
/// yield, excess, diatomic notes) lives in each reactant's popover to keep this
/// box uncluttered.
struct StoichResultPanel: View {
    let result: StoichResult
    let symbolA: String
    let symbolB: String
    let productFormula: String

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
        Text(equationText)
            .font(.callout.weight(.semibold))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .padding(.vertical, 10).padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
