// ChemInteractive/Views/GuidedTourOverlay.swift
import SwiftUI

/// Collects the on-screen frames of tour targets so the tour can highlight them.
struct TourAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Tag a view as a guided-tour target with an id.
    func tourAnchor(_ id: String) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [id: $0] }
    }
}

/// One coach-mark step: dims the screen, highlights the target frame (if any), and
/// places the popup card next to it (below when the target is in the top half, above
/// when in the bottom half; centered when there is no target).
struct GuidedTourOverlay: View {
    let title: String
    let text: String
    let systemImage: String
    let index: Int
    let total: Int
    let targetRect: CGRect?
    let containerSize: CGSize
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    private var isLast: Bool { index == total - 1 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.6).ignoresSafeArea()

            if let r = targetRect {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.accent, lineWidth: 3)
                    .frame(width: r.width + 12, height: r.height + 12)
                    .position(x: r.midX, y: r.midY)
                    .shadow(color: Theme.accent.opacity(0.8), radius: 10)
            }

            card
                .frame(maxWidth: 360)
                .position(cardCenter)
        }
    }

    private var cardCenter: CGPoint {
        let x = containerSize.width / 2
        guard let r = targetRect else {
            return CGPoint(x: x, y: containerSize.height * 0.6)
        }
        let half = containerSize.height / 2
        let y = r.midY < half
            ? min(r.maxY + 150, containerSize.height - 150)   // card below target
            : max(r.minY - 150, 170)                          // card above target
        return CGPoint(x: x, y: y)
    }

    private var card: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage).font(.system(size: 32)).foregroundStyle(Theme.accent)
            Text(title).font(.title3.weight(.bold)).foregroundStyle(.white)
            Text(text).font(.subheadline).multilineTextAlignment(.center)
                .foregroundStyle(Theme.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in
                    Circle().fill(i == index ? Theme.accent : Theme.muted).frame(width: 6, height: 6)
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
        .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
    }
}
