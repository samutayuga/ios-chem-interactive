import SwiftUI
import ChemCore

/// Compact explanation card for a bond type, shown when the bond-type label
/// is tapped. Reuses CardChrome and the shared explanation provider.
struct BondingInfoCard: View {
    let bonding: BondingType
    let a: ZoneState
    let b: ZoneState
    let onClose: () -> Void

    var body: some View {
        CardChrome(onClose: onClose) {
            Text(bondingTitle(bonding))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.text)
                .padding(.bottom, 8)
            Text(bondingExplanation(bonding, a, b))
                .font(.system(size: 13))
                .foregroundStyle(Theme.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
