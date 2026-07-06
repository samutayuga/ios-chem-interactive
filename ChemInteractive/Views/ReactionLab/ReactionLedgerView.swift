// ChemInteractive/Views/ReactionLab/ReactionLedgerView.swift
import SwiftUI
import ChemCore

struct ReactionLedgerView: View {
    let outcome: LedgerOutcome

    var body: some View {
        switch outcome {
        case .reaction(let r):
            VStack(spacing: 8) {
                ReactionTypeBadge(text: ReactionLedgerFormat.classLabel(r.reactionClass))
                Text(ReactionLedgerFormat.equation(r))
                    .font(.system(size: 16, weight: .bold))
                    .multilineTextAlignment(.center).foregroundStyle(.white)
                ForEach(ReactionLedgerFormat.productLines(r), id: \.self) { line in
                    Text(line).font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent.opacity(0.5)))
                }
                Text(ReactionLedgerFormat.footer(r)).font(.caption2).foregroundStyle(.secondary)
            }
        case .noReaction(let msg):
            NoReactionView(badge: "No reaction", message: msg, tone: .warn)
        case .notClassified(let msg):
            NoReactionView(badge: "Not classified", message: msg, tone: .neutral)
        case .cannotBalance(let msg):
            NoReactionView(badge: "Can’t balance", message: msg, tone: .neutral)
        }
    }
}
