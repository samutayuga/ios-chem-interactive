import SwiftUI
import ChemCore

struct ElementTrayView: View {
    @Environment(CanvasModel.self) private var model
    @State private var tab: Tab = .elements
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    @State private var detailElement: Element?
    @State private var detailIon: PolyatomicIon?

    private enum Tab { case elements, polyatomic }

    private var draggingDisabled: Bool { model.state.canvasPhase == .animatingCrossover }

    // The single filled slot, when exactly one is filled (drives hint tints + legend).
    private var firstSlot: ChemCore.ZoneState? {
        let a = model.state.slotA, b = model.state.slotB
        if a != nil && b != nil { return nil }
        return a ?? b
    }

    private func isFBlock(_ z: Int) -> Bool { (57...71).contains(z) || (89...103).contains(z) }
    private var highlightSource: Element? { detailElement }
    private func axisHighlighted(_ el: Element) -> Bool {
        guard let sel = highlightSource else { return false }
        let sameGroup = !isFBlock(el.atomicNumber) && !isFBlock(sel.atomicNumber) && el.group == sel.group
        return sameGroup || el.period == sel.period
    }
    private func isFocused(_ el: Element) -> Bool { highlightSource?.atomicNumber == el.atomicNumber }
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
            GeometryReader { geo in
                let metrics = trayCellMetrics(width: geo.size.width, height: geo.size.height)
                ScrollView([.horizontal, .vertical]) {
                    Group {
                        if tab == .elements { elementsGrid(metrics) } else { polyatomicGrid }
                    }
                    .scaleEffect(zoom * pinch, anchor: .topLeading)
                }
                .gesture(
                    MagnificationGesture()
                        .updating($pinch) { value, state, _ in state = value }
                        .onEnded { value in
                            zoom = min(4, max(1, zoom * value))
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.2)) { zoom = 1 }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface.opacity(0.5))
        .overlay {
            if let el = detailElement {
                ElementDetailCard(element: el, disabled: draggingDisabled) {
                    detailElement = nil; model.clearSelection()
                }
            } else if let ion = detailIon {
                PolyatomicDetailCard(ion: ion, disabled: draggingDisabled) {
                    detailIon = nil; model.clearSelection()
                }
            }
        }
        .onChange(of: model.selectedToken) { _, newValue in
            if newValue == nil { detailElement = nil; detailIon = nil }
        }
        .task {
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-detailElement"), i + 1 < args.count,
               let el = model.elements.first(where: { $0.symbol == args[i + 1] }) {
                detailElement = el
            }
            #endif
        }
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

    private func elementsGrid(_ m: TrayCellMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 18 columns × 7 periods. Empty cells where no element occupies (group, period).
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                ForEach(1...7, id: \.self) { period in
                    GridRow {
                        ForEach(1...18, id: \.self) { group in
                            if let el = mainElements.first(where: { $0.group == group && $0.period == period }) {
                                ElementTokenView(element: el, hint: hint(for: el), disabled: draggingDisabled,
                                                 metrics: m,
                                                 onTap: { detailElement = $0; model.select(TokenTransfer(symbol: $0.symbol, isPolyatomic: false)) },
                                                 axisHighlighted: axisHighlighted(el), focused: isFocused(el))
                            } else {
                                Color.clear.frame(width: m.cell, height: m.cell)
                            }
                        }
                    }
                }
            }
            Divider().overlay(.white.opacity(0.1))
            fBlockRow(lanthanides, label: "6f", m)
            fBlockRow(actinides, label: "7f", m)
        }
    }

    private func fBlockRow(_ els: [Element], label: String, _ m: TrayCellMetrics) -> some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 8)).foregroundStyle(.white.opacity(0.3)).frame(width: 16, alignment: .trailing)
            ForEach(els, id: \.atomicNumber) { el in
                ElementTokenView(element: el, hint: hint(for: el), disabled: draggingDisabled,
                                 metrics: m,
                                 onTap: { detailElement = $0; model.select(TokenTransfer(symbol: $0.symbol, isPolyatomic: false)) },
                                 axisHighlighted: axisHighlighted(el), focused: isFocused(el))
            }
        }
    }

    private var polyatomicGrid: some View {
        HStack(spacing: 8) {
            ForEach(model.polyatomicIons, id: \.symbol) { ion in
                PolyatomicTokenView(ion: ion, disabled: draggingDisabled,
                                    onTap: { detailIon = $0; model.select(TokenTransfer(symbol: $0.symbol, isPolyatomic: true)) })
            }
        }
    }
}
