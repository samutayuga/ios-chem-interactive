// ChemInteractive/Views/ReactionLab/ReactantZoneView.swift
import SwiftUI
import ChemCore

struct ReactantZoneView: View {
    let zone: Int
    @Environment(ReactionLabModel.self) private var model
    @Environment(CanvasModel.self) private var tray
    @State private var isTargeted = false
    @State private var showQuantity = false
    @State private var showMassInfo = false

    private var tokens: [ZoneState] { zone == 1 ? model.zone1 : model.zone2 }
    private var reactant: Reactant? { zone == 1 ? model.reactant1 : model.reactant2 }
    private var quantity: ReactantEntry? { zone == 1 ? model.quantity1 : model.quantity2 }
    private var pendingIndex: Int? { model.pendingCharge?.zone == zone ? model.pendingCharge?.index : nil }
    private var inviteTap: Bool { tray.selectedToken != nil }

    /// A lone atom reports Ar (relative atomic mass); a molecule/compound reports Mr
    /// (relative formula mass).
    private var massKind: String {
        guard let r = reactant else { return "Mr" }
        let distinctElements = r.composition.count
        let totalAtoms = r.composition.values.reduce(0, +)
        return (distinctElements == 1 && totalAtoms == 1) ? "Ar" : "Mr"
    }

    private var massInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(massKind == "Ar" ? "Ar — relative atomic mass" : "Mr — relative formula mass")
                .font(.headline)
            Text(massKind == "Ar"
                 ? "The mass of one atom of this element, relative to carbon‑12. Numerically the molar mass in g/mol."
                 : "The sum of the relative atomic masses (Ar) of every atom in the formula. Numerically the molar mass in g/mol.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: 260)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "\(zone).circle.fill")
                .font(.subheadline).foregroundStyle(Theme.accent.opacity(0.85))

            HStack(spacing: 8) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { idx, z in
                    tokenPill(z, index: idx)
                }
                if tokens.count < 2 {
                    Image(systemName: tokens.isEmpty ? "sparkles" : "plus.circle")
                        .font(.title3)
                        .foregroundStyle(Theme.accent.opacity(inviteTap ? 0.9 : 0.5))
                        .symbolEffect(.pulse, isActive: inviteTap)
                }
            }

            if let r = reactant {
                Button { showMassInfo = true } label: {
                    HStack(spacing: 6) {
                        Text(r.formula).font(.headline).foregroundStyle(.primary)
                        Text("\(massKind) \(String(format: "%.2f", r.molarMass)) g/mol")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Image(systemName: "info.circle").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showMassInfo) {
                    massInfoView.presentationCompactAdaptation(.popover)
                }
                quantityButton
            }

            if let i = pendingIndex, i < tokens.count {
                TransitionMetalPickerView(zone: tokens[i]) { model.pickCharge($0) }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent.opacity(isTargeted || inviteTap ? 0.16 : 0.06)))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5])))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            if let token = tray.selectedToken {
                model.place(token, inZone: zone)
                tray.clearSelection()
            }
        }
        .dropDestination(for: TokenTransfer.self) { items, _ in
            guard let t = items.first else { return false }
            model.place(t, inZone: zone)
            return true
        } isTargeted: { isTargeted = $0 }
    }

    private func tokenPill(_ z: ZoneState, index: Int) -> some View {
        Text(z.symbol)
            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Capsule().fill(z.isPolyatomic ? Color.blue : Color.green))
            .overlay(alignment: .topTrailing) {
                Button {
                    model.removeToken(zone: zone, index: index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12)).foregroundStyle(.red)
                }
                .offset(x: 5, y: -5)
            }
    }

    private var quantityButton: some View {
        Button { showQuantity = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "scalemass")
                if let q = quantity {
                    Text("\(String(format: "%.2f", q.value)) \(q.unit == .mole ? "mol" : "g")")
                }
            }
            .font(.caption).padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(.black.opacity(0.4))).foregroundStyle(.white)
        }
        .popover(isPresented: $showQuantity) {
            ReactantQuantityPopover(
                symbol: reactant?.formula ?? "",
                entry: Binding(get: { quantity }, set: { model.setQuantity($0, zone: zone) })
            )
        }
    }
}
