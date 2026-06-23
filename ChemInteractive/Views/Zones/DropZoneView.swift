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

    private var highlighted: Bool { isTargeted || hasPendingSelection }
    private let liquidFill: CGFloat = 0.6

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cylinder

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
        .frame(maxWidth: .infinity, minHeight: 96)
    }

    // Bubbling potion flask: glow halo → liquid fill → rising bubbles → glass
    // outline → contents in the bulb, all inside one aspect-constrained container
    // that also owns the hit-test shape and the drop/tap gestures.
    private var cylinder: some View {
        ZStack {
            // Soft glow halo behind the bulb; intensifies when targeted/selectable.
            PotionFlaskShape()
                .fill(accent.opacity(highlighted ? 0.28 : 0.12))
                .blur(radius: highlighted ? 14 : 9)

            if let zone {
                SubstanceFill(state: resolveSubstanceState(for: zone, elements: model.elements),
                              color: elementClassColor(zone.elementClass),
                              fill: liquidFill)
                    .id(zone.symbol)   // restart the entrance animation when the element changes
            }

            // Bubbles always simmer for the potion vibe; tinted by contents when filled.
            PotionBubbles(color: zone != nil ? elementClassColor(zone!.elementClass) : accent)
                .clipShape(PotionFlaskShape())
                .opacity(0.9)

            // Glass: a faint inner sheen fill + the rim/wall outline.
            PotionFlaskShape()
                .fill(accent.opacity(0.05))
            PotionFlaskShape()
                .stroke(accent.opacity(highlighted ? 1 : 0.45), lineWidth: highlighted ? 3 : 2)

            // Contents sit in the bulb, centered.
            GeometryReader { geo in
                content
                    .frame(maxWidth: .infinity)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.66)
            }
            .padding(.horizontal, 6)
        }
        .aspectRatio(0.6, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .contentShape(PotionFlaskShape())
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
        } else if hasPendingSelection {
            VStack(spacing: 4) {
                Text(model.selectedToken!.symbol)
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(accent)
                Image(systemName: "hand.tap")
                    .font(.system(size: 16)).foregroundStyle(accent.opacity(0.8))
            }
        } else {
            // Empty + idle: sparkles cue "drop / brew here".
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundStyle(accent.opacity(0.6))
        }
    }
}
