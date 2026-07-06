// ChemInteractive/Views/ReactionLab/ReactionTypeBadge.swift
import SwiftUI

struct ReactionTypeBadge: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(Capsule().fill(Theme.accent.opacity(0.3)))
            .foregroundStyle(.white)
    }
}
