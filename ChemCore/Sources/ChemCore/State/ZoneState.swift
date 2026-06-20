public struct ZoneState: Equatable, Sendable {
    public var symbol: String
    public var elementClass: ElementClass
    public var isPolyatomic: Bool
    public var isTransition: Bool
    public var valenceElectrons: Int
    public var oxidationStates: [Int]
    public var derivedCharge: Int?
    public var wrongCount: Int
    public var status: ZoneStatus

    public init(symbol: String, elementClass: ElementClass, isPolyatomic: Bool,
                isTransition: Bool, valenceElectrons: Int, oxidationStates: [Int],
                derivedCharge: Int? = nil, wrongCount: Int = 0, status: ZoneStatus = .neutral) {
        self.symbol = symbol; self.elementClass = elementClass; self.isPolyatomic = isPolyatomic
        self.isTransition = isTransition; self.valenceElectrons = valenceElectrons
        self.oxidationStates = oxidationStates; self.derivedCharge = derivedCharge
        self.wrongCount = wrongCount; self.status = status
    }

    public init(element: Element) {
        self.init(
            symbol: element.symbol,
            elementClass: element.elementClass,
            isPolyatomic: false,
            isTransition: element.block == .d,
            valenceElectrons: parseValenceElectrons(config: element.electronConfiguration, group: element.group),
            oxidationStates: element.oxidationStates
        )
    }

    public init(polyatomic ion: PolyatomicIon) {
        self.init(
            symbol: ion.symbol,
            elementClass: .nonMetal,
            isPolyatomic: true,
            isTransition: false,
            valenceElectrons: 0,
            oxidationStates: [ion.charge]
        )
    }
}
