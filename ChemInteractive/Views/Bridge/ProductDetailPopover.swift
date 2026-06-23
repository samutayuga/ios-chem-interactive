// ChemInteractive/Views/Bridge/ProductDetailPopover.swift
import SwiftUI
import ChemCore

/// Popover shown when the product term in the balanced equation is tapped: a
/// formula badge + "Product" pill, the theoretical yield, and a footer banner
/// when the reactants were in an exact ratio.
struct ProductDetailPopover: View {
    let result: StoichResult
    let productFormula: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            StoichMetricRow(icon: "atom", tint: Theme.accent, title: "Yield",
                            moles: result.yield.moles, mass: result.yield.mass)
            if result.limiting == .both { exactBanner }
        }
        .padding(14)
        .frame(width: 230)
        .fixedSize(horizontal: false, vertical: true)
        .presentationCompactAdaptation(.popover)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(productFormula)
                .font(.headline.weight(.bold)).foregroundStyle(.white)
                .padding(.horizontal, 10).frame(height: 34)
                .background(Theme.accent.opacity(0.25), in: Capsule())
                .overlay(Capsule().stroke(Theme.accent.opacity(0.7), lineWidth: 1.5))
            Text("Product")
                .font(.caption2.weight(.semibold)).foregroundStyle(Theme.accent)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Theme.accent.opacity(0.18), in: Capsule())
                .overlay(Capsule().stroke(Theme.accent.opacity(0.5), lineWidth: 1))
            Spacer()
        }
    }

    private var exactBanner: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption2).foregroundStyle(.green)
            Text("Stoichiometric ratio — no limiting reagent")
                .font(.caption2).foregroundStyle(.green)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
