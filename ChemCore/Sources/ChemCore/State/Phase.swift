public enum CanvasPhase: Equatable {
    case selecting
    case slotAFilled
    case explaining
    case animatingCrossover
    case showingCovalent
    case showingMetallic
    case complete
}

public enum Slot: Equatable {
    case a, b
    public var other: Slot { self == .a ? .b : .a }
}

public enum ZoneStatus: Equatable {
    case neutral, deducing, ionized
}
