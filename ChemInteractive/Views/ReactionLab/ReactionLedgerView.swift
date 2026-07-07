// ChemInteractive/Views/ReactionLab/ReactionLedgerView.swift
import SwiftUI
import ChemCore

struct ReactionLedgerView: View {
    let outcome: LedgerOutcome

    var body: some View {
        switch outcome {
        case .reaction(let r):
            posterCard(r)
        case .noReaction(let msg):
            NoReactionView(badge: "No reaction", message: msg, tone: .warn)
        case .notClassified(let msg):
            NoReactionView(badge: "Not classified", message: msg, tone: .neutral)
        case .cannotBalance(let msg):
            NoReactionView(badge: "Can’t balance", message: msg, tone: .neutral)
        }
    }

    // MARK: - Poster

    private func posterCard(_ r: ReactionResult) -> some View {
        VStack(spacing: 12) {
            ReactionTypeBadge(text: ReactionLedgerFormat.classLabel(r.reactionClass))

            Text(ReactionLedgerFormat.equation(r))
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)

            Divider().overlay(Theme.accent.opacity(0.3))

            productChips(r)

            Text(ReactionLedgerFormat.footer(r))
                .font(.caption2).foregroundStyle(Theme.text.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)

            compactRedox(analyzeRedox(r))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Theme.surface, Theme.bg],
                                     startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
        .shadow(color: Theme.accent.opacity(0.25), radius: 10, y: 4)
    }

    /// Compact product yield chips that wrap into rows — space-efficient when a
    /// reaction has two or three products.
    private func productChips(_ r: ReactionResult) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], spacing: 6) {
            ForEach(Array(zip(r.products, r.yields).enumerated()), id: \.offset) { _, pair in
                let (p, y) = pair
                VStack(spacing: 1) {
                    Text(p.coeff > 1 ? "\(p.coeff) \(p.formula)" : p.formula)
                        .font(.caption.weight(.bold)).foregroundStyle(.white)
                    Text("\(num(y.moles)) mol · \(num(y.mass)) g")
                        .font(.system(size: 9)).foregroundStyle(Theme.text.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6).padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.cation.opacity(0.14)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cation.opacity(0.3), lineWidth: 0.5))
            }
        }
    }

    /// One-line redox summary for the compact inline card; full detail lives in the sheet.
    private func compactRedox(_ a: RedoxAnalysis) -> some View {
        let redColor = Color(hex: 0xff9040)
        return HStack(spacing: 8) {
            Text(a.isRedox ? "REDOX" : "NON-REDOX")
                .font(.caption2.weight(.bold)).tracking(1)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill((a.isRedox ? redColor : Theme.muted).opacity(0.3)))
                .foregroundStyle(a.isRedox ? redColor : Theme.text.opacity(0.75))
            if let agents = ReactionLedgerFormat.redoxAgents(a) {
                Text(agents).font(.caption2).foregroundStyle(Theme.text.opacity(0.75)).lineLimit(1)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func num(_ v: Double) -> String { String(format: "%.2f", v) }
}
