import AVFoundation

/// VOIDSTACK — fully procedural audio engine built on a single AVAudioSourceNode.
/// Every sound (SFX + generative ambient pad/arpeggio) is synthesized in real time;
/// no external audio files are bundled or used.
final class AudioEngine {
    private enum Wave { case sine, square, triangle, sawtooth, noise }

    private struct Voice {
        let id = UUID()
        let wave: Wave
        let freq: Double
        var glideToFreq: Double?
        var phase: Double = 0
        var secondsElapsed: Double = 0
        let attack: Double
        let decay: Double
        let sustainLevel: Double
        let release: Double
        let peak: Float
        var filterCutoffHz: Double?
        var filterState: Float = 0

        var totalDuration: Double { attack + decay + release }

        var isFinished: Bool { secondsElapsed > totalDuration + 0.02 }

        mutating func render(sampleRate: Double) -> Float {
            let dt = 1.0 / sampleRate
            let t = secondsElapsed
            secondsElapsed += dt

            var freqNow = freq
            if let target = glideToFreq {
                let progress = min(1, t / max(totalDuration, 0.0001))
                freqNow = freq + (target - freq) * progress
            }
            phase += freqNow * dt
            if phase >= 1 { phase -= phase.rounded(.down) }

            var raw: Float
            switch wave {
            case .sine: raw = Float(sin(2 * Double.pi * phase))
            case .square: raw = phase < 0.5 ? 1 : -1
            case .triangle: raw = Float(4 * abs(phase - 0.5) - 1)
            case .sawtooth: raw = Float(2 * phase - 1)
            case .noise: raw = Float.random(in: -1...1)
            }

            if let cutoff = filterCutoffHz {
                let alpha = Float(1 - exp(-2 * Double.pi * cutoff / sampleRate))
                filterState += (raw - filterState) * alpha
                raw = filterState
            }

            return raw * envelope(at: t)
        }

        private func envelope(at t: Double) -> Float {
            if t < attack {
                return peak * Float(t / max(attack, 0.0001))
            }
            if t < attack + decay {
                let p = (t - attack) / max(decay, 0.0001)
                return peak * Float(1 - p * (1 - sustainLevel))
            }
            let sustainValue = peak * Float(sustainLevel)
            let p = (t - attack - decay) / max(release, 0.0001)
            if p >= 1 { return 0 }
            return sustainValue * Float(1 - p)
        }
    }

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44100
    private var voices: [Voice] = []
    private let lock = NSLock()
    private var masterGain: Float = 0.8

    private var padTimer: Timer?
    private var arpTimer: Timer?
    private var arpStep = 0
    private var started = false

    private static let scale = [0, 3, 5, 7, 10, 12, 15, 19]
    private static let root = 45.0

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            self.lock.lock()
            var localVoices = self.voices
            self.lock.unlock()

            for frame in 0..<Int(frameCount) {
                var sample: Float = 0
                for i in localVoices.indices {
                    sample += localVoices[i].render(sampleRate: self.sampleRate)
                }
                sample = max(-1, min(1, sample * self.masterGain))
                for buffer in ablPointer {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }

            let finishedIds = Set(localVoices.filter(\.isFinished).map(\.id))
            self.lock.lock()
            for updated in localVoices where !updated.isFinished {
                if let idx = self.voices.firstIndex(where: { $0.id == updated.id }) {
                    self.voices[idx] = updated
                }
            }
            self.voices.removeAll { finishedIds.contains($0.id) }
            self.lock.unlock()

            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1
    }

    func resume() {
        guard !started else { return }
        started = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        try? engine.start()
    }

    func setMuted(_ muted: Bool) {
        masterGain = muted ? 0 : 0.8
    }

    private func addVoice(_ v: Voice) {
        lock.lock()
        voices.append(v)
        lock.unlock()
    }

    private func semitoneToFreq(_ semi: Double, base: Double = 110) -> Double {
        base * pow(2, semi / 12)
    }

