// ChemInteractive/Views/ReactionLab/ReactionLabView.swift
import SwiftUI
import ChemCore

struct ReactionLabView: View {
    @Environment(ReactionLabModel.self) private var model
    @State private var pulse = false

    private var fireKey: String {
        "\(model.quantity1?.unit.rawValue ?? "-")|\(model.quantity2?.unit.rawValue ?? "-")"
    }
    private var bothSet: Bool { model.quantity1 != nil && model.quantity2 != nil }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 6) {
                ReactantZoneView(zone: 1).frame(maxWidth: .infinity)
                Text("+").font(.title3).foregroundStyle(.secondary)
                ReactantZoneView(zone: 2).frame(maxWidth: .infinity)
            }
            Text("↓").font(.title2).foregroundStyle(Theme.accent.opacity(0.7))

            if let outcome = ReactionLedgerFormat.outcome(model.result) {
                ReactionLedgerView(outcome: outcome)
                    .scaleEffect(pulse ? 1.05 : 1)
                    .overlay { if pulse { ReactionBurst() } }
            } else {
                Text("Add a reactant to each side.")
                    .font(.footnote).foregroundStyle(.secondary).padding()
            }

            Button { model.reset() } label: {
                Label("Reset", systemImage: "arrow.counterclockwise").font(.caption)
            }
        }
        .onChange(of: fireKey) { _, _ in if bothSet { fire() } }
    }

    private func fire() {
        SoundFX.reaction()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.3)) { pulse = false }
        }
    }
}
