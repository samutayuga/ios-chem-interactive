import SwiftUI
import ChemCore

struct DropZoneView: View {
    let slot: Slot
    @Environment(CanvasModel.self) private var model
    @State private var isTargeted = false

    private var zone: ChemCore.ZoneState? { slot == .a ? model.state.slotA : model.state.slotB }
    private var phase: ChemCore.CanvasPhase { model.state.canvasPhase }
    private var dropDisabled: Bool { phase == .animatingCrossover || phase == .explaining }
    private var showReplace: Bool { zone != nil && phase != .animatingCrossover }
    private var accent: Color { slot == .a ? Theme.cation : Theme.anion }
    private var hasPendingSelection: Bool { model.selectedToken != nil && !dropDisabled }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 12)
                .stroke(accent.opacity(isTargeted || hasPendingSelection ? 1 : 0.4), lineWidth: 2)
                .background(content.padding(8))
                .frame(maxWidth: .infinity, minHeight: 96)

            if showReplace {
                Button {
                    model.send(.replaceElement(slot: slot))
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 20, height: 20)
                        .background(.white.opacity(0.1), in: Circle())
                }
                .padding(8)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if let token = model.selectedToken, !dropDisabled { model.place(token, in: slot) }
        }
        .dropDestination(for: TokenTransfer.self) { items, _ in
            guard !dropDisabled, let token = items.first else { return false }
            model.place(token, in: slot)
            return true
        } isTargeted: { isTargeted = $0 }
    }

    @ViewBuilder private var content: some View {
        if let zone {
            if zone.status == .ionized, let charge = zone.derivedCharge {
                Text(formatIon(symbol: zone.symbol, charge: charge))
                    .font(.system(size: 30, weight: .bold)).foregroundStyle(accent)
            } else {
                Text(zone.symbol)
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(accent)
            }
        } else {
            Text(hasPendingSelection ? "Tap to place \(model.selectedToken!.symbol)" : "Drop here")
                .font(.system(size: 13)).foregroundStyle(accent.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
}
