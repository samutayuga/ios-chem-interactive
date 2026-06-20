import SwiftUI
import ChemCore

struct BridgeView: View {
    @Environment(CanvasModel.self) private var model

    private var state: CanvasState { model.state }

    var body: some View {
        VStack(spacing: 16) {
            Text("⇌").font(.system(size: 28)).foregroundStyle(Theme.accent.opacity(0.6))

            switch state.canvasPhase {
            case .animatingCrossover:
                // Plan 2 stub: immediately advance the phase machine. Plan 3 animates here.
                // Defer one runloop turn so the phase mutation doesn't run during the
                // view update that presented this branch (avoids the SwiftUI
                // "Modifying state during view update" runtime warning).
                ProgressView()
                    .tint(Theme.accent)
                    .onAppear {
                        DispatchQueue.main.async { model.send(.crossoverComplete) }
                    }

            case .complete:
                if let a = state.slotA, let b = state.slotB {
                    IonicCompletePlaceholder(slotA: a, slotB: b) { model.send(.reset) }
                }

            case .showingCovalent:
                if let a = state.slotA, let b = state.slotB {
                    CovalentPlaceholder(slotA: a, slotB: b) { model.send(.reset) }
                }

            case .showingMetallic:
                if let a = state.slotA, let b = state.slotB {
                    MetallicPlaceholder(slotA: a, slotB: b) { model.send(.reset) }
                }

            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
