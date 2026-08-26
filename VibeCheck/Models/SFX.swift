import AVFoundation
import UIKit

/// Little synthesised bleeps, ported from the original web app's Web Audio
/// sounds. Generating tones beats shipping audio files: no assets, no latency,
/// and the score sting can be composed per band.
enum SFX {
    private static let engine = AVAudioEngine()
    private static let player = AVAudioPlayerNode()
    private static var started = false
    private static let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
    }

    private static func ensureRunning() {
        guard !started else { return }
        // .ambient means we never interrupt the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
        player.play()
        started = true
    }

    private struct Tone {
        let freq: Double
        let duration: Double
        let delay: Double
        var gain: Double = 0.22
    }

    /// Renders the tones into one buffer and plays it in a single scheduling pass.
    private static func play(_ tones: [Tone]) {
        guard enabled, !tones.isEmpty else { return }
        ensureRunning()

        let sampleRate = format.sampleRate
        let total = tones.map { $0.delay + $0.duration }.max() ?? 0
        let frames = AVAudioFrameCount(total * sampleRate)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buffer.frameLength = frames
        guard let samples = buffer.floatChannelData?[0] else { return }
        for i in 0..<Int(frames) { samples[i] = 0 }

        for tone in tones {
            let start = Int(tone.delay * sampleRate)
            let count = Int(tone.duration * sampleRate)
            guard count > 0 else { continue }
            for n in 0..<count {
                let idx = start + n
                guard idx < Int(frames) else { break }
                let t = Double(n) / sampleRate
                // Exponential decay, matching the web version's gain ramp.
                let envelope = exp(-5.0 * t / tone.duration)
                samples[idx] += Float(sin(2 * .pi * tone.freq * t) * tone.gain * envelope)
            }
        }
        // Guard against clipping where tones overlap.
        var peak: Float = 0
        for i in 0..<Int(frames) { peak = max(peak, abs(samples[i])) }
        if peak > 1 { for i in 0..<Int(frames) { samples[i] /= peak } }

        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    // MARK: - The sounds

    static func shutter() {
        guard enabled else { return }
        AudioServicesPlaySystemSound(1108)          // the system camera shutter
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    static func tap() {
        play([Tone(freq: 620, duration: 0.05, delay: 0, gain: 0.12)])
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Ticking while the score counts up.
    static func tick() {
        play([Tone(freq: 900, duration: 0.02, delay: 0, gain: 0.05)])
    }

    static func thinking() {
        play([
            Tone(freq: 440, duration: 0.11, delay: 0.00, gain: 0.13),
            Tone(freq: 550, duration: 0.11, delay: 0.13, gain: 0.13),
        ])
    }

    /// The sting when the verdict lands, pitched by how well you did.
    static func score(_ value: Int) {
        let generator = UINotificationFeedbackGenerator()
        switch value {
        case 85...:
            play([
                Tone(freq: 523, duration: 0.13, delay: 0.00),
                Tone(freq: 659, duration: 0.13, delay: 0.11),
                Tone(freq: 784, duration: 0.16, delay: 0.22),
                Tone(freq: 1046, duration: 0.34, delay: 0.34),
            ])
            if enabled { generator.notificationOccurred(.success) }
        case 60..<85:
            play([
                Tone(freq: 440, duration: 0.13, delay: 0.00),
                Tone(freq: 554, duration: 0.13, delay: 0.11),
                Tone(freq: 659, duration: 0.24, delay: 0.22),
            ])
            if enabled { generator.notificationOccurred(.success) }
        case 35..<60:
            play([
                Tone(freq: 392, duration: 0.15, delay: 0.00),
                Tone(freq: 392, duration: 0.22, delay: 0.16),
            ])
            if enabled { generator.notificationOccurred(.warning) }
        default:
            // Sad trombone: three steps down.
            play([
                Tone(freq: 330, duration: 0.17, delay: 0.00),
                Tone(freq: 277, duration: 0.17, delay: 0.16),
                Tone(freq: 220, duration: 0.42, delay: 0.32),
            ])
            if enabled { generator.notificationOccurred(.error) }
        }
    }
}
