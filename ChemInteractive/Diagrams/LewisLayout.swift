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

import Foundation

// MARK: - Covalent layout

struct CovalentLayout: Equatable {
    let centralIsA: Bool      // is slotA the central atom?
    let nPeripheral: Int
    let bondOrder: Int
    let centralLone: Int      // lone pairs on the central atom
    let peripheralLone: Int   // lone pairs on each peripheral atom
}

func covalentLayout(slotA: ZoneState, slotB: ZoneState) -> CovalentLayout {
    let s = calcStoich(veA: slotA.valenceElectrons, veB: slotB.valenceElectrons)
    let centralIsA = s.nA <= s.nB                 // central = the smaller-count atom
    let central = centralIsA ? slotA : slotB
    let peripheral = centralIsA ? slotB : slotA
    let nPeripheral = centralIsA ? s.nB : s.nA
    let centralLone = max(0, (central.valenceElectrons - s.bondOrder * nPeripheral) / 2)
    let peripheralLone = max(0, (peripheral.valenceElectrons - s.bondOrder) / 2)
    return CovalentLayout(centralIsA: centralIsA, nPeripheral: nPeripheral,
                          bondOrder: s.bondOrder, centralLone: centralLone, peripheralLone: peripheralLone)
}

/// Peripheral-atom centres for 1–4 atoms; 5+ collapses to a single atom (view adds an ×N badge).
func peripheralPositions(_ n: Int, center: CGPoint, distance d: CGFloat) -> [CGPoint] {
    switch n {
    case 1:
        return [CGPoint(x: center.x + d, y: center.y)]
    case 2:
        return [CGPoint(x: center.x - d, y: center.y), CGPoint(x: center.x + d, y: center.y)]
    case 3:
        let a = CGFloat.pi / 3
        return [CGPoint(x: center.x - d, y: center.y),
                CGPoint(x: center.x + d * cos(a), y: center.y - d * sin(a)),
                CGPoint(x: center.x + d * cos(a), y: center.y + d * sin(a))]
    case 4:
        return [CGPoint(x: center.x, y: center.y - d), CGPoint(x: center.x + d, y: center.y),
                CGPoint(x: center.x, y: center.y + d), CGPoint(x: center.x - d, y: center.y)]
    default:
        return [CGPoint(x: center.x + d, y: center.y)]
    }
}

/// `count` lone-pair directions chosen from the 8 cardinal/diagonal slots, farthest from all bonds.
func lonePairAngles(bondAngles: [Double], count: Int) -> [Double] {
    guard count > 0 else { return [] }
    let candidates = (0..<8).map { Double($0) * .pi / 4 }
    let scored = candidates.map { a -> (angle: Double, dist: Double) in
        let minDist = bondAngles.reduce(Double.pi) { m, ba in
            let diff = abs((a - ba + 3 * .pi).truncatingRemainder(dividingBy: 2 * .pi) - .pi)
            return Swift.min(m, diff)
        }
        return (a, minDist)
    }
    return scored.sorted { $0.dist > $1.dist }.prefix(count).map { $0.angle }
}

// MARK: - Metallic layout

/// A/B alternation over the 3×2 cation lattice (homonuclear → both indices map to the same symbol).
let metallicIonIndexPattern: [Int] = [0, 1, 0, 1, 0, 1]

/// Delocalised-electron count for the sea (capped at the 12-slot pool), via ChemCore.
func metallicElectronsShown(slotA: ZoneState, slotB: ZoneState) -> Int {
    metallicElectronCount(veA: slotA.valenceElectrons, veB: slotB.valenceElectrons)
}
