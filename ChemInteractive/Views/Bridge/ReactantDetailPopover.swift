// ChemInteractive/Views/Bridge/ReactantDetailPopover.swift
import SwiftUI
import ChemCore

/// Small popover shown when a reactant term in the balanced equation is tapped.
/// Reports that reactant's role in the reaction and the theoretical yield.
struct ReactantDetailPopover: View {
    let symbol: String
    let slot: Slot
    let result: StoichResult
    let productFormula: String

    private func fmt(_ v: Double) -> String { String(format: "%.3g", v) }

    private var isLimiting: Bool {
        (slot == .a && result.limiting == .a) || (slot == .b && result.limiting == .b)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(symbol).font(.caption.weight(.semibold))

            if result.limiting == .both {
                Text("Stoichiometric — fully consumed")
                    .font(.caption2).foregroundStyle(Theme.text)
            } else if isLimiting {
                Text("Limiting reactant")
                    .font(.caption2.weight(.semibold)).foregroundStyle(Theme.accent)
            } else {
                Text("Excess: \(fmt(result.excess.moles)) mol (\(fmt(result.excess.mass)) g) left over")
                    .font(.caption2).foregroundStyle(Theme.text)
            }

            Text("Yield: \(fmt(result.yield.moles)) mol (\(fmt(result.yield.mass)) g) \(productFormula)")
                .font(.caption2).foregroundStyle(Theme.text)

            if naturallyDiatomic.contains(symbol) {
                Text("\(symbol) cannot exist as monoatomic, It only exist in \(symbol)₂")
                    .font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(12)
        .frame(width: 220)
        .fixedSize(horizontal: false, vertical: true)
        .presentationCompactAdaptation(.popover)
    }
}
