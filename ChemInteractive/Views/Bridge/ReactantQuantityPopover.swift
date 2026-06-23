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

    private var isDiatomic: Bool { naturallyDiatomic.contains(symbol) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quantity of \(symbol)").font(.caption.weight(.semibold))
            HStack(spacing: 6) {
                TextField("0", text: $text)
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .onChange(of: text) { _, _ in sync() }
                Picker("", selection: $unit) {
                    Text("mol").tag(QuantityUnit.mole)
                    Text("g").tag(QuantityUnit.mass)
                }
                .pickerStyle(.segmented)
                .onChange(of: unit) { _, _ in sync() }
            }
            if isDiatomic {
                Text("\(symbol) cannot exist as monoatomic, It only exist in \(symbol)₂")
                    .font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(12)
        .onAppear {
            if let e = entry { text = trimmed(e.value); unit = e.unit }
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
