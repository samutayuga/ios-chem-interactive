// ChemInteractive/Views/ReactionLab/RedoxSectionView.swift
import SwiftUI
import ChemCore

struct RedoxSectionView: View {
    let analysis: RedoxAnalysis

    var body: some View {
        VStack(spacing: 6) {
            ReactionTypeBadge(text: ReactionLedgerFormat.redoxBadge(analysis))
            if let agents = ReactionLedgerFormat.redoxAgents(analysis) {
                Text(agents).font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(analysis.narrative, id: \.self) { line in
                Text(line)
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
    }
}
