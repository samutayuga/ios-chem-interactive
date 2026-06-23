import SwiftUI
import ChemCore

struct ChemCanvasView: View {
    @Environment(CanvasModel.self) private var model

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ElementTrayView()
                    .frame(height: geo.size.height * 0.45)

                ScrollView {
                    canvas.padding(12)
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .overlay { ExplanationModalView() }
    }

    @ViewBuilder private var canvas: some View {
        if model.state.canvasPhase == .stoichiometry {
            // Stoichiometry: flasks side by side, result spans full width below it
            // so the balanced equation has room to render on one line.
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    DropZoneView(slot: .a).frame(maxWidth: .infinity)
                    DropZoneView(slot: .b).frame(maxWidth: .infinity)
                }
                BridgeView().frame(maxWidth: .infinity)
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                DropZoneView(slot: .a).frame(maxWidth: .infinity)
                BridgeView().frame(maxWidth: .infinity)
                DropZoneView(slot: .b).frame(maxWidth: .infinity)
            }
        }
    }
}
