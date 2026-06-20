public enum DomainError: Error, Equatable {
    case invalidAtomicNumber(Int)
}

func validate(_ z: Int) throws {
    guard (1...118).contains(z) else { throw DomainError.invalidAtomicNumber(z) }
}
