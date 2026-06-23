// ChemInteractive/Views/Bridge/StoichResultPanel.swift
import SwiftUI
import ChemCore

/// The balanced reaction equation. Each reactant term is tappable and anchors a
/// small popover with that reactant's detail (role + yield), so the box itself
/// stays uncluttered.
struct StoichResultPanel: View {
    let result: StoichResult
    let symbolA: String
    let symbolB: String
    let productFormula: String

    @State private var showDetailA = false
    @State private var showDetailB = false

    private func term(_ coeff: Int, _ sym: String, _ molecularity: Int) -> String {
        let unit = molecularity == 2 ? "\(sym)₂" : sym
        return coeff == 1 ? unit : "\(coeff)\(unit)"
    }

    private var rhs: String {
        let e = result.equation
        return e.coeffProduct == 1 ? productFormula : "\(e.coeffProduct)\(productFormula)"
    }

    private func reactantTerm(_ label: String, slot: Slot, show: Binding<Bool>) -> some View {
        Button { show.wrappedValue = true } label: {
            Text(label).underline().foregroundStyle(Theme.accent)
        }
        .buttonStyle(.plain)
        .popover(isPresented: show) {
            ReactantDetailPopover(symbol: slot == .a ? symbolA : symbolB, slot: slot,
                                  result: result, productFormula: productFormula)
        }
    }

    var body: some View {
        let e = result.equation
        HStack(spacing: 3) {
            reactantTerm(term(e.coeffA, symbolA, e.molecularityA), slot: .a, show: $showDetailA)
            Text("+")
            reactantTerm(term(e.coeffB, symbolB, e.molecularityB), slot: .b, show: $showDetailB)
            Text("→")
            Text(rhs)
        }
        .font(.callout.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.vertical, 10).padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
