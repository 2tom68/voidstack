// VOIDSTACK — DOM/HUD glue.
import { START_LIVES } from './game.js';

export class UI {
  constructor() {
    this.el = {
      score: document.getElementById('score'),
      level: document.getElementById('level'),
      combo: document.getElementById('combo'),
      lives: document.getElementById('lives'),
      warning: document.getElementById('warning'),
      start: document.getElementById('start-screen'),
      howto: document.getElementById('howto-screen'),
      pause: document.getElementById('pause-screen'),
      gameover: document.getElementById('gameover-screen'),
      finalScore: document.getElementById('final-score'),
      btnPause: document.getElementById('btn-pause'),
      touchControls: document.getElementById('touch-controls'),
    };
    this.renderLives(START_LIVES);
  }

  renderLives(lives) {
    this.el.lives.innerHTML = '';
    for (let i = 0; i < START_LIVES; i++) {
      const d = document.createElement('div');
      d.className = 'heart' + (i >= lives ? ' lost' : '');
      this.el.lives.appendChild(d);
    }
  }

  setScore(v) {
    this.el.score.textContent = v.toLocaleString('de-DE');
  }
  setLevel(v) {
    this.el.level.textContent = v;
  }
  setCombo(v) {
    this.el.combo.textContent = `×${v}`;
  }
  setWarning(active) {
    this.el.warning.classList.toggle('hidden', !active);
  }

  show(name) {
    ['start', 'howto', 'pause', 'gameover'].forEach((k) => this.el[k].classList.add('hidden'));
    if (name) this.el[name].classList.remove('hidden');
  }

  showHudChrome(visible) {
    this.el.btnPause.classList.toggle('hidden', !visible);
    if ('ontouchstart' in window) this.el.touchControls.classList.toggle('hidden', !visible);
  }

  setFinalScore(v) {
    this.el.finalScore.textContent = v.toLocaleString('de-DE');
  }
}