    private func tone(freq: Double, wave: Wave, dur: Double, peak: Float, glideTo: Double? = nil, filter: Double? = nil, delay: Double = 0) {
        let voice = Voice(
            wave: wave, freq: freq, glideToFreq: glideTo,
            attack: 0.006, decay: dur * 0.35, sustainLevel: 0.5, release: dur * 0.6,
            peak: peak, filterCutoffHz: filter
        )
        if delay <= 0 {
            addVoice(voice)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.addVoice(voice) }
        }
    }

    // MARK: - SFX

    func playSelect() {
        tone(freq: 720, wave: .triangle, dur: 0.06, peak: 0.18)
    }

    /// Loud impact "thud" for each roll step of a tumbling stack.
    func playRoll() {
        let base = 90.0 + Double.random(in: 0...30)
        tone(freq: base, wave: .square, dur: 0.16, peak: 0.55, glideTo: base * 0.5, filter: 700)
        addVoice(Voice(wave: .noise, freq: 0, attack: 0.001, decay: 0.03, sustainLevel: 0.15, release: 0.09, peak: 0.5, filterCutoffHz: 1800))
    }

    func playClearMarked(combo: Int) {
        let base = 440.0 + Double(min(combo, 8)) * 60
        for (i, interval) in [0.0, 4, 7, 12].enumerated() {
            tone(freq: semitoneToFreq(interval, base: base), wave: .square, dur: 0.22, peak: 0.22, filter: 3200, delay: Double(i) * 0.03)
        }
    }

    func playPushFail() {
        addVoice(Voice(wave: .noise, freq: 0, attack: 0.002, decay: 0.05, sustainLevel: 0.3, release: 0.28, peak: 0.4, filterCutoffHz: 900))
        tone(freq: 140, wave: .sawtooth, dur: 0.32, peak: 0.3, glideTo: 60)
    }

    func playEscapeAlarm() {
        for i in 0..<2 {
            tone(freq: 660, wave: .square, dur: 0.12, peak: 0.3, glideTo: 420, delay: Double(i) * 0.16)
        }
    }

    func playLevelUp() {
        for (i, interval) in [0.0, 4, 7, 12, 16].enumerated() {
            tone(freq: semitoneToFreq(interval, base: 330), wave: .triangle, dur: 0.3, peak: 0.25, delay: Double(i) * 0.05)
        }
    }

    func playGameOver() {
        for (i, interval) in [0.0, -3, -7, -12].enumerated() {
            tone(freq: semitoneToFreq(interval, base: 220), wave: .sawtooth, dur: 0.9, peak: 0.28, filter: 1200, delay: Double(i) * 0.22)
        }
    }

    // MARK: - Generative ambient pad + arpeggio

    func startAmbient() {
        stopAmbient()
        schedulePad()
        padTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in self?.schedulePad() }
        arpStep = 0
        arpTimer = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { [weak self] _ in self?.scheduleArpStep() }
    }

    func stopAmbient() {
        padTimer?.invalidate(); padTimer = nil
        arpTimer?.invalidate(); arpTimer = nil
    }

    private func schedulePad() {
        let base = semitoneToFreq(0, base: 55)
        for detune in [0.0, 0.004] {
            addVoice(Voice(
                wave: .sawtooth, freq: base * (1 + detune),
                attack: 1.2, decay: 0.6, sustainLevel: 0.55, release: 2.2,
                peak: 0.14, filterCutoffHz: 480
            ))
        }
    }

    private func scheduleArpStep() {
        let degree = Double(Self.scale[(arpStep * 3) % Self.scale.count])
        let octave = arpStep % 8 < 4 ? 0.0 : 12.0
        let freq = semitoneToFreq(degree + octave, base: semitoneToFreq(0, base: Self.root))
        tone(freq: freq, wave: .triangle, dur: 0.2, peak: arpStep % 4 == 0 ? 0.22 : 0.13, filter: 2200)
        arpStep += 1
    }
}
