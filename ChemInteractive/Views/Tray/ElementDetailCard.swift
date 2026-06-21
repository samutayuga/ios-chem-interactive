import SwiftUI
import ChemCore

/// Width of the header row (glyph + attributes, incl. the group name); drives
/// the card width so the electron config wraps to it instead of widening the card.
private struct CardHeaderWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct ElementDetailCard: View {
    let element: Element
    var disabled: Bool = false
    let onClose: () -> Void

    @State private var headerWidth: CGFloat = 0

    private var token: TokenTransfer { TokenTransfer(symbol: element.symbol, isPolyatomic: false) }
    private var glyphColor: Color { elementClassColor(element.elementClass) }

    var body: some View {
        CardChrome(onClose: onClose, dim: 0.15, blocking: false, width: nil) {
            HStack(alignment: .center, spacing: 12) {
                if disabled {
                    atomGlyph
                } else {
                    atomGlyph.draggable(token) { dragPreview }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(element.name).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.text)
                    Text(element.elementClass.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(glyphColor)
                    Text(element.category.rawValue)
                        .font(.system(size: 12)).foregroundStyle(Theme.text.opacity(0.7))
                    Text(periodicGroupName(for: element))
                        .font(.system(size: 12)).foregroundStyle(Theme.text.opacity(0.8))
                    Text("Period \(element.period)")
                        .font(.system(size: 12)).foregroundStyle(Theme.text.opacity(0.8))
                }
            }
            .background(GeometryReader { g in
                Color.clear.preference(key: CardHeaderWidthKey.self, value: g.size.width)
            })
            .padding(.bottom, 8)

            // Wrap the electron config to the header (group-name-driven) width.
            Text(superscriptElectronCounts(element.electronConfiguration))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: headerWidth > 0 ? headerWidth : nil, alignment: .leading)
                .padding(.bottom, 10)

            if !element.oxidationStates.isEmpty {
                Text("Oxidation: " + element.oxidationStates.map { $0 > 0 ? "+\($0)" : "\($0)" }.joined(separator: ", "))
                    .font(.system(size: 12)).foregroundStyle(Theme.text.opacity(0.8))
                    .frame(width: headerWidth > 0 ? headerWidth : nil, alignment: .leading)
                    .padding(.bottom, 12)
            }
        }
        .onPreferenceChange(CardHeaderWidthKey.self) { headerWidth = $0 }
    }

    // Standard periodic-table notation: mass number (A) as left-superscript,
    // atomic number (Z) as left-subscript, left of the chemical symbol.
    private var atomGlyph: some View {
        HStack(alignment: .center, spacing: 4) {
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(element.massNumber)")
                Text("\(element.atomicNumber)")
            }
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Theme.text.opacity(0.9))
            Text(element.symbol)
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(glyphColor)
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

struct PolyatomicDetailCard: View {
    let ion: PolyatomicIon
    var disabled: Bool = false
    let onClose: () -> Void

    private var token: TokenTransfer { TokenTransfer(symbol: ion.symbol, isPolyatomic: true) }

    var body: some View {
        CardChrome(onClose: onClose, dim: 0.15, blocking: false, width: nil) {
            Group {
                if disabled {
                    formulaGlyph
                } else {
                    formulaGlyph.draggable(token) { dragPreview }
                }
            }
            .padding(.bottom, 6)
            Text(ion.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text)
            Text("Charge \(ion.charge > 0 ? "+\(ion.charge)" : "\(ion.charge)")")
                .font(.system(size: 12)).foregroundStyle(Theme.text.opacity(0.8))
                .padding(.bottom, 12)
        }
    }

    private var formulaGlyph: some View {
        Text(ion.formula)
            .font(.system(size: 44, weight: .bold))
            .foregroundStyle(.white)
    }

    private var dragPreview: some View {
        Text(ion.formula).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            .padding(8).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
