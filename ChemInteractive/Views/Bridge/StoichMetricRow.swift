// ChemInteractive/Views/Bridge/StoichMetricRow.swift
import SwiftUI

/// An icon-led amount row shared by the reactant and product detail popovers:
/// a tinted icon, a caption title, then `moles` (emphasised) and `grams` (muted).
struct StoichMetricRow: View {
    let icon: String
    let tint: Color
    let title: String
    let moles: Double
    let mass: Double

    private func fmt(_ v: Double) -> String { String(format: "%.2f", v) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15)).foregroundStyle(tint).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundStyle(Theme.text.opacity(0.7))
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(fmt(moles)) mol")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text("· \(fmt(mass)) g")
                        .font(.caption2).foregroundStyle(Theme.text.opacity(0.7))
                }
            }
            Spacer()
        }
    }
}
