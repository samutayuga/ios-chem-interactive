import SwiftUI
import ChemCore

/// High-contrast, tappable bond-type label with an info affordance. Tapping
/// opens a BondingInfoCard explaining the bond.
struct BondTypeLabel: View {
    let bonding: BondingType
    let a: ZoneState
    let b: ZoneState
    @State private var showInfo = false

    private var labelText: String {
        switch bonding {
        case .ionic: return "IONIC BOND"
        case .covalent: return "COVALENT BOND"
        case .metallic: return "METALLIC BOND"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(labelText).font(.system(size: 10, weight: .semibold)).tracking(2)
            Image(systemName: "info.circle").font(.system(size: 10))
        }
        .foregroundStyle(Theme.text.opacity(0.85))
        .contentShape(Rectangle())
        .onTapGesture { showInfo = true }
        .fullScreenCover(isPresented: $showInfo) {
            BondingInfoCard(bonding: bonding, a: a, b: b) { showInfo = false }
                .presentationBackground(.clear)
        }
    }
}
