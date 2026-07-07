// ChemInteractive/Views/ReactionLab/ReactionLabTourSheet.swift
import SwiftUI

/// A short instructional tour for Reaction Lab: numbered steps as tinted cards.
/// Shown automatically on first entry and reopenable from the "?" button.
struct ReactionLabTourSheet: View {
    @Environment(\.dismiss) private var dismiss

    private struct Step: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(icon: "hand.tap",
             title: "Pick a reactant",
             detail: "Tap an element in the tray, then tap a reactant zone — or long‑press and drag it in."),
        Step(icon: "plus.circle",
             title: "Build a compound",
             detail: "Add up to two species per zone to form a compound, e.g. Na + OH → NaOH. One species stays a bare element."),
        Step(icon: "scalemass",
             title: "Set the amount",
             detail: "Tap ⚖ on each reactant to enter a quantity in moles or grams. Leave blank for stoichiometric amounts."),
        Step(icon: "doc.text.magnifyingglass",
             title: "Read the result",
             detail: "See the balanced equation, product yields, and a redox verdict. Tap “Full explanation” for the step‑by‑step."),
        Step(icon: "sparkles",
             title: "Try these",
             detail: "NaOH + HCl · Zn + CuSO₄ · CH₄ + O₂. Non‑reacting pairs show a “no reaction” note."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("How to use Reaction Lab").font(.headline).foregroundStyle(Theme.text)
                Spacer()
                Button("Done") { dismiss() }.font(.body.weight(.semibold)).foregroundStyle(Theme.accent)
            }
            .padding()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        stepCard(number: index + 1, step)
                    }
                }
                .padding(20)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func stepCard(number: Int, _ step: Step) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.25)).frame(width: 34, height: 34)
                Text("\(number)").font(.headline).foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Label(step.title, systemImage: step.icon)
                    .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text(step.detail)
                    .font(.caption).foregroundStyle(Theme.text.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.25), lineWidth: 1))
    }
}
