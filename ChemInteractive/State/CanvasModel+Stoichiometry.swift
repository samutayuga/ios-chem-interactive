import ChemCore

/// Stoichiometry derived from the current slots + per-slot quantities. Centralised
/// here so the bridge (equation) and the reactant popovers (per-reactant detail)
/// read one source of truth. Reuses the same product subscripts the diagrams use.
extension CanvasModel {
    private func atomicMass(_ symbol: String) -> Double? {
        elements.first { $0.symbol == symbol }?.atomicMass
    }

    private func reactantSpec(_ zone: ZoneState, subscriptInProduct: Int,
                              entry: ReactantEntry?) -> ReactantSpec? {
        guard let m = atomicMass(zone.symbol) else { return nil }
        return ReactantSpec(symbol: zone.symbol, atomicMass: m,
                            subscriptInProduct: subscriptInProduct,
                            isDiatomic: naturallyDiatomic.contains(zone.symbol),
                            entry: entry)
    }

    /// (subscript of slotA, subscript of slotB) in the product. Ionic uses the
    /// crossover subscripts mapped back to slot order; covalent uses covalentStoich.
    private func productSubscripts(_ a: ZoneState, _ b: ZoneState) -> (Int, Int)? {
        switch state.bondingType {
        case .ionic:
            let pair = ionicPair(a, b)
            let cm = crossoverModel(cation: pair.cation, anion: pair.anion)
            let aIsCation = pair.cation.symbol == a.symbol
            return aIsCation ? (cm.cationSub, cm.anionSub) : (cm.anionSub, cm.cationSub)
        case .covalent:
            let s = covalentStoich(veA: a.valenceElectrons, groupA: a.group, periodA: a.period,
                                   veB: b.valenceElectrons, groupB: b.group, periodB: b.period)
            return (s.nA, s.nB)
        default:
            return nil
        }
    }

    /// The solved stoichiometry for the current reaction, or nil when not applicable.
    var stoichResult: StoichResult? {
        guard let a = state.slotA, let b = state.slotB,
              let subs = productSubscripts(a, b),
              let specA = reactantSpec(a, subscriptInProduct: subs.0, entry: quantityA),
              let specB = reactantSpec(b, subscriptInProduct: subs.1, entry: quantityB)
        else { return nil }
        return solveStoichiometry(a: specA, b: specB)
    }

    /// Single-unit product formula (e.g. "NaCl", "H₂O"); the panel prepends the coefficient.
    var productFormula: String {
        guard let a = state.slotA, let b = state.slotB else { return "" }
        switch state.bondingType {
        case .ionic:
            let pair = ionicPair(a, b)
            if let cc = pair.cation.derivedCharge, let ac = pair.anion.derivedCharge {
                return ionicFormula(cationSymbol: pair.cation.symbol, cationCharge: cc,
                                    anionSymbol: pair.anion.symbol, anionCharge: ac,
                                    anionIsPolyatomic: pair.anion.isPolyatomic)
            }
            return ""
        case .covalent:
            let s = covalentStoich(veA: a.valenceElectrons, groupA: a.group, periodA: a.period,
                                   veB: b.valenceElectrons, groupB: b.group, periodB: b.period)
            let homo = a.symbol == b.symbol
            let aFirst = iupacFirst(a.symbol, b.symbol)
            let fst = aFirst ? a.symbol : b.symbol
            let fstN = aFirst ? s.nA : s.nB
            let snd = aFirst ? b.symbol : a.symbol
            let sndN = aFirst ? s.nB : s.nA
            return homo
                ? "\(a.symbol)\((s.nA + s.nB) > 1 ? subscriptGlyphs(s.nA + s.nB) : "")"
                : "\(fst)\(fstN > 1 ? subscriptGlyphs(fstN) : "")\(snd)\(sndN > 1 ? subscriptGlyphs(sndN) : "")"
        default:
            return ""
        }
    }
}
