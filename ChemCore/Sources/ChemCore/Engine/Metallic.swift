/// Delocalised electron count for the electron-sea model, capped at the pool size.
public func metallicElectronCount(veA: Int, veB: Int, poolSize: Int = 12) -> Int {
    min(3 * veA + 3 * veB, poolSize)
}
