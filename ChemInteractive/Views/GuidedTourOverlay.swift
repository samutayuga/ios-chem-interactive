// ChemInteractive/Views/GuidedTourOverlay.swift
import SwiftUI

/// One popup step of the app-wide guided tour: a dimmed backdrop + a card with an
/// icon, title, body, progress dots, and Skip / Back / Next controls. The host owns
/// the step index and any menu switching.
struct GuidedTourOverlay: View {
    let title: String
    let text: String
    let systemImage: String
    let index: Int
    let total: Int
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    private var isLast: Bool { index == total - 1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack {
                Spacer()
                card.padding(20)
            }
        }
        .transition(.opacity)
    }

    private var card: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage).font(.system(size: 34)).foregroundStyle(Theme.accent)
            Text(title).font(.title3.weight(.bold)).foregroundStyle(.white)
            Text(text).font(.subheadline).multilineTextAlignment(.center)
                .foregroundStyle(Theme.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in
                    Circle().fill(i == index ? Theme.accent : Theme.muted)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 2)

            HStack {
                Button("Skip", action: onSkip).foregroundStyle(Theme.text.opacity(0.7))
                Spacer()
                if index > 0 {
                    Button("Back", action: onBack).foregroundStyle(Theme.accent).padding(.trailing, 6)
                }
                Button(isLast ? "Done" : "Next", action: onNext)
                    .font(.body.weight(.bold))
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .background(Capsule().fill(Theme.accent))
                    .foregroundStyle(.white)
            }
            .font(.subheadline)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
    }
}
