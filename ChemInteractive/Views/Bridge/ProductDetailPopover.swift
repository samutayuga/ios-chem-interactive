// ChemInteractive/Views/Bridge/ProductDetailPopover.swift
import SwiftUI
import ChemCore

/// Small popover shown when the product term in the balanced equation is tapped.
/// Reports the theoretical yield of the product.
struct ProductDetailPopover: View {
    let result: StoichResult
    let productFormula: String

    private func fmt(_ v: Double) -> String { String(format: "%.2f", v) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(productFormula).font(.caption.weight(.semibold))
            Text("Yield: \(fmt(result.yield.moles)) mol (\(fmt(result.yield.mass)) g)")
                .font(.caption2).foregroundStyle(Theme.text)
            if result.limiting == .both {
                Text("Reactants fully consumed (stoichiometric)")
                    .font(.caption2).foregroundStyle(Theme.text.opacity(0.8))
            }
        }
        .padding(12)
        .frame(width: 220)
        .fixedSize(horizontal: false, vertical: true)
        .presentationCompactAdaptation(.popover)
    }
}
