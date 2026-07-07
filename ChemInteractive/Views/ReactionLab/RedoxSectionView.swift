// ChemInteractive/Views/ReactionLab/RedoxSectionView.swift
import SwiftUI
import ChemCore

/// Poster-style redox explanation: a coloured verdict header, agent callouts, and
/// per-element oxidation-state change rows (oxidised = warm/up, reduced = cool/down).
struct RedoxSectionView: View {
    let analysis: RedoxAnalysis

    private let oxColor = Color(hex: 0xff9040)   // oxidised — warm
    private let redColor = Color(hex: 0x40c0ff)  // reduced — cool

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            header
            if analysis.isRedox {
                agents
                if !analysis.changes.isEmpty {
                    Divider().overlay(Theme.accent.opacity(0.25))
                    ForEach(analysis.changes, id: \.symbol) { changeRow($0) }
                }
            } else {
                Text("No oxidation states change — every atom keeps its charge.")
                    .font(.caption).multilineTextAlignment(.center)
                    .foregroundStyle(Theme.text.opacity(0.75))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.3), lineWidth: 1))
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: analysis.isRedox ? "arrow.triangle.2.circlepath" : "equal.circle")
            Text(analysis.isRedox ? "REDOX" : "NON-REDOX")
                .font(.caption.weight(.heavy)).tracking(1.5)
        }
        .foregroundStyle(analysis.isRedox ? oxColor : Theme.text.opacity(0.6))
    }

    private var agents: some View {
        VStack(spacing: 6) {
            if let red = analysis.reducingAgent {
                agentCallout(role: "Reducing agent", formula: red, color: oxColor, icon: "arrow.up.circle.fill")
            }
            if let ox = analysis.oxidisingAgent {
                agentCallout(role: "Oxidising agent", formula: ox, color: redColor, icon: "arrow.down.circle.fill")
            }
        }
    }

    private func agentCallout(role: String, formula: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(role.uppercased()).font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color.opacity(0.9)).tracking(0.5)
                Text(formula).font(.subheadline.weight(.bold)).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.15)))
    }

    private func changeRow(_ c: ElementRedox) -> some View {
        let up = c.change == .oxidised
        let color = up ? oxColor : redColor
        return HStack(spacing: 8) {
            Text(c.symbol)
                .font(.caption.weight(.bold)).foregroundStyle(.white)
                .frame(width: 30, height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.3)))
            Text(signed(c.before)).font(.caption.monospacedDigit()).foregroundStyle(Theme.text.opacity(0.7))
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(color)
            Text(signed(c.after)).font(.caption.weight(.bold).monospacedDigit()).foregroundStyle(color)
            Image(systemName: up ? "arrow.up" : "arrow.down").font(.caption2).foregroundStyle(color)
            Text(up ? "oxidised" : "reduced").font(.caption2.weight(.semibold)).foregroundStyle(color)
        }
    }

    private func signed(_ n: Int) -> String { n > 0 ? "+\(n)" : (n < 0 ? "−\(-n)" : "0") }
}
