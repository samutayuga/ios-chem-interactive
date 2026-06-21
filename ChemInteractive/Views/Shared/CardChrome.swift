import SwiftUI

/// Shared dimmed backdrop + card chrome. When `blocking` is true the backdrop
/// intercepts taps and dismisses on tap; when false it lets taps pass through
/// to the views beneath (non-modal) and is dismissed via the X button.
struct CardChrome<Content: View>: View {
    let onClose: () -> Void
    var dim: Double = 0.55
    var blocking: Bool = true
    var width: CGFloat? = 260   // nil → size to content (no wrapping)
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            backdrop
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(16)
            .frame(width: width)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(8)
            }
            .shadow(radius: 20)
        }
    }

    @ViewBuilder private var backdrop: some View {
        if blocking {
            Color.black.opacity(dim).ignoresSafeArea().onTapGesture { onClose() }
        } else {
            Color.black.opacity(dim).ignoresSafeArea().allowsHitTesting(false)
        }
    }
}
