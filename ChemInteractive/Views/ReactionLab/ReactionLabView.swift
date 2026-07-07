// ChemInteractive/Views/ReactionLab/ReactionLabView.swift
import SwiftUI
import ChemCore

struct ReactionLabView: View {
    @Environment(ReactionLabModel.self) private var model
    @State private var pulse = false
    @State private var showFailure = false
    @State private var failureTitle = ""
    @State private var failureMessage = ""
    @State private var activeSheet: LabSheet?
    @AppStorage("reactionLabTourSeen") private var tourSeen = false

    // A single sheet driver — SwiftUI honours only one `.sheet` per view.
    private enum LabSheet: String, Identifiable { case tour, detail; var id: String { rawValue } }

    private var fireKey: String {
        "\(model.quantity1?.unit.rawValue ?? "-")|\(model.quantity2?.unit.rawValue ?? "-")"
    }
    private var bothSet: Bool { model.quantity1 != nil && model.quantity2 != nil }

    /// A failing outcome (title + message) when both reactants resolve but don't react;
    /// nil for a successful reaction or an incomplete build.
    private var failure: (title: String, message: String)? {
        switch ReactionLedgerFormat.outcome(model.result) {
        case .noReaction(let m):    return ("No reaction", m)
        case .notClassified(let m): return ("Not classified", m)
        case .cannotBalance(let m): return ("Can’t balance", m)
        default:                    return nil
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { activeSheet = .tour } label: {
                    Image(systemName: "questionmark.circle").font(.title3)
                }
                .tint(Theme.accent)
                Spacer()
                Button { model.reset() } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise").font(.caption)
                }
                .buttonStyle(.bordered).tint(Theme.accent)
            }
            HStack(alignment: .top, spacing: 6) {
                ReactantZoneView(zone: 1).frame(maxWidth: .infinity)
                Text("+").font(.title3).foregroundStyle(.secondary)
                ReactantZoneView(zone: 2).frame(maxWidth: .infinity)
            }
            Text("↓").font(.title2).foregroundStyle(Theme.accent.opacity(0.7))

            if let outcome = ReactionLedgerFormat.outcome(model.result) {
                if case .reaction = outcome {
                    ReactionLedgerView(outcome: outcome)
                        .scaleEffect(pulse ? 1.05 : 1)
                        .overlay { if pulse { ReactionBurst() } }
                    Button { activeSheet = .detail } label: {
                        Label("Full explanation", systemImage: "text.magnifyingglass")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered).tint(Theme.accent)
                } else {
                    // Failing reaction — surfaced as a modal (below), not inline.
                    Text("No reaction — adjust the reactants.")
                        .font(.footnote).foregroundStyle(.secondary).padding()
                }
            } else {
                Text("Add a reactant to each side.")
                    .font(.footnote).foregroundStyle(.secondary).padding()
            }
        }
        .onChange(of: fireKey) { _, _ in if bothSet { fire() } }
        .onChange(of: failure?.message) { _, _ in
            if let f = failure {
                failureTitle = f.title
                failureMessage = f.message
                showFailure = true
            } else {
                showFailure = false
            }
        }
        .alert(failureTitle, isPresented: $showFailure) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failureMessage)
        }
        .sheet(item: $activeSheet) { which in
            switch which {
            case .tour:
                ReactionLabTourSheet()
            case .detail:
                if case .success(let r)? = model.result, r.feasible {
                    ReactionDetailSheet(result: r)
                }
            }
        }
        .onAppear { if !tourSeen { activeSheet = .tour; tourSeen = true } }
    }

    private func fire() {
        SoundFX.reaction()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.3)) { pulse = false }
        }
    }
}
