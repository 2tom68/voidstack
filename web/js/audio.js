// VOIDSTACK — fully procedural Web Audio engine. No external audio files are used;
// every sound effect and the ambient score are synthesized at runtime.

const SCALE = [0, 3, 5, 7, 10, 12, 15, 19]; // minor pentatonic-ish, root-relative semitones
const ROOT = 45; // A2 in MIDI-ish semitone space (relative, not tied to standard tuning)

function semitoneToFreq(semi, base = 110) {
  return base * Math.pow(2, semi / 12);
}

export class AudioEngine {
  constructor() {
    this.ctx = null;
    this.master = null;
    this.muted = false;
    this._noiseBuffer = null;
    this._ambientRunning = false;
    this._nextNoteTime = 0;
    this._schedulerId = null;
    this._step = 0;
  }

  ensureContext() {
    if (this.ctx) return;
    const Ctx = window.AudioContext || window.webkitAudioContext;
    this.ctx = new Ctx();
    this.master = this.ctx.createGain();
    this.master.gain.value = 0.85;
    const compressor = this.ctx.createDynamicsCompressor();
    this.master.connect(compressor);
    compressor.connect(this.ctx.destination);
    this.busOut = compressor;

    this.sfxGain = this.ctx.createGain();
    this.sfxGain.gain.value = 1.0;
    this.sfxGain.connect(this.master);

    this.musicGain = this.ctx.createGain();
    this.musicGain.gain.value = 0.32;
    this.musicGain.connect(this.master);

    this._noiseBuffer = this._makeNoiseBuffer();
  }

  async resume() {
    this.ensureContext();
    if (this.ctx.state === 'suspended') await this.ctx.resume();
  }

  setMuted(m) {
    this.muted = m;
    if (this.master) this.master.gain.setTargetAtTime(m ? 0 : 0.85, this.ctx.currentTime, 0.05);
  }

  _makeNoiseBuffer() {
    const buffer = this.ctx.createBuffer(1, this.ctx.sampleRate * 0.6, this.ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
    return buffer;
  }

  _env(gainNode, t0, attack, decay, sustain, release, peak = 1) {
    const g = gainNode.gain;
    g.cancelScheduledValues(t0);
    g.setValueAtTime(0, t0);
    g.linearRampToValueAtTime(peak, t0 + attack);
    g.linearRampToValueAtTime(peak * sustain, t0 + attack + decay);
    g.linearRampToValueAtTime(0, t0 + attack + decay + release);
  }

  _tone({ freq, type = 'sine', t0, dur, dest, gain = 0.5, glideTo = null, filterFreq = null }) {
    const osc = this.ctx.createOscillator();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t0);
    if (glideTo) osc.frequency.exponentialRampToValueAtTime(glideTo, t0 + dur);
    const g = this.ctx.createGain();
    let node = osc;
    if (filterFreq) {
      const f = this.ctx.createBiquadFilter();
      f.type = 'lowpass';
      f.frequency.value = filterFreq;
      osc.connect(f);
      node = f;
    }
    node.connect(g);
    g.connect(dest);
    this._env(g, t0, 0.006, dur * 0.35, 0.5, dur * 0.6, gain);
    osc.start(t0);
    osc.stop(t0 + dur + 0.05);
    return { osc, gain: g };
  }

  playSelect() {
    if (!this.ctx) return;
    const t0 = this.ctx.currentTime;
    this._tone({ freq: 720, type: 'triangle', t0, dur: 0.06, dest: this.sfxGain, gain: 0.18 });
  }

  playClearMarked(combo = 0) {
    if (!this.ctx) return;
    const t0 = this.ctx.currentTime;
    const base = 440 + Math.min(combo, 8) * 60;
    [0, 4, 7, 12].forEach((interval, i) => {
      this._tone({
        freq: semitoneToFreq(interval, base),
        type: 'square',
        t0: t0 + i * 0.03,
        dur: 0.22,
        dest: this.sfxGain,
        gain: 0.22,
        filterFreq: 3200,
      });
    });
  }

  playPushFail() {
    if (!this.ctx) return;
    const t0 = this.ctx.currentTime;
    const src = this.ctx.createBufferSource();
    src.buffer = this._noiseBuffer;
    const filter = this.ctx.createBiquadFilter();
    filter.type = 'bandpass';
    filter.frequency.value = 320;
    filter.Q.value = 0.8;
    const g = this.ctx.createGain();
    src.connect(filter);
    filter.connect(g);
    g.connect(this.sfxGain);
    this._env(g, t0, 0.002, 0.05, 0.3, 0.28, 0.55);
    src.start(t0);
    src.stop(t0 + 0.4);
    this._tone({ freq: 140, type: 'sawtooth', t0, dur: 0.32, dest: this.sfxGain, gain: 0.3, glideTo: 60 });
  }

