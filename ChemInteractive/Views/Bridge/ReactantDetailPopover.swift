// ChemInteractive/Views/Bridge/ReactantDetailPopover.swift
import SwiftUI
import ChemCore

/// Popover shown when a reactant term in the balanced equation is tapped: a
/// symbol badge + role pill, then icon-led Consumed / Remaining metrics.
struct ReactantDetailPopover: View {
    @Environment(CanvasModel.self) private var model
    let symbol: String
    let slot: Slot

    private func fmt(_ v: Double) -> String { String(format: "%.2f", v) }
    private var accent: Color { slot == .a ? Theme.cation : Theme.anion }
    private var isDiatomic: Bool { naturallyDiatomic.contains(symbol) }

    // Each reactant carries a role: it runs out first (Limiting), it has a
    // leftover (Excess), or it is consumed in an exact ratio (Exact).
    private enum Role { case limiting, excess, exact }
    private var role: Role? {
        guard let r = model.stoichResult else { return nil }
        if r.limiting == .both { return .exact }
        let lim = (slot == .a && r.limiting == .a) || (slot == .b && r.limiting == .b)
        return lim ? .limiting : .excess
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let o = model.reactantOutcome(for: slot) {
                StoichMetricRow(icon: "flame.fill", tint: accent, title: "Consumed",
                                moles: o.consumed.moles, mass: o.consumed.mass)
                if let rem = o.remaining {
                    StoichMetricRow(icon: "tray.full.fill", tint: .orange, title: "Unreacted",
                                    moles: rem.moles, mass: rem.mass)
                }
            }
            if isDiatomic { diatomicNote }
        }
        .padding(14)
        .frame(width: 230)
        .fixedSize(horizontal: false, vertical: true)
        .presentationCompactAdaptation(.popover)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(symbol)
                .font(.headline.weight(.bold)).foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(accent.opacity(0.25), in: Circle())
                .overlay(Circle().stroke(accent.opacity(0.7), lineWidth: 1.5))
            if let role { roleBadge(role) }
            Spacer()
        }
    }

    private func roleBadge(_ r: Role) -> some View {
        let (label, color): (String, Color) = {
            switch r {
            case .limiting: return ("Limiting reagent", Theme.accent)
            case .excess:   return ("Excess reagent", .orange)
            case .exact:    return ("Stoichiometric", .green)
            }
        }()
        return Text(label)
            .font(.caption2.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
    }

    private var diatomicNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2).foregroundStyle(.orange)
            Text("Diatomic element — exists only as \(symbol)₂")
                .font(.caption2).foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
