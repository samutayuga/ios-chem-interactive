public enum CanvasPhase: Equatable, Sendable {
    case selecting
    case slotAFilled
    case explaining
    case animatingCrossover
    case showingCovalent
    case showingMetallic
    case complete
    case stoichiometry
}

public enum Slot: Equatable {
    case a, b
    public var other: Slot { self == .a ? .b : .a }
}

public enum ZoneStatus: Equatable, Sendable {
    case neutral, deducing, ionized
}
