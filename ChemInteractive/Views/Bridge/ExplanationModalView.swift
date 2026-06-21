import SwiftUI
import ChemCore

struct ExplanationModalView: View {
    @Environment(CanvasModel.self) private var model

    private var slotA: ZoneState? { model.state.slotA }
    private var slotB: ZoneState? { model.state.slotB }
    private var bonding: BondingType? { model.state.bondingType }

    private var applyEnabled: Bool {
        guard bonding == .ionic else { return true }
        return slotA?.status != .deducing && slotB?.status != .deducing
    }

    var body: some View {
        if model.state.canvasPhase == .explaining, let a = slotA, let b = slotB, let bonding {
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    Text(label(bonding))
                        .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)

                    if bonding == .ionic {
                        VStack(spacing: 8) {
                            slotPanel(a, slot: .a)
                            slotPanel(b, slot: .b)
                        }
                    }

                    Divider().overlay(Theme.muted.opacity(0.2))
                    summary(bonding, a, b).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Button {
                        model.send(.dismissExplanation)
                    } label: {
                        Text("Apply →").font(.system(size: 14, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .foregroundStyle(applyEnabled ? Theme.accent : .white.opacity(0.3))
                    .background((applyEnabled ? Theme.accent.opacity(0.3) : .white.opacity(0.05)), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(applyEnabled ? Theme.accent : .white.opacity(0.1), lineWidth: 1))
                    .disabled(!applyEnabled)
                }
                .padding(20)
                .frame(maxWidth: 420)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.muted.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 12)
            }
        }
    }

    private func label(_ b: BondingType) -> String { bondingTitle(b) }

    @ViewBuilder private func slotPanel(_ zone: ZoneState, slot: ChemCore.Slot) -> some View {
        Group {
            if zone.status == .deducing {
                TransitionMetalPickerView(zone: zone) { charge in model.send(.pickTMCharge(slot: slot, charge: charge)) }
            } else if zone.status == .neutral {
                Text("\(zone.symbol) — charge to be determined").font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
            } else {
                Text(chargeExplanation(zone)).font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private func summary(_ bonding: BondingType, _ a: ZoneState, _ b: ZoneState) -> some View {
        Text(bondingExplanation(bonding, a, b))
    }
}
