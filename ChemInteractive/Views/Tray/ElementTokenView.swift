import SwiftUI
import ChemCore

struct ElementTokenView: View {
    let element: Element
    var hint: BondHintKind?
    var disabled: Bool = false

    @Environment(CanvasModel.self) private var model

    private var token: TokenTransfer { TokenTransfer(symbol: element.symbol, isPolyatomic: false) }
    private var isInactive: Bool { disabled || hint == BondHintKind.none }
    private var isSelected: Bool { model.selectedToken == token }
    private var glyphColor: Color { elementClassColor(element.elementClass) }

    @ViewBuilder
    var body: some View {
        let styled = VStack(spacing: 0) {
            HStack(spacing: 2) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(element.massNumber)").font(.system(size: 7))
                    Text("\(element.atomicNumber)").font(.system(size: 7))
                }
                .foregroundStyle(Theme.text.opacity(0.65))
                Text(element.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(glyphColor)
            }
        }
        .frame(width: 38, height: 38)
        .background((hint?.tint) ?? Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(glyphColor.opacity(0.4), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(isSelected ? 0.8 : 0), lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 6))

        if isInactive {
            styled
                .opacity(0.2)
                .allowsHitTesting(false)
        } else {
            styled
                .opacity(model.selectedToken != nil && !isSelected ? 0.5 : 1)
                .draggable(token) { dragPreview }
                .onTapGesture { model.select(token) }
        }
    }

    private var dragPreview: some View {
        Text(element.symbol)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(glyphColor)
            .padding(8)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
