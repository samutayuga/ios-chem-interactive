import Foundation

public enum ReactionClass: String, Equatable, Sendable {
    case synthesis, doubleDisplacement, singleDisplacement, combustion, none
}

func isDioxygen(_ r: Reactant) -> Bool {
    r.composition.count == 1 && r.composition["O"] == 2
}
private func isFuel(_ r: Reactant) -> Bool {
    r.composition["C"] != nil || r.composition["H"] != nil || r.isBareElement
}
private func isIonicCompound(_ r: Reactant) -> Bool {
    r.cation != nil && r.anion != nil
}

public func classifyReaction(_ r1: Reactant, _ r2: Reactant) -> ReactionClass {
    // 1. Combustion: one side is O₂, the other burns.
    if (isDioxygen(r1) && isFuel(r2) && !isDioxygen(r2))
        || (isDioxygen(r2) && isFuel(r1) && !isDioxygen(r1)) {
        return .combustion
    }
    // 2. Single displacement: exactly one bare element + one ionic compound.
    if (r1.isBareElement && isIonicCompound(r2)) || (r2.isBareElement && isIonicCompound(r1)) {
        return .singleDisplacement
    }
    // 3. Double displacement: both ionic compounds.
    if isIonicCompound(r1) && isIonicCompound(r2) {
        return .doubleDisplacement
    }
    // 4. Synthesis: two bare elements.
    if r1.isBareElement && r2.isBareElement {
        return .synthesis
    }
    return .none
}
