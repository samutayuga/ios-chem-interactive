import SwiftUI
import ChemCore

struct TransitionMetalPickerView: View {
    let zone: ZoneState
    let onPick: (Int) -> Void

    private var positiveStates: [Int] { zone.oxidationStates.filter { $0 > 0 } }

    var body: some View {
        VStack(spacing: 12) {
            Text("Transition metal — pick its charge:")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: 0xfde047))
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                ForEach(positiveStates, id: \.self) { charge in
                    Button {
                        onPick(charge)
                    } label: {
                        Text("\(zone.symbol)\(superscript(charge))+")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: 0xfde047))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: 0xeab308).opacity(0.6), lineWidth: 1))
                    }
                }
            }
        }
        .padding(12)
    }
}
