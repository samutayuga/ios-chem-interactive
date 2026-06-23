// ChemInteractive/Views/Bridge/ReactantQuantityPopover.swift
import SwiftUI
import ChemCore

/// Hover popover letting the user set a reactant's quantity + unit. Writes a
/// `ReactantEntry?` (nil when blank/invalid). Diatomic elements show a notice.
struct ReactantQuantityPopover: View {
    let symbol: String
    @Binding var entry: ReactantEntry?
    /// This reactant's slot and the current solved result, used to show the
    /// per-reactant detail (role + yield) inside the popover. Optional so the
    /// view still works as a plain quantity editor.
    var slot: Slot? = nil
    var result: StoichResult? = nil
    var productFormula: String = ""

    @State private var text: String = ""
    @State private var unit: QuantityUnit = .mole
    @FocusState private var fieldFocused: Bool

    private var isDiatomic: Bool { naturallyDiatomic.contains(symbol) }

    private func fmt(_ v: Double) -> String { String(format: "%.3g", v) }

    private var isLimiting: Bool {
        guard let r = result, let slot else { return false }
        return (slot == .a && r.limiting == .a) || (slot == .b && r.limiting == .b)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quantity of \(symbol)").font(.caption.weight(.semibold))
            HStack(spacing: 6) {
                // Numeric field: ≥48pt tap target, decimal keypad, distinct focus ring.
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($fieldFocused)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .padding(.horizontal, 10)
                    .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(fieldFocused ? Theme.accent : Theme.accent.opacity(0.35),
                                    lineWidth: fieldFocused ? 2.5 : 1)
                    )
                    .shadow(color: fieldFocused ? Theme.accent.opacity(0.5) : .clear, radius: 5)
                    .animation(.easeOut(duration: 0.15), value: fieldFocused)
                    .onChange(of: text) { _, _ in sync() }
                Picker("", selection: $unit) {
                    Text("mol").tag(QuantityUnit.mole)
                    Text("g").tag(QuantityUnit.mass)
                }
                .pickerStyle(.segmented)
                .frame(width: 88)
                .onChange(of: unit) { _, _ in sync() }
            }
            if isDiatomic {
                Text("\(symbol) cannot exist as monoatomic, It only exist in \(symbol)₂")
                    .font(.caption2).foregroundStyle(.orange)
            }
            detailSection
        }
        .padding(12)
        .frame(width: 240)
        .fixedSize(horizontal: false, vertical: true)
        .presentationCompactAdaptation(.popover)
        .onAppear {
            if let e = entry { text = trimmed(e.value); unit = e.unit }
            // Defer a tick so focus lands after the popover finishes presenting.
            DispatchQueue.main.async { fieldFocused = true }
        }
    }

    /// Per-reactant result: its role in the reaction + the theoretical yield.
    @ViewBuilder private var detailSection: some View {
        if let r = result {
            Divider().overlay(Theme.accent.opacity(0.3))
            if r.limiting == .both {
                Text("Stoichiometric — fully consumed")
                    .font(.caption2).foregroundStyle(Theme.text)
            } else if isLimiting {
                Text("Limiting reactant")
                    .font(.caption2.weight(.semibold)).foregroundStyle(Theme.accent)
            } else {
                Text("Excess: \(fmt(r.excess.moles)) mol (\(fmt(r.excess.mass)) g) left over")
                    .font(.caption2).foregroundStyle(Theme.text)
            }
            Text("Yield: \(fmt(r.yield.moles)) mol (\(fmt(r.yield.mass)) g) \(productFormula)")
                .font(.caption2).foregroundStyle(Theme.text)
        }
    }

    private func trimmed(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v)
    }

    /// Parse the field; positive number -> ReactantEntry, else nil.
    private func sync() {
        guard let v = Double(text), v > 0 else { entry = nil; return }
        entry = ReactantEntry(value: v, unit: unit)
    }
}
