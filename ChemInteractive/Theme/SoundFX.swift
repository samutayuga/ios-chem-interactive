// ChemInteractive/Theme/SoundFX.swift
import AVFoundation
import UIKit

/// UI sound/haptic effects. The reaction sound is synthesised at runtime (a
/// noise "fizz" with a fast attack and exponential decay) — no bundled assets.
enum SoundFX {
    /// Fires when both reactants have an amount — the reaction "happens".
    static func reaction() {
        ReactionSound.shared.play()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Synthesises and plays a "match strike" reaction sound: a short scratchy
/// strike, then an igniting flare (low roar swell + decay) with crackle pops.
final class ReactionSound {
    static let shared = ReactionSound()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private let buffer: AVAudioPCMBuffer

    private init() {
        buffer = ReactionSound.makeMatchStrike(format: format)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func play() {
        do {
            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
            player.play()
        } catch {
            // Audio is non‑critical; ignore failures (e.g. interrupted session).
        }
    }

    /// One‑shot ~0.6s buffer: a scratchy strike (~55ms) then an igniting flare.
    private static func makeMatchStrike(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = 44_100.0
        let duration = 0.6
        let frames = AVAudioFrameCount(sampleRate * duration)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        let samples = buf.floatChannelData![0]

        let strikeEnd = 0.055
        var roar: Float = 0
        var prevWhite: Float = 0
        var crackle: Float = 0
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let white = Float.random(in: -1...1)
            var s: Float

            if t < strikeEnd {
                // Scratch: high-passed noise (derivative emphasises highs) gated
                // by a buzz, under a short gaussian blip ≈ the friction strike.
                let highs = 0.5 * (white - prevWhite)
                let buzz: Float = sin(2 * .pi * 950 * t) > 0 ? 1.0 : 0.35
                let blip = Float(exp(-pow((t - 0.022) / 0.014, 2)))
                s = highs * buzz * blip * 1.4
            } else {
                // Flare: noise swell (attack) then decay, low-passed to a roar,
                // with occasional sharp crackle pops.
                let ft = t - strikeEnd
                let flare = Float((1 - exp(-ft * 26.0)) * exp(-ft * 4.5))
                roar += 0.12 * (white - roar)
                if Float.random(in: 0...1) < 0.0011 { crackle = Float.random(in: 0.4...0.9) }
                crackle *= 0.85
                let pop = Float.random(in: -1...1) * crackle
                s = (roar * 0.75 + white * 0.15 + pop * 0.45) * flare
            }
            prevWhite = white
            samples[i] = s * 0.7
        }
        return buf
    }
}
