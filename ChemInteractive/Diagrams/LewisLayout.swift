import CoreGraphics
import ChemCore

// MARK: - Cation/anion ordering (shared by ionic diagrams + ExplanationModalView)

/// Prefer derivedCharge sign (positive = cation); otherwise Metal/Metalloid is the cation.
func ionicPair(_ a: ZoneState, _ b: ZoneState) -> (cation: ZoneState, anion: ZoneState) {
    if let ca = a.derivedCharge, let cb = b.derivedCharge, ca != 0 || cb != 0 {
        return ca > 0 ? (a, b) : (b, a)
    }
    let aCation = a.elementClass == .metal || a.elementClass == .metalloid
    return aCation ? (a, b) : (b, a)
}

// MARK: - Crossover model (ionic animation)

enum CrossoverStep: Equatable { case isolate, crisscross, brackets, gcdReduce, done }

struct CrossoverModel: Equatable {
    let cationSymbol: String
    let anionSymbol: String
    let cationSub: Int       // gcd-reduced cation subscript
    let anionSub: Int        // gcd-reduced anion subscript
    let gcdValue: Int
    let showBrackets: Bool
    let showGcd: Bool
    let steps: [CrossoverStep]
}

/// Subscripts cross over (each charge → the other ion's subscript), reduced by their gcd.
func crossoverModel(cation: ZoneState, anion: ZoneState) -> CrossoverModel {
    let cc = abs(cation.derivedCharge ?? 0)
    let ac = abs(anion.derivedCharge ?? 0)
    let g = max(1, gcd(ac, cc))
    let cationSub = ac / g
    let anionSub = cc / g
    let showBrackets = anion.isPolyatomic && anionSub > 1
    let showGcd = g > 1
    var steps: [CrossoverStep] = [.isolate, .crisscross]
    if showBrackets { steps.append(.brackets) }
    if showGcd { steps.append(.gcdReduce) }
    steps.append(.done)
    return CrossoverModel(cationSymbol: cation.symbol, anionSymbol: anion.symbol,
                          cationSub: cationSub, anionSub: anionSub, gcdValue: g,
                          showBrackets: showBrackets, showGcd: showGcd, steps: steps)
}

// MARK: - Lewis electron-transfer model (ionic, both regular elements)

struct LewisTransfer: Equatable {
    let cCount: Int          // number of cations in the formula unit
    let aCount: Int          // number of anions
    let eMoved: Int          // electrons transferred per cation
    let anionAfterDots: Int  // anion's outer dots after gaining electrons (capped at 8)
}

func lewisTransfer(cation: ZoneState, anion: ZoneState) -> LewisTransfer {
    let cc = cation.derivedCharge ?? 0
    let ac = anion.derivedCharge ?? 0
    let g = max(1, gcd(abs(cc), abs(ac)))
    return LewisTransfer(cCount: abs(ac) / g, aCount: abs(cc) / g, eMoved: abs(cc),
                         anionAfterDots: min(anion.valenceElectrons + abs(ac), 8))
}

// MARK: - Electron dot ring

private let dotRing: [(dx: CGFloat, dy: CGFloat)] = [
    (22, 0), (0, -22), (-22, 0), (0, 22),     // right, top, left, bottom
    (22, -8), (8, -22), (-22, -8), (-8, 22),  // then paired
]

/// First `min(n, 8)` Lewis-dot offsets around an atom centre.
func dotPositions(_ n: Int) -> [(dx: CGFloat, dy: CGFloat)] {
    Array(dotRing.prefix(max(0, min(n, 8))))
}
