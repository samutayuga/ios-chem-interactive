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

    private struct Step { let mode: AppMode?; let anchor: String?; let title: String; let text: String; let image: String }

    private let tourSteps: [Step] = [
        Step(mode: .bonding, anchor: nil, title: "Welcome!",
             text: "This app teaches chemical bonding and reactions. Here's a quick tour.", image: "flask.fill"),
        Step(mode: .bonding, anchor: "modes", title: "Two modes",
             text: "Switch between Bonding and Reaction Lab with this control.", image: "rectangle.2.swap"),
        Step(mode: .bonding, anchor: "tray", title: "Periodic tray",
             text: "Tap an element to select it, then tap a flask — or long‑press and drag. Pinch to zoom.", image: "square.grid.3x3.fill"),
        Step(mode: .bonding, anchor: "canvas", title: "Bonding",
             text: "Drop two species into the flasks to classify the bond — ionic, covalent, or metallic.", image: "atom"),
        Step(mode: .reactionLab, anchor: "canvas", title: "Reaction Lab",
             text: "Build two reactant compounds (1–2 species each), set amounts, and watch them react.", image: "testtube.2"),
        Step(mode: .reactionLab, anchor: "canvas", title: "The result",
             text: "See the balanced equation, yields, and a redox verdict. Tap “Full explanation” for the step‑by‑step.", image: "doc.text.magnifyingglass"),
        Step(mode: nil, anchor: "help", title: "You're set!",
             text: "Tap this ? button to replay the tour any time. Have fun experimenting!", image: "checkmark.circle.fill"),
    ]

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Picker("Mode", selection: $mode) {
                        ForEach(AppMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .tourAnchor("modes")
                    Button { startTour() } label: {
                        Image(systemName: "questionmark.circle").font(.title3)
                    }
                    .tint(Theme.accent)
                    .tourAnchor("help")
                }
                .padding(.horizontal, 12).padding(.top, 8)

                ElementTrayView()
                    .environment(bondingModel)
                    .frame(height: geo.size.height * 0.42)
                    .tourAnchor("tray")

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
                .tourAnchor("canvas")
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .overlay { if mode == .bonding && tourIndex == nil { ExplanationModalView().environment(bondingModel) } }
        .overlayPreferenceValue(TourAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if let i = tourIndex {
                    let step = tourSteps[i]
                    let rect = step.anchor.flatMap { anchors[$0] }.map { proxy[$0] }
                    GuidedTourOverlay(
                        title: step.title, text: step.text, systemImage: step.image,
                        index: i, total: tourSteps.count,
                        targetRect: rect, containerSize: proxy.size,
                        onBack: { goTo(i - 1) },
                        onNext: { i + 1 < tourSteps.count ? goTo(i + 1) : endTour() },
                        onSkip: endTour
                    )
                }
            }
        }
        .onChange(of: mode) { _, _ in bondingModel.clearSelection() }
        .onAppear {
            guard !appTourSeen else { return }
            appTourSeen = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { startTour() }
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
