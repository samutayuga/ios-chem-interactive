import SwiftUI
import ChemCore

struct ElementTokenView: View {
    let element: Element
    var hint: BondHintKind?
    var disabled: Bool = false
    var metrics: TrayCellMetrics
    var onTap: (Element) -> Void
    var axisHighlighted: Bool = false
    var focused: Bool = false

    @Environment(CanvasModel.self) private var model

    private var token: TokenTransfer { TokenTransfer(symbol: element.symbol, isPolyatomic: false) }
    private var isInactive: Bool { disabled || hint == BondHintKind.none }
    private var isSelected: Bool { model.selectedToken == token }
    private var glyphColor: Color { elementClassColor(element.elementClass) }

    private var dragPreview: some View {
        Text(element.symbol)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(glyphColor)
            .padding(10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(glyphColor.opacity(0.6), lineWidth: 1))
    }

    @ViewBuilder
    var body: some View {
        let styled = VStack(spacing: 0) {
            HStack(spacing: 2) {
                if metrics.showCornerNumbers {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(element.massNumber)").font(.system(size: metrics.cornerFont))
                        Text("\(element.atomicNumber)").font(.system(size: metrics.cornerFont))
                    }
                    .foregroundStyle(Theme.text.opacity(0.65))
                }
                Text(element.symbol)
                    .font(.system(size: metrics.symbolFont, weight: .bold))
                    .foregroundStyle(glyphColor)
            }
        }
        .frame(width: metrics.cell, height: metrics.cell)
        .background {
            ZStack {
                (hint?.tint) ?? Theme.surface
                if axisHighlighted { Theme.accent.opacity(0.45) }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(glyphColor.opacity(0.4), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(axisHighlighted ? 0.7 : 0), lineWidth: 1.5))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(isSelected ? 0.8 : 0), lineWidth: 2))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(focused ? 1 : 0), lineWidth: 2.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))

        if isInactive {
            styled
                .opacity(0.2)
                .allowsHitTesting(false)
        } else {
            styled
                .opacity(model.selectedToken != nil && !isSelected ? 0.5 : 1)
                .onTapGesture { onTap(element) }
                .draggable(token) { dragPreview }
        }
    }
}
