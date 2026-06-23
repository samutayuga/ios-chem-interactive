public struct CanvasState: Equatable, Sendable {
    public var canvasPhase: CanvasPhase
    public var bondingType: BondingType?
    public var slotA: ZoneState?
    public var slotB: ZoneState?

    public init(canvasPhase: CanvasPhase, bondingType: BondingType?, slotA: ZoneState?, slotB: ZoneState?) {
        self.canvasPhase = canvasPhase; self.bondingType = bondingType
        self.slotA = slotA; self.slotB = slotB
    }

    public static let initial = CanvasState(
        canvasPhase: .selecting, bondingType: nil, slotA: nil, slotB: nil
    )
}

public enum CanvasAction {
    case dropElement(slot: Slot, zone: ZoneState)
    case pickTMCharge(slot: Slot, charge: Int)
    case dismissExplanation
    case replaceElement(slot: Slot)
    case crossoverComplete
    case startStoichiometry
    case reset
}
