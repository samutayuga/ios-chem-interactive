// ChemInteractive/Views/Bridge/ReactantQuantityPopover.swift
import SwiftUI
import ChemCore

/// Hover popover letting the user set a reactant's quantity + unit. Writes a
/// `ReactantEntry?` (nil when blank/invalid). Diatomic elements show a notice.
struct ReactantQuantityPopover: View {
    let symbol: String
    @Binding var entry: ReactantEntry?

    @State private var text: String = ""
    @State private var unit: QuantityUnit = .mole
    @FocusState private var fieldFocused: Bool

    var body: some View {
        // Narrow layout (unit on its own line) so the popover can't cover the
        // other reactant or its knob.
        VStack(alignment: .leading, spacing: 8) {
            // Numeric field: ≥48pt tap target, decimal keypad, distinct focus ring.
            TextField("0.00", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($fieldFocused)
                .accessibilityLabel("Quantity of \(symbol)")
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
            .onChange(of: unit) { _, _ in sync() }
        }
        .padding(12)
        .frame(width: 150)
        .fixedSize(horizontal: false, vertical: true)
        .presentationCompactAdaptation(.popover)
        .onAppear {
            if let e = entry { text = formatted(e.value); unit = e.unit }
            // Defer a tick so focus lands after the popover finishes presenting.
            DispatchQueue.main.async { fieldFocused = true }
        }
    }

    /// Two-decimal display for the seeded value.
    private func formatted(_ v: Double) -> String { String(format: "%.2f", v) }

    /// Parse the field; positive number -> ReactantEntry, else nil.
    private func sync() {
        guard let v = Double(text), v > 0 else { entry = nil; return }
        entry = ReactantEntry(value: v, unit: unit)
    }
}
