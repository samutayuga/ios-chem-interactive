// ChemInteractive/Views/BondingCanvas.swift
import SwiftUI
import ChemCore

/// The bonding-mode canvas (flasks + bridge), extracted from the former
/// ChemCanvasView so RootModeView can host the shared tray above it.
struct BondingCanvas: View {
    @Environment(CanvasModel.self) private var model

    var body: some View {
        if model.state.canvasPhase == .stoichiometry {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    DropZoneView(slot: .a).frame(maxWidth: .infinity)
                    DropZoneView(slot: .b).frame(maxWidth: .infinity)
                }
                BridgeView().frame(maxWidth: .infinity)
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                DropZoneView(slot: .a).frame(maxWidth: .infinity)
                BridgeView().frame(maxWidth: .infinity)
                DropZoneView(slot: .b).frame(maxWidth: .infinity)
            }
        }
    }
}
