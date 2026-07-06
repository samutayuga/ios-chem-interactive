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
                let freed = Product(formula: boundCation.symbol, composition: [boundCation.symbol: 1])
                return .products([newSalt, freed])
            default:
                return .infeasible("\(freeSpecies.symbol) is below \(boundCation.symbol) in the activity series")
            }
        } else {
            switch displaces(freeSpecies.symbol, over: anion.symbol) {
            case .some(true):
                let newSalt = ionicProduct(boundCation, freeSpecies)
                let freed = Product(formula: anion.symbol, composition: [anion.symbol: 1])
                return .products([newSalt, freed])
            default:
                return .infeasible("\(freeSpecies.symbol) is below \(anion.symbol) in the activity series")
            }
        }

    case .combustion:
        let fuel = isDioxygenReactant(r1) ? r2 : r1
        if let c = fuel.composition["C"] { // hydrocarbon path
            var products = [carbonDioxide]
            if fuel.composition["H"] != nil { products.append(water) }
            _ = c
            return .products(products)
        }
        if fuel.composition["H"] != nil {
            return .products([water])
        }
        // Bare-element fuel → oxide E O_n where n = |positive charge|.
        guard let e = fuel.species.first else { return .infeasible("no fuel") }
        let n = max(1, abs(e.charge ?? 2))
        let oxideComp = ["\(e.symbol)": 1, "O": n]
        let oxide = Product(formula: "\(e.symbol)O\(formulaSubscript(n))", composition: oxideComp)
        return .products([oxide])

    case .synthesis:
        let compound = makeReactant([r1.species[0], r2.species[0]])
        return .products([Product(formula: compound.formula, composition: compound.composition)])

    case .none:
        return .infeasible("no recognised reaction")
    }
}

private func isDioxygenReactant(_ r: Reactant) -> Bool {
    r.composition.count == 1 && r.composition["O"] == 2
}
