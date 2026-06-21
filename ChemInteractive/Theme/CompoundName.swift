import ChemCore

private let anionRoots: [String: String] = [
    "F": "Fluoride", "Cl": "Chloride", "Br": "Bromide", "I": "Iodide",
    "O": "Oxide", "S": "Sulfide", "Se": "Selenide", "Te": "Telluride",
    "N": "Nitride", "P": "Phosphide", "As": "Arsenide",
    "C": "Carbide", "H": "Hydride",
]

private let greekPrefixes = ["", "mono", "di", "tri", "tetra", "penta", "hexa", "hepta", "octa", "nona", "deca"]
private let romanNumerals = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII"]

private func roman(_ n: Int) -> String {
    (n >= 1 && n < romanNumerals.count) ? romanNumerals[n] : String(n)
}

private func elementName(_ symbol: String, _ elements: [Element]) -> String {
    elements.first { $0.symbol == symbol }?.name ?? symbol
}

private func anionRoot(_ symbol: String, _ elements: [Element]) -> String {
    anionRoots[symbol] ?? elementName(symbol, elements)
}

/// Greek prefix for a count. `allowMono` adds "mono" for count 1 (second element only).
private func greekPrefix(_ count: Int, allowMono: Bool) -> String {
    if count == 1 { return allowMono ? "mono" : "" }
    return (count >= 0 && count < greekPrefixes.count) ? greekPrefixes[count] : ""
}

/// Join a Greek prefix to a root, eliding the prefix's trailing a/o before a vowel.
private func joinElided(_ prefix: String, _ root: String) -> String {
    guard let first = root.lowercased().first, "aeiou".contains(first),
          let last = prefix.last, last == "a" || last == "o" else {
        return prefix + root
    }
    return String(prefix.dropLast()) + root
}

private func sentenceCased(_ s: String) -> String {
    guard let first = s.first else { return s }
    return first.uppercased() + s.dropFirst()
}

func ionicCompoundName(cation: ZoneState, anion: ZoneState,
                       elements: [Element], ions: [PolyatomicIon]) -> String {
    var cationWord: String
    if cation.isPolyatomic {
        // Polyatomic cation (e.g. NH₄ → Ammonium); fixed charge, no Roman numeral.
        cationWord = ions.first { $0.symbol == cation.symbol }?.name ?? cation.symbol
    } else {
        cationWord = elementName(cation.symbol, elements)
        let variable = cation.isTransition || cation.oxidationStates.count > 1
        if variable, let c = cation.derivedCharge, c > 0 {
            cationWord += "(\(roman(c)))"
        }
    }
    let anionWord: String
    if anion.isPolyatomic {
        anionWord = ions.first { $0.symbol == anion.symbol }?.name ?? anion.symbol
    } else {
        anionWord = anionRoot(anion.symbol, elements)
    }
    return "\(cationWord) \(anionWord.lowercased())"
}

/// Covalent name from explicit counts (order already decided by the caller).
func covalentName(firstSymbol: String, firstCount: Int,
                  secondSymbol: String, secondCount: Int, elements: [Element]) -> String {
    let firstWord = greekPrefix(firstCount, allowMono: false) + elementName(firstSymbol, elements).lowercased()
    let secondWord = joinElided(greekPrefix(secondCount, allowMono: true),
                                anionRoot(secondSymbol, elements).lowercased())
    return sentenceCased("\(firstWord) \(secondWord)")
}

func covalentCompoundName(slotA: ZoneState, slotB: ZoneState, elements: [Element]) -> String {
    if slotA.symbol == slotB.symbol { return elementName(slotA.symbol, elements) }
    let s = calcStoich(veA: slotA.valenceElectrons, veB: slotB.valenceElectrons)
    let aFirst = iupacFirst(slotA.symbol, slotB.symbol)
    return covalentName(firstSymbol: aFirst ? slotA.symbol : slotB.symbol,
                        firstCount: aFirst ? s.nA : s.nB,
                        secondSymbol: aFirst ? slotB.symbol : slotA.symbol,
                        secondCount: aFirst ? s.nB : s.nA,
                        elements: elements)
}