  playEscapeAlarm() {
    if (!this.ctx) return;
    const t0 = this.ctx.currentTime;
    for (let i = 0; i < 2; i++) {
      this._tone({ freq: 660, type: 'square', t0: t0 + i * 0.16, dur: 0.12, dest: this.sfxGain, gain: 0.3, glideTo: 420 });
    }
  }

  playLevelUp() {
    if (!this.ctx) return;
    const t0 = this.ctx.currentTime;
    [0, 4, 7, 12, 16].forEach((interval, i) => {
      this._tone({ freq: semitoneToFreq(interval, 330), type: 'triangle', t0: t0 + i * 0.05, dur: 0.3, dest: this.sfxGain, gain: 0.25 });
    });
  }

  playGameOver() {
    if (!this.ctx) return;
    const t0 = this.ctx.currentTime;
    [0, -3, -7, -12].forEach((interval, i) => {
      this._tone({ freq: semitoneToFreq(interval, 220), type: 'sawtooth', t0: t0 + i * 0.22, dur: 0.9, dest: this.sfxGain, gain: 0.28, filterFreq: 1200 });
    });
  }

  // --- generative ambient synthwave pad + arpeggio ---

  startAmbient() {
    if (!this.ctx || this._ambientRunning) return;
    this._ambientRunning = true;
    this._step = 0;
    this._nextNoteTime = this.ctx.currentTime + 0.1;

    const padOsc1 = this.ctx.createOscillator();
    const padOsc2 = this.ctx.createOscillator();
    padOsc1.type = 'sawtooth';
    padOsc2.type = 'sawtooth';
    padOsc1.frequency.value = semitoneToFreq(0, 55);
    padOsc2.frequency.value = semitoneToFreq(0, 55) * 1.004;
    const padFilter = this.ctx.createBiquadFilter();
    padFilter.type = 'lowpass';
    padFilter.frequency.value = 500;
    const padGain = this.ctx.createGain();
    padGain.gain.value = 0.22;
    padOsc1.connect(padFilter);
    padOsc2.connect(padFilter);
    padFilter.connect(padGain);
    padGain.connect(this.musicGain);
    padOsc1.start();
    padOsc2.start();
    this._pad = { padOsc1, padOsc2, padFilter, padGain };

    const lfo = this.ctx.createOscillator();
    lfo.frequency.value = 0.06;
    const lfoGain = this.ctx.createGain();
    lfoGain.gain.value = 260;
    lfo.connect(lfoGain);
    lfoGain.connect(padFilter.frequency);
    lfo.start();
    this._lfo = lfo;

    this._scheduler();
  }

  stopAmbient() {
    if (!this._ambientRunning) return;
    this._ambientRunning = false;
    clearTimeout(this._schedulerId);
    const t = this.ctx.currentTime;
    if (this._pad) {
      this._pad.padGain.gain.setTargetAtTime(0, t, 0.3);
      this._pad.padOsc1.stop(t + 1.2);
      this._pad.padOsc2.stop(t + 1.2);
    }
    if (this._lfo) this._lfo.stop(t + 1.2);
  }

  _scheduler() {
    if (!this._ambientRunning) return;
    while (this._nextNoteTime < this.ctx.currentTime + 0.15) {
      this._scheduleArpNote(this._step, this._nextNoteTime);
      this._nextNoteTime += 0.22;
      this._step = (this._step + 1) % 16;
    }
    this._schedulerId = setTimeout(() => this._scheduler(), 60);
  }

  _scheduleArpNote(step, t0) {
    const patternDegree = SCALE[(step * 3) % SCALE.length];
    const octave = step % 8 < 4 ? 0 : 12;
    const freq = semitoneToFreq(patternDegree + octave, semitoneToFreq(0, ROOT));
    const osc = this.ctx.createOscillator();
    osc.type = 'triangle';
    osc.frequency.value = freq;
    const filter = this.ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.value = 2200;
    const g = this.ctx.createGain();
    osc.connect(filter);
    filter.connect(g);
    g.connect(this.musicGain);
    this._env(g, t0, 0.01, 0.05, 0.2, 0.14, step % 4 === 0 ? 0.28 : 0.16);
    osc.start(t0);
    osc.stop(t0 + 0.24);
  }
}
