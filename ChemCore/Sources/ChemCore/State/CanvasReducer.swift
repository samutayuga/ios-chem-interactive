private func get(_ state: CanvasState, _ slot: Slot) -> ZoneState? {
    slot == .a ? state.slotA : state.slotB
}
private func set(_ state: CanvasState, _ slot: Slot, _ zone: ZoneState?) -> CanvasState {
    var s = state
    if slot == .a { s.slotA = zone } else { s.slotB = zone }
    return s
}

/// Transition/empty-oxidation zones must be deduced; otherwise ionize to the first state.
private func autoIonize(_ zone: ZoneState) -> ZoneState {
    var z = zone
    if z.isTransition { z.status = .deducing; return z }
    if z.oxidationStates.isEmpty { z.status = .deducing; return z }
    z.status = .ionized
    z.derivedCharge = z.oxidationStates[0]
    return z
}

public func canvasReducer(_ state: CanvasState, _ action: CanvasAction) -> CanvasState {
    switch action {
    case let .dropElement(slot, zone):
        var newZone = zone
        newZone.status = .neutral
        newZone.wrongCount = 0

        // Both slots filled -> new drop resets the other slot and restarts.
        if state.slotA != nil && state.slotB != nil {
            let next = set(state, slot, newZone)
            var cleared = set(next, slot.other, nil)
            cleared.canvasPhase = .slotAFilled
            cleared.bondingType = nil
            return cleared
        }

        var next = set(state, slot, newZone)
        guard let other = get(next, slot.other) else {
            next.canvasPhase = .slotAFilled
            next.bondingType = nil
            return next
        }

        let bonding = bondingType(
            aClass: newZone.elementClass, bClass: other.elementClass,
            aPolyatomic: newZone.isPolyatomic, bPolyatomic: other.isPolyatomic
        )

        if bonding == .covalent || bonding == .metallic {
            next.bondingType = bonding
            next.canvasPhase = .explaining
            return next
        }

        // Ionic — auto-ionise both slots immediately.
        let ionizedNew = autoIonize(newZone)
        let ionizedOther = autoIonize(other)
        next = set(next, slot, ionizedNew)
        next = set(next, slot.other, ionizedOther)
        next.bondingType = bonding
        next.canvasPhase = .explaining
        return next

    case let .pickTMCharge(slot, charge):
        guard var zone = get(state, slot) else { return state }
        zone.status = .ionized
        zone.derivedCharge = charge
        return set(state, slot, zone)

    case .dismissExplanation:
        if state.bondingType == .ionic
            && (state.slotA?.status == .deducing || state.slotB?.status == .deducing) {
            return state
        }
        var s = state
        switch state.bondingType {
        case .ionic:    s.canvasPhase = .animatingCrossover
        case .covalent: s.canvasPhase = .showingCovalent
        case .metallic: s.canvasPhase = .showingMetallic
        case .none:     return state
        }
        return s

    case let .replaceElement(slot):
        let other = get(state, slot.other)
        var resetOther = other
        resetOther?.status = .neutral
        resetOther?.derivedCharge = nil
        resetOther?.wrongCount = 0
        var cleared = set(state, slot, nil)
        cleared = set(cleared, slot.other, resetOther)
        cleared.canvasPhase = resetOther != nil ? .slotAFilled : .selecting
        cleared.bondingType = nil
        return cleared

    case .crossoverComplete:
        var s = state
        s.canvasPhase = .complete
        return s

    case .startStoichiometry:
        guard state.canvasPhase == .complete || state.canvasPhase == .showingCovalent else { return state }
        var s = state
        s.canvasPhase = .stoichiometry
        return s

    case .reset:
        return .initial
    }
}
