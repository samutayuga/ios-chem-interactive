import Foundation
import ChemCore

private let superscriptMap: [Int: String] = [
    1: "¹", 2: "²", 3: "³", 4: "⁴", 5: "⁵", 6: "⁶", 7: "⁷",
]

/// Superscript glyph for 1...7, else the decimal string.
func superscript(_ n: Int) -> String {
    superscriptMap[n] ?? String(n)
}

private let subscriptDigits: [Character: Character] = [
    "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
    "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
]

/// Unicode subscript rendering of a non-negative integer.
func subscriptGlyphs(_ n: Int) -> String {
    String(String(n).map { subscriptDigits[$0] ?? $0 })
}

private let superscriptDigits: [Character: Character] = [
    "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
    "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
]

/// Render the electron counts in an electron-configuration string as
/// superscripts, leaving principal quantum numbers and subshell letters as-is.
/// e.g. "1s2 2s2 2p6 3d10" -> "1s² 2s² 2p⁶ 3d¹⁰".
func superscriptElectronCounts(_ config: String) -> String {
    var out = ""
    var afterSubshell = false   // true once we've passed the s/p/d/f letter
    for ch in config {
        switch ch {
        case "s", "p", "d", "f":
            afterSubshell = true
            out.append(ch)
        case "0"..."9" where afterSubshell:
            out.append(superscriptDigits[ch] ?? ch)
        case " ":
            afterSubshell = false
            out.append(ch)
        default:
            out.append(ch)   // principal quantum number digit, etc.
        }
    }
    return out
}

/// Ion label, e.g. "Na⁺", "Mg²⁺", "Cl⁻", "O²⁻".
func formatIon(symbol: String, charge: Int) -> String {
    let abs = Swift.abs(charge)
    let sign = charge > 0 ? "⁺" : "⁻"
    let sup = abs == 1 ? sign : "\(superscript(abs))\(sign)"
    return "\(symbol)\(sup)"
}

/// Electrons a nonmetal needs to complete its octet (duet for H).
func electronsNeeded(_ valenceElectrons: Int) -> Int {
    valenceElectrons == 1 ? 1 : 8 - valenceElectrons
}

/// gcd-reduced ionic formula. Charges are passed as signed values; magnitudes drive subscripts.
func ionicFormula(cationSymbol: String, cationCharge: Int,
                  anionSymbol: String, anionCharge: Int,
                  anionIsPolyatomic: Bool) -> String {
    let cC = Swift.abs(cationCharge)
    let aC = Swift.abs(anionCharge)
    let g = gcd(cC, aC)
    let cSub = aC / g   // cross over: anion charge → cation subscript
    let aSub = cC / g
    let cationPart = cSub == 1 ? cationSymbol : "\(cationSymbol)\(subscriptGlyphs(cSub))"
    let anionPart: String
    if anionIsPolyatomic && aSub > 1 {
        anionPart = "(\(anionSymbol))\(subscriptGlyphs(aSub))"
    } else {
        anionPart = aSub == 1 ? anionSymbol : "\(anionSymbol)\(subscriptGlyphs(aSub))"
    }
    return "\(cationPart)\(anionPart)"
}

/// Per-ion charge-derivation copy shown in the explanation modal.
func chargeExplanation(_ zone: ZoneState) -> String {
    if zone.isPolyatomic {
        let c = zone.derivedCharge ?? 0
        return "\(zone.symbol) is a polyatomic ion with a fixed charge of \(c > 0 ? "+" : "")\(c)"
    }
    let ve = zone.valenceElectrons
    let plural = ve != 1 ? "s" : ""
    if zone.elementClass == .metal || zone.elementClass == .metalloid {
        let c = Swift.abs(zone.derivedCharge ?? 0)
        return "\(zone.symbol) has \(ve) valence electron\(plural) → loses \(c)e⁻ → \(formatIon(symbol: zone.symbol, charge: c))"
    }
    let c = Swift.abs(zone.derivedCharge ?? 0)
    return "\(zone.symbol) has \(ve) valence electron\(plural) → gains \(c)e⁻ → \(formatIon(symbol: zone.symbol, charge: -c))"
}
