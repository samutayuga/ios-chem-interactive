// ChemInteractive/Views/Bridge/ReactantDetailPopover.swift
import SwiftUI
import ChemCore

/// Small popover shown when a reactant term in the balanced equation is tapped.
/// Reports how much of that reactant the reaction consumes, plus any leftover.
struct ReactantDetailPopover: View {
    @Environment(CanvasModel.self) private var model
    let symbol: String
    let slot: Slot

    private func fmt(_ v: Double) -> String { String(format: "%.3g", v) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(symbol).font(.caption.weight(.semibold))

            if let o = model.reactantOutcome(for: slot) {
                Text("Consumed: \(fmt(o.consumed.moles)) mol (\(fmt(o.consumed.mass)) g)")
                    .font(.caption2).foregroundStyle(Theme.text)
                if let rem = o.remaining {
                    Text("Remaining: \(fmt(rem.moles)) mol (\(fmt(rem.mass)) g)")
                        .font(.caption2).foregroundStyle(Theme.accent)
                }
            }

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
