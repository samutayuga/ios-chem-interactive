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
    @State private var showProduct = false

    private func term(_ coeff: Int, _ sym: String, _ molecularity: Int) -> String {
        let unit = molecularity == 2 ? "\(sym)₂" : sym
        return coeff == 1 ? unit : "\(coeff)\(unit)"
    }

    private var rhs: String {
        let e = result.equation
        return e.coeffProduct == 1 ? productFormula : "\(e.coeffProduct)\(productFormula)"
    }

    /// A tappable term rendered as a tinted chip — signals "interactive" without
    /// underlines.
    private func chipLabel(_ label: String) -> some View {
        Text(label)
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Theme.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
    }

    private func reactantTerm(_ label: String, slot: Slot, show: Binding<Bool>) -> some View {
        Button { show.wrappedValue = true } label: { chipLabel(label) }
        .buttonStyle(.plain)
        .popover(isPresented: show) {
            ReactantDetailPopover(symbol: slot == .a ? symbolA : symbolB, slot: slot)
        }
    }

    var body: some View {
        let e = result.equation
        HStack(spacing: 4) {
            reactantTerm(term(e.coeffA, symbolA, e.molecularityA), slot: .a, show: $showDetailA)
            Text("+").foregroundStyle(Theme.text.opacity(0.7))
            reactantTerm(term(e.coeffB, symbolB, e.molecularityB), slot: .b, show: $showDetailB)
            Text("→").foregroundStyle(Theme.text.opacity(0.7))
            Button { showProduct = true } label: { chipLabel(rhs) }
            .buttonStyle(.plain)
            .popover(isPresented: $showProduct) {
                ProductDetailPopover(result: result, productFormula: productFormula)
            }
        }
        .font(.callout.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.vertical, 10).padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
