import SwiftUI
import ChemCore

struct ElementTrayView: View {
    @Environment(CanvasModel.self) private var model
    @State private var tab: Tab = .elements

    private enum Tab { case elements, polyatomic }

    private var draggingDisabled: Bool { model.state.canvasPhase == .animatingCrossover }

    // The single filled slot, when exactly one is filled (drives hint tints + legend).
    private var firstSlot: ChemCore.ZoneState? {
        let a = model.state.slotA, b = model.state.slotB
        if a != nil && b != nil { return nil }
        return a ?? b
    }

    private func isFBlock(_ z: Int) -> Bool { (57...71).contains(z) || (89...103).contains(z) }
    private var mainElements: [Element] { model.elements.filter { !isFBlock($0.atomicNumber) } }
    private var lanthanides: [Element] { model.elements.filter { (57...71).contains($0.atomicNumber) }.sorted { $0.atomicNumber < $1.atomicNumber } }
    private var actinides: [Element] { model.elements.filter { (89...103).contains($0.atomicNumber) }.sorted { $0.atomicNumber < $1.atomicNumber } }

    private func hint(for el: Element) -> BondHintKind? {
        guard let first = firstSlot else { return nil }
        return bondHint(firstClass: first.elementClass, firstIsPolyatomic: first.isPolyatomic,
                        tokenClass: el.elementClass, tokenCategory: el.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ScrollView([.horizontal, .vertical]) {
                if tab == .elements { elementsGrid } else { polyatomicGrid }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface.opacity(0.5))
    }

    private var header: some View {
        HStack(spacing: 8) {
            tabButton("Elements", .elements)
            tabButton("Polyatomic Ions", .polyatomic)
            if firstSlot != nil { legend }
            Spacer()
        }
    }

    private func tabButton(_ title: String, _ value: Tab) -> some View {
        Button(title) { tab = value }
            .font(.system(size: 11))
            .padding(.horizontal, 12).padding(.vertical, 4)
            .foregroundStyle(tab == value ? Theme.accent : Theme.muted)
            .overlay(Capsule().stroke(tab == value ? Theme.accent : Theme.muted.opacity(0.4), lineWidth: 1))
            .background(tab == value ? Theme.accent.opacity(0.2) : .clear, in: Capsule())
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendDot(Color(hex: 0x3b82f6), "Ionic")
            legendDot(Color(hex: 0x22c55e), "Covalent")
            legendDot(Color(hex: 0xf97316), "Metallic")
        }
        .font(.system(size: 9))
        .foregroundStyle(.white.opacity(0.5))
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) { Circle().fill(color.opacity(0.8)).frame(width: 8, height: 8); Text(label) }
    }

    private var elementsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 18 columns × 7 periods. Empty cells where no element occupies (group, period).
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                ForEach(1...7, id: \.self) { period in
                    GridRow {
                        ForEach(1...18, id: \.self) { group in
                            if let el = mainElements.first(where: { $0.group == group && $0.period == period }) {
                                ElementTokenView(element: el, hint: hint(for: el), disabled: draggingDisabled)
                            } else {
                                Color.clear.frame(width: 38, height: 38)
                            }
                        }
                    }
                }
            }
            Divider().overlay(.white.opacity(0.1))
            fBlockRow(lanthanides, label: "6f")
            fBlockRow(actinides, label: "7f")
        }
    }

    private func fBlockRow(_ els: [Element], label: String) -> some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 8)).foregroundStyle(.white.opacity(0.3)).frame(width: 16, alignment: .trailing)
            ForEach(els, id: \.atomicNumber) { el in
                ElementTokenView(element: el, hint: hint(for: el), disabled: draggingDisabled)
            }
        }
    }

    private var polyatomicGrid: some View {
        HStack(spacing: 8) {
            ForEach(model.polyatomicIons, id: \.symbol) { ion in
                PolyatomicTokenView(ion: ion, disabled: draggingDisabled)
            }
        }
    }
}
