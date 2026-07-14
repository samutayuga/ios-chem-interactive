import SwiftUI
import ChemCore

struct PolyatomicTokenView: View {
    let ion: PolyatomicIon
    var disabled: Bool = false
    var onTap: (PolyatomicIon) -> Void

    @Environment(CanvasModel.self) private var model

    private var token: TokenTransfer { TokenTransfer(symbol: ion.symbol, isPolyatomic: true) }
    private var isSelected: Bool { model.selectedToken == token }

    private var dragPreview: some View {
        Text(ion.formula)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .padding(10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.anion.opacity(0.6), lineWidth: 1))
    }

    @ViewBuilder
    var body: some View {
        let styled = Text(ion.formula)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(height: 64)
            .padding(.horizontal, 12)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.anion.opacity(0.4), lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(isSelected ? 0.8 : 0), lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 8))

        if disabled {
            styled
                .opacity(0.2)
                .allowsHitTesting(false)
        } else {
            styled
                .opacity(model.selectedToken != nil && !isSelected ? 0.5 : 1)
                .onTapGesture { onTap(ion) }
                .draggable(token) { dragPreview }
        }
    }
}
