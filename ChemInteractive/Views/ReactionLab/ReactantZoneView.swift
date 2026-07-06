// ChemInteractive/Views/ReactionLab/ReactantZoneView.swift
import SwiftUI
import ChemCore

struct ReactantZoneView: View {
    let zone: Int
    @Environment(ReactionLabModel.self) private var model
    @State private var isTargeted = false
    @State private var showQuantity = false

    private var tokens: [ZoneState] { zone == 1 ? model.zone1 : model.zone2 }
    private var reactant: Reactant? { zone == 1 ? model.reactant1 : model.reactant2 }
    private var quantity: ReactantEntry? { zone == 1 ? model.quantity1 : model.quantity2 }
    private var pendingIndex: Int? { model.pendingCharge?.zone == zone ? model.pendingCharge?.index : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reactant \(zone)").font(.caption2).foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { idx, z in
                    tokenPill(z, index: idx)
                }
                if tokens.count < 2 {
                    Text(tokens.isEmpty ? "drop element / ion" : "＋ add 2nd")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            if let r = reactant {
                Text("\(r.formula) · \(String(format: "%.2f", r.molarMass)) g/mol")
                    .font(.headline).foregroundStyle(.primary)
                quantityButton
            }

            if let i = pendingIndex, i < tokens.count {
                TransitionMetalPickerView(zone: tokens[i]) { model.pickCharge($0) }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent.opacity(isTargeted ? 0.16 : 0.06)))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5])))
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
            Text(quantity.map { "\(String(format: "%.2f", $0.value)) \($0.unit == .mole ? "mol" : "g") ▾" } ?? "set amount ▾")
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
