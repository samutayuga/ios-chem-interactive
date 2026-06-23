// ChemInteractive/Views/Bridge/ReactionBurst.swift
import SwiftUI

/// A one-shot burst played over the equation when the reaction fires: an
/// expanding ring plus sparkles flying outward, then fading. Non-interactive.
struct ReactionBurst: View {
    @State private var animate = false
    private let count = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.accent, lineWidth: 3)
                .scaleEffect(animate ? 2.4 : 0.3)
                .opacity(animate ? 0 : 0.8)

            ForEach(0..<count, id: \.self) { i in
                let angle = Double(i) / Double(count) * 2 * .pi
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(i.isMultiple(of: 2) ? Theme.cation : Theme.anion)
                    .offset(x: animate ? cos(angle) * 70 : 0,
                            y: animate ? sin(angle) * 40 : 0)
                    .scaleEffect(animate ? 0.3 : 1)
                    .opacity(animate ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.65)) { animate = true } }
    }
}
