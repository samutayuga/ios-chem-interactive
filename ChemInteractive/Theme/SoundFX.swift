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

/// Synthesises and plays a short "burning / fire" reaction sound: a low noise
/// roar + airy hiss + random crackle pops, shaped by a fast‑attack / slow‑decay
/// envelope.
final class ReactionSound {
    static let shared = ReactionSound()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private let buffer: AVAudioPCMBuffer

    private init() {
        buffer = ReactionSound.makeFire(format: format)
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

    /// One‑shot ~1s fire buffer: low rumble (roar) + hiss + crackle pops.
    private static func makeFire(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = 44_100.0
        let duration = 1.0
        let frames = AVAudioFrameCount(sampleRate * duration)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        let samples = buf.floatChannelData![0]

        var roar: Float = 0      // low‑passed noise → fire roar
        var hiss: Float = 0      // lightly filtered noise → airy hiss
        var crackle: Float = 0   // decaying envelope for random pops
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            // Fast attack (~10ms), slow decay → a burst that settles and fades.
            let env = Float((1 - exp(-t * 120.0)) * exp(-t * 2.3))
            let white = Float.random(in: -1...1)
            roar += 0.03 * (white - roar)          // deep rumble
            hiss += 0.45 * (white - hiss)          // bright hiss
            // Occasionally retrigger a sharp, fast‑decaying crackle (wood snap).
            if Float.random(in: 0...1) < 0.0009 { crackle = Float.random(in: 0.6...1.0) }
            crackle *= 0.86
            let pop = Float.random(in: -1...1) * crackle
            samples[i] = (roar * 0.7 + hiss * 0.25 + pop * 0.55) * env * 0.7
        }
        return buf
    }
}
