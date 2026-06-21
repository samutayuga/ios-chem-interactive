import ChemCore

/// Traditional group name (with IUPAC number) for an element, or the f-block
/// series name, formatted "Group N/Name". Hydrogen is "Group 1" only
/// (it is not an alkali metal); f-block has no group number.
func periodicGroupName(for el: Element) -> String {
    let z = el.atomicNumber
    if (57...71).contains(z) { return "Lanthanides" }
    if (89...103).contains(z) { return "Actinides" }

    let g = el.group
    let traditional: String?
    switch g {
    case 1:  traditional = z == 1 ? nil : "Alkali metals"
    case 2:  traditional = "Alkaline earth metals"
    case 3...12: traditional = "Transition metals"
    case 13: traditional = "Boron group"
    case 14: traditional = "Carbon group"
    case 15: traditional = "Pnictogens"
    case 16: traditional = "Chalcogens"
    case 17: traditional = "Halogens"
    case 18: traditional = "Noble gases"
    default: traditional = nil
    }
    if let traditional { return "Group \(g)/\(traditional)" }
    return "Group \(g)"
}
