import Foundation

public struct Product: Equatable, Sendable {
    public let formula: String
    public let composition: [String: Int]
    public init(formula: String, composition: [String: Int]) {
        self.formula = formula; self.composition = composition
    }
}

public enum Prediction: Equatable, Sendable {
    case products([Product])
    case infeasible(String)
}

private let water = Product(formula: "H₂O", composition: ["H": 2, "O": 1])
private let carbonDioxide = Product(formula: "CO₂", composition: ["C": 1, "O": 2])

/// A freed element from a displacement, as its stable molecular form
/// (diatomic for H, N, O, F, Cl, Br, I).
private func freedElement(_ symbol: String) -> Product {
    if naturallyDiatomic.contains(symbol) {
        return Product(formula: "\(symbol)\(formulaSubscript(2))", composition: [symbol: 2])
    }
    return Product(formula: symbol, composition: [symbol: 1])
}

/// Neutralise a cation with an anion into a single ionic Product.
private func ionicProduct(_ cation: Species, _ anion: Species) -> Product {
    let sub = crossoverSubscripts(cationCharge: cation.charge ?? 1,
                                  anionCharge: anion.charge ?? -1)
    let comp = cation.composition.mapValues { $0 * sub.cationSub }
        .merging(anion.composition.mapValues { $0 * sub.anionSub }) { $0 + $1 }
    let formula = binaryFormula(first: cation.symbol, firstCount: sub.cationSub,
                                second: anion.symbol, secondCount: sub.anionSub,
                                secondIsPolyatomic: anion.isPolyatomic)
    return Product(formula: formula, composition: comp)
}

public func predictProducts(_ cls: ReactionClass, _ r1: Reactant, _ r2: Reactant) -> Prediction {
    switch cls {
    case .doubleDisplacement:
        guard let c1 = r1.cation, let a1 = r1.anion,
              let c2 = r2.cation, let a2 = r2.anion else {
            return .infeasible("both reactants must be ionic")
        }
        var products: [Product] = []
        for (cat, an) in [(c1, a2), (c2, a1)] {
            if cat.symbol == "H" && an.symbol == "OH" {
                products.append(water)
            } else if cat.symbol == "H" && an.symbol == "CO₃" {
                products.append(carbonDioxide)
                products.append(water)
            } else {
                products.append(ionicProduct(cat, an))
            }
        }
        return .products(products)

    case .singleDisplacement:
        let (free, salt) = r1.isBareElement ? (r1, r2) : (r2, r1)
        guard let boundCation = salt.cation, let anion = salt.anion,
              let freeSpecies = free.species.first else {
            return .infeasible("salt reactant must be ionic")
        }
        // Metal free element displaces the salt's cation; halogen displaces the anion.
        if freeSpecies.elementClass == .metal {
            switch displaces(freeSpecies.symbol, over: boundCation.symbol) {
            case .some(true):
                let newSalt = ionicProduct(freeSpecies, anion)
                let freed = freedElement(boundCation.symbol)
                return .products([newSalt, freed])
            default:
                return .infeasible("\(freeSpecies.symbol) is below \(boundCation.symbol) in the activity series")
            }
        } else {
            switch displaces(freeSpecies.symbol, over: anion.symbol) {
            case .some(true):
                let newSalt = ionicProduct(boundCation, freeSpecies)
                let freed = freedElement(anion.symbol)
                return .products([newSalt, freed])
            default:
                return .infeasible("\(freeSpecies.symbol) is below \(anion.symbol) in the activity series")
            }
        }

    case .combustion:
        let fuel = isDioxygen(r1) ? r2 : r1
        if fuel.composition["C"] != nil { // hydrocarbon path
            var products = [carbonDioxide]
            if fuel.composition["H"] != nil { products.append(water) }
            return .products(products)
        }
        if fuel.composition["H"] != nil {
            return .products([water])
        }
        // Bare-element fuel → oxide via crossover against oxygen (charge -2).
        guard let e = fuel.species.first else { return .infeasible("no fuel") }
        // Requires e.charge to encode the fuel element's oxidation magnitude;
        // when charge is nil this falls back to 2, which is only correct for +2 elements.
        let sub = crossoverSubscripts(cationCharge: abs(e.charge ?? 2), anionCharge: -2)
        let oxideComp = [e.symbol: sub.cationSub, "O": sub.anionSub]
        let oxide = Product(
            formula: binaryFormula(first: e.symbol, firstCount: sub.cationSub,
                                   second: "O", secondCount: sub.anionSub, secondIsPolyatomic: false),
            composition: oxideComp)
        return .products([oxide])

    case .synthesis:
        let compound = makeReactant([r1.species[0], r2.species[0]])
        return .products([Product(formula: compound.formula, composition: compound.composition)])

    case .none:
        return .infeasible("no recognised reaction")
    }
}
