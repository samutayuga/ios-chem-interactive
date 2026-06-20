import SwiftUI
import ChemCore

struct ChemCanvasView: View {
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ElementTrayView()
                    .frame(height: geo.size.height * 0.45)

                ScrollView {
                    HStack(alignment: .top, spacing: 8) {
                        DropZoneView(slot: .a).frame(maxWidth: .infinity)
                        BridgeView().frame(maxWidth: .infinity)
                        DropZoneView(slot: .b).frame(maxWidth: .infinity)
                    }
                    .padding(12)
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .overlay { ExplanationModalView() }
    }
}
