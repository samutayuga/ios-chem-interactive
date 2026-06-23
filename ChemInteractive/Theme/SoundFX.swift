// ChemInteractive/Theme/SoundFX.swift
import AudioToolbox

/// Tiny UI sound effects using built-in iOS system sounds — no bundled audio
/// assets. Used when tapping a reactant or product term in the stoichiometry
/// equation.
enum SoundFX {
    /// Reactant tap — a soft "tock".
    static func reactant() { AudioServicesPlaySystemSound(1104) }
    /// Product tap — a brighter "tink".
    static func product() { AudioServicesPlaySystemSound(1057) }
}
