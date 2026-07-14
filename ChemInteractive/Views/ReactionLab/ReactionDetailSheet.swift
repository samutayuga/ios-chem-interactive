// ChemInteractive/Views/ReactionLab/ReactionDetailSheet.swift
import SwiftUI
import ChemCore

/// The reaction explanation the compact inline card doesn't show: the color-coded
/// redox agents + per-element oxidation-state changes, and the full narrative — each
/// sentence in its own tinted "post" card (warm = oxidised, cool = reduced).
struct ReactionDetailSheet: View {
    let result: ReactionResult
    @Environment(\.dismiss) private var dismiss

    private let oxColor = Color(hex: 0xff9040)   // oxidised / reducing agent — warm
    private let redColor = Color(hex: 0x40c0ff)  // reduced / oxidising agent — cool

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
                VStack(alignment: .center, spacing: 16) {
                    Text(ReactionLedgerFormat.equation(result))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white).minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .center)

                    RedoxSectionView(analysis: redox)

                    if !redox.narrative.isEmpty {
                        Text("STEP BY STEP").font(.caption2.weight(.bold)).tracking(1)
                            .foregroundStyle(Theme.text.opacity(0.55))
                        ForEach(redox.narrative, id: \.self) { line in
                            narrativeCard(line)
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    /// One explanation sentence as a tinted card with a left accent bar.
    private func narrativeCard(_ line: String) -> some View {
        let tint = narrativeTint(line)
        return HStack(alignment: .top, spacing: 10) {
            Capsule().fill(tint).frame(width: 3)
            Text(line).font(.subheadline).foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.3), lineWidth: 1))
    }

    private func narrativeTint(_ line: String) -> Color {
        if line.contains("reducing agent") { return oxColor }
        if line.contains("oxidising agent") { return redColor }
        if line.contains("oxidised") { return oxColor }
        if line.contains("reduced") { return redColor }
        return Theme.accent
    }
}
