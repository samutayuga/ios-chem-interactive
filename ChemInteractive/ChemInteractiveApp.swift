import SwiftUI

@main
struct ChemInteractiveApp: App {
    @State private var model = CanvasModel()

    var body: some Scene {
        WindowGroup {
            ChemCanvasView()
                .environment(model)
                .preferredColorScheme(.dark)
                .task {
                    #if DEBUG
                    if let preview = CanvasModel.debugPreviewArgument(ProcessInfo.processInfo.arguments) {
                        model.debugSeed(preview)
                    }
                    #endif
                }
        }
    }
}
