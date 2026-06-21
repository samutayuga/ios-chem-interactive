import ChemCore

/// Display title for a bond type.
func bondingTitle(_ b: BondingType) -> String {
    switch b {
    case .ionic: return "Ionic Bonding"
    case .covalent: return "Covalent Bonding"
    case .metallic: return "Metallic Bonding"
    }
}

/// Plain-text explanation of a bond between two zones. Shared by the
/// at-`.explaining` modal and the tappable bond-type info card.
func bondingExplanation(_ bonding: BondingType, _ a: ZoneState, _ b: ZoneState) -> String {
    switch bonding {
    case .ionic:
        let pair = ionicPair(a, b)
        if pair.cation.status == .ionized, pair.anion.status == .ionized,
           let cc = pair.cation.derivedCharge, let ac = pair.anion.derivedCharge {
            let f = ionicFormula(cationSymbol: pair.cation.symbol, cationCharge: cc,
                                 anionSymbol: pair.anion.symbol, anionCharge: ac,
                                 anionIsPolyatomic: pair.anion.isPolyatomic)
            // Per-ion electron transfer (charge = the oxidation state used),
            // then the criss-cross that balances them into the formula.
            return "\(chargeExplanation(pair.cation)). \(chargeExplanation(pair.anion)). "
                + "The opposite charges attract; crossing them as subscripts balances the compound to \(f)."
        }
        return "The metal transfers its electron(s) to the non-metal; the opposite charges attract to form an ionic bond."
    case .covalent:
        let aN = electronsNeeded(a.valenceElectrons), bN = electronsNeeded(b.valenceElectrons)
        let share = "\(a.symbol) needs \(aN) more electron\(aN != 1 ? "s" : "") and \(b.symbol) needs \(bN) electron\(bN != 1 ? "s" : "") — they share electrons to complete their octets."
        return share + " " + covalentPairSummary(a, b)
    case .metallic:
        if a.symbol == b.symbol {
            return "Each \(a.symbol) atom contributes \(a.valenceElectrons) valence electron\(a.valenceElectrons != 1 ? "s" : "") to a delocalised electron sea. The positive metal ions are held in a lattice by electrostatic attraction to the sea of electrons."
        } else {
            return "Each \(a.symbol) atom contributes \(a.valenceElectrons) electron\(a.valenceElectrons != 1 ? "s" : "") and each \(b.symbol) atom contributes \(b.valenceElectrons) electron\(b.valenceElectrons != 1 ? "s" : ""). The positive metal ions are held in a lattice by electrostatic attraction to the sea of electrons."
        }
    }
}

/// Bonding/lone-pair counts for a covalent pair, derived from `covalentLayout`.
func covalentPairSummary(_ a: ZoneState, _ b: ZoneState) -> String {
    let l = covalentLayout(slotA: a, slotB: b)
    let central = l.centralIsA ? a : b
    let peripheral = l.centralIsA ? b : a
    let kind = l.bondOrder == 1 ? "single" : l.bondOrder == 2 ? "double" : "triple"
    return "Each bond shares \(l.bondOrder) pair\(l.bondOrder > 1 ? "s" : "") (\(kind)); "
        + "\(l.nPeripheral) bond\(l.nPeripheral > 1 ? "s" : "") total; "
        + "\(central.symbol) has \(l.centralLone) lone pair\(l.centralLone != 1 ? "s" : ""), "
        + "each \(peripheral.symbol) has \(l.peripheralLone)."
}
