// ChemInteractive/Views/RootModeView.swift
import SwiftUI
import ChemCore

struct RootModeView: View {
    enum AppMode: String, CaseIterable { case bonding = "Bonding", reactionLab = "Reaction Lab" }

    let bondingModel: CanvasModel
    @State private var reactionModel = ReactionLabModel()
    @State private var mode: AppMode = .bonding

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(AppMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12).padding(.top, 8)

                // Shared periodic tray. Its drag payload (TokenTransfer) is
                // mode-agnostic; it stays bound to the bonding model as the catalog.
                ElementTrayView()
                    .environment(bondingModel)
                    .frame(height: geo.size.height * 0.42)

                ScrollView {
                    Group {
                        switch mode {
                        case .bonding:
                            BondingCanvas().environment(bondingModel)
                        case .reactionLab:
                            ReactionLabView()
                                .environment(reactionModel)
                                .environment(bondingModel)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .overlay { if mode == .bonding { ExplanationModalView().environment(bondingModel) } }
        .onChange(of: mode) { _, _ in bondingModel.clearSelection() }
    }
}
