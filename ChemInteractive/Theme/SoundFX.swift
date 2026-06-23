// ChemInteractive/Theme/SoundFX.swift
import AudioToolbox
import UIKit

/// Tiny UI sound/haptic effects using built-in iOS system sounds — no bundled
/// audio assets.
enum SoundFX {
    /// Fires when both reactants have an amount — the reaction "happens".
    static func reaction() {
        AudioServicesPlaySystemSound(1025)   // tri-tone completion cue
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
