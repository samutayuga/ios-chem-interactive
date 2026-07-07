// ChemInteractive/Views/ReactionLab/ReactionDetailSheet.swift
import SwiftUI
import ChemCore

/// Full reaction detail in a swipeable two-page sheet: Reaction (equation + yields)
/// and Redox (agents, per-element changes, and the full explanation).
struct ReactionDetailSheet: View {
    let result: ReactionResult
    @Environment(\.dismiss) private var dismiss

    private var redox: RedoxAnalysis { analyzeRedox(result) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Reaction detail").font(.headline).foregroundStyle(Theme.text)
                Spacer()
                Button("Done") { dismiss() }.font(.body.weight(.semibold)).foregroundStyle(Theme.accent)
            }
            .padding()

            TabView {
                page { reactionPage }
                page { redoxPage }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func page<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView { content().padding(20).frame(maxWidth: .infinity, alignment: .leading) }
    }

    private var reactionPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReactionTypeBadge(text: ReactionLedgerFormat.classLabel(result.reactionClass))
            Text(ReactionLedgerFormat.equation(result))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).minimumScaleFactor(0.5)

            Text("PRODUCTS").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(Theme.text.opacity(0.55))
            ForEach(ReactionLedgerFormat.productLines(result), id: \.self) { line in
                Text(line).font(.subheadline).foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cation.opacity(0.12)))
            }
            Text(ReactionLedgerFormat.footer(result)).font(.footnote).foregroundStyle(Theme.text.opacity(0.7))
        }
    }

    private var redoxPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            RedoxSectionView(analysis: redox)
            if !redox.narrative.isEmpty {
                Text("EXPLANATION").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(Theme.text.opacity(0.55))
                ForEach(redox.narrative, id: \.self) { line in
                    Text(line).font(.subheadline).foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
