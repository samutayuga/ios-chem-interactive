import SwiftUI

/// The small "Reset" capsule shown under each result diagram.
struct ResetButton: View {
    let action: () -> Void
    var body: some View {
        Button("Reset", action: action)
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .overlay(Capsule().stroke(Theme.muted.opacity(0.6), lineWidth: 1))
    }
}
