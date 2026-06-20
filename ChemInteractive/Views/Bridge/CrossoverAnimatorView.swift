import SwiftUI
import ChemCore

struct CrossoverAnimatorView: View {
    let cation: ZoneState
    let anion: ZoneState
    let onComplete: () -> Void

    @State private var stepIndex = 0

    private var model: CrossoverModel { crossoverModel(cation: cation, anion: anion) }

    /// Has the animation advanced to/past the frame for `step` (monotonic).
    private func reached(_ step: CrossoverStep) -> Bool {
        guard let idx = model.steps.firstIndex(of: step) else { return false }
        return stepIndex >= idx
    }

    var body: some View {
        let m = model
        HStack(alignment: .bottom, spacing: 2) {
            Text(m.cationSymbol).font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.cation)
            if m.cationSub > 1 { subscriptLabel(m.cationSub) }
            if m.showBrackets { bracket("(") }
            Text(m.anionSymbol).font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.anion)
            if m.showBrackets { bracket(")") }
            if m.anionSub > 1 { subscriptLabel(m.anionSub) }
        }
        .overlay(alignment: .top) {
            if m.showGcd, m.steps.indices.contains(stepIndex), m.steps[stepIndex] == .gcdReduce {
                Text("÷\(m.gcdValue)")
                    .font(.system(size: 12)).foregroundStyle(Color(hex: 0xfde047))
                    .offset(y: -24)
            }
        }
        .task { await runSteps() }
    }

    private func subscriptLabel(_ n: Int) -> some View {
        Text(subscriptGlyphs(n))
            .font(.system(size: 16)).foregroundStyle(.white)
            .opacity(reached(.crisscross) ? 1 : 0)
            .offset(y: reached(.crisscross) ? 0 : -12)
    }

    private func bracket(_ s: String) -> some View {
        Text(s).font(.system(size: 30)).foregroundStyle(Theme.anion)
            .opacity(reached(.brackets) ? 1 : 0)
    }

    private func runSteps() async {
        let durationNs: [CrossoverStep: UInt64] = [
            .isolate: 200_000_000, .crisscross: 600_000_000,
            .brackets: 300_000_000, .gcdReduce: 400_000_000, .done: 0,
        ]
        let steps = model.steps   // snapshot once; props are immutable for this view
        for i in steps.indices {
            withAnimation(.easeOut(duration: 0.25)) { stepIndex = i }
            let step = steps[i]
            if step == .done { break }
            try? await Task.sleep(nanoseconds: durationNs[step] ?? 400_000_000)
        }
        onComplete()   // always fires at the end → phase machine cannot softlock
    }
}

#Preview {
    CrossoverAnimatorView(
        cation: ZoneState(symbol: "Al", elementClass: .metal, isPolyatomic: false, isTransition: false,
                          valenceElectrons: 3, oxidationStates: [3], derivedCharge: 3, status: .ionized),
        anion: ZoneState(symbol: "O", elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                         valenceElectrons: 6, oxidationStates: [-2], derivedCharge: -2, status: .ionized),
        onComplete: {}
    )
    .padding(40)
    .background(Theme.bg)
}
