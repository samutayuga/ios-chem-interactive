// ChemInteractive/Views/RootModeView.swift
import SwiftUI
import ChemCore

struct RootModeView: View {
    enum AppMode: String, CaseIterable { case bonding = "Bonding", reactionLab = "Reaction Lab" }

    let bondingModel: CanvasModel
    @State private var reactionModel = ReactionLabModel()
    @State private var mode: AppMode = .bonding

    @State private var tourIndex: Int?
    @AppStorage("appTourSeen") private var appTourSeen = false

    private struct Step { let mode: AppMode?; let title: String; let text: String; let image: String }

    private let tourSteps: [Step] = [
        Step(mode: .bonding, title: "Welcome!",
             text: "This app teaches chemical bonding and reactions. Here's a quick tour.", image: "flask.fill"),
        Step(mode: .bonding, title: "Two modes",
             text: "Switch between Bonding and Reaction Lab with this control at the top.", image: "rectangle.2.swap"),
        Step(mode: .bonding, title: "Periodic tray",
             text: "Tap an element to select it, then tap a flask — or long‑press and drag it. Pinch to zoom the table.", image: "square.grid.3x3.fill"),
        Step(mode: .bonding, title: "Bonding",
             text: "Drop two species into the flasks to classify the bond — ionic, covalent, or metallic — with an animated diagram.", image: "atom"),
        Step(mode: .reactionLab, title: "Reaction Lab",
             text: "Build two reactant compounds (1–2 species each), set amounts, and watch them react.", image: "testtube.2"),
        Step(mode: .reactionLab, title: "The result",
             text: "See the balanced equation, product yields, and a redox verdict. Tap “Full explanation” for the step‑by‑step.", image: "doc.text.magnifyingglass"),
        Step(mode: nil, title: "You're set!",
             text: "Tap the ? button any time to replay this tour. Have fun experimenting!", image: "checkmark.circle.fill"),
    ]

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Picker("Mode", selection: $mode) {
                        ForEach(AppMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Button { startTour() } label: {
                        Image(systemName: "questionmark.circle").font(.title3)
                    }
                    .tint(Theme.accent)
                }
                .padding(.horizontal, 12).padding(.top, 8)

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
        .overlay { if mode == .bonding && tourIndex == nil { ExplanationModalView().environment(bondingModel) } }
        .overlay { tourOverlay }
        .onChange(of: mode) { _, _ in bondingModel.clearSelection() }
        .onAppear {
            guard !appTourSeen else { return }
            appTourSeen = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { startTour() }
        }
    }

    @ViewBuilder private var tourOverlay: some View {
        if let i = tourIndex {
            let s = tourSteps[i]
            GuidedTourOverlay(
                title: s.title, text: s.text, systemImage: s.image,
                index: i, total: tourSteps.count,
                onBack: { goTo(i - 1) },
                onNext: { i + 1 < tourSteps.count ? goTo(i + 1) : endTour() },
                onSkip: endTour
            )
        }
    }

    private func startTour() { goTo(0) }

    private func goTo(_ i: Int) {
        guard i >= 0, i < tourSteps.count else { return }
        if let m = tourSteps[i].mode { mode = m }
        withAnimation(.easeInOut(duration: 0.2)) { tourIndex = i }
    }

    private func endTour() {
        withAnimation(.easeInOut(duration: 0.2)) { tourIndex = nil }
    }
}
