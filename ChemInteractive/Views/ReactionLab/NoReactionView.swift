// ChemInteractive/Views/ReactionLab/NoReactionView.swift
import SwiftUI

struct NoReactionView: View {
    enum Tone { case warn, neutral }
    let badge: String
    let message: String
    let tone: Tone

    var body: some View {
        VStack(spacing: 8) {
            ReactionTypeBadge(text: badge)
            Text(message)
                .font(.footnote).multilineTextAlignment(.center)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill((tone == .warn ? Color.red : Color.gray).opacity(0.15)))
        }
        .frame(maxWidth: .infinity)
    }
}
