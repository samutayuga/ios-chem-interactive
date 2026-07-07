// ChemInteractive/Views/ReactionLab/ReactionDetailSheet.swift
import SwiftUI
import ChemCore

/// The reaction explanation the compact inline card doesn't show: the color-coded
/// redox agents + per-element oxidation-state changes, and the full narrative.
/// A short equation header gives context (the inline card already shows yields).
struct ReactionDetailSheet: View {
    let result: ReactionResult
    @Environment(\.dismiss) private var dismiss

    private var redox: RedoxAnalysis { analyzeRedox(result) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Explanation").font(.headline).foregroundStyle(Theme.text)
                Spacer()
                Button("Done") { dismiss() }.font(.body.weight(.semibold)).foregroundStyle(Theme.accent)
            }
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(ReactionLedgerFormat.equation(result))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white).minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .center)

                    RedoxSectionView(analysis: redox)

                    if !redox.narrative.isEmpty {
                        Text("STEP BY STEP").font(.caption2.weight(.bold)).tracking(1)
                            .foregroundStyle(Theme.text.opacity(0.55))
                        ForEach(redox.narrative, id: \.self) { line in
                            Text(line).font(.subheadline).foregroundStyle(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
    }
}
