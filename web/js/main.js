// VOIDSTACK — entry point: wires game logic, renderer, audio, input and UI together.
import { VoidStackGame } from './game.js';
import { VoidStackRenderer } from './renderer.js';
import { AudioEngine } from './audio.js';
import { InputController } from './input.js';
import { UI } from './ui.js';

const canvas = document.getElementById('scene');
const game = new VoidStackGame();
const renderer = new VoidStackRenderer(canvas);
const audio = new AudioEngine();
const ui = new UI();

let state = 'menu'; // menu | howto | playing | paused | gameover

function setState(next) {
  state = next;
  const screenMap = { menu: 'start', howto: 'howto', paused: 'pause', gameover: 'gameover', playing: null };
  ui.show(screenMap[next]);
  ui.showHudChrome(next === 'playing' || next === 'paused');
  input.setEnabled(next === 'playing');
}

// --- game event wiring ---
game.on('select', (col) => renderer.setSelected(col));
game.on('score', (v) => ui.setScore(v));
game.on('combo', (v) => ui.setCombo(v));
game.on('levelUp', (v) => {
  ui.setLevel(v);
  audio.playLevelUp();
});
game.on('clearedMarked', ({ stack, combo }) => {
  renderer.burst(stack.col, stack.row, true);
  audio.playClearMarked(combo);
});
game.on('pushedSafe', () => {
  audio.playPushFail();
  renderer.shake(0.28, 0.3);
});
game.on('lifeLost', ({ reason, stack }) => {
  ui.renderLives(game.lives);
  if (reason === 'escaped') {
    renderer.burst(stack.col, 0, true);
    audio.playEscapeAlarm();
    renderer.shake(0.45, 0.4);
  } else {
    renderer.shake(0.45, 0.4);
  }
});
game.on('pushEmpty', () => audio.playSelect());
game.on('gameOver', ({ score }) => {
  audio.playGameOver();
  audio.stopAmbient();
  ui.setFinalScore(score);
  setState('gameover');
});
game.on('reset', () => {
  ui.setScore(0);
  ui.setCombo(0);
  ui.setLevel(1);
  ui.renderLives(game.lives);
  ui.setWarning(false);
});

// --- input wiring ---
const input = new InputController({
  canvas,
  onLeft: () => {
    game.selectDelta(-1);
    audio.playSelect();
  },
  onRight: () => {
    game.selectDelta(1);
    audio.playSelect();
  },
  onPush: () => game.push(),
  onPause: () => {
    if (state === 'playing') pauseGame();
  },
});
input.bindAbsoluteSelect((col) => {
  game.selectCol(col);
  audio.playSelect();
});
input.setEnabled(false);

// --- flow control ---
function startGame() {
  audio.resume();
  audio.startAmbient();
  game.reset();
  game.start();
  setState('playing');
}

function pauseGame() {
  game.running = false;
  setState('paused');
}

function resumeGame() {
  game.running = true;
  setState('playing');
}

document.getElementById('btn-start').addEventListener('click', startGame);
document.getElementById('btn-retry').addEventListener('click', startGame);
document.getElementById('btn-howto').addEventListener('click', () => setState('howto'));
document.getElementById('btn-back').addEventListener('click', () => setState('menu'));
document.getElementById('btn-resume').addEventListener('click', resumeGame);
document.getElementById('btn-quit').addEventListener('click', () => {
  audio.stopAmbient();
  setState('menu');
});
document.getElementById('btn-menu').addEventListener('click', () => setState('menu'));

document.addEventListener('visibilitychange', () => {
  if (document.hidden && state === 'playing') pauseGame();
});

// --- main loop ---
let lastT = performance.now();
function frame(now) {
  const dt = Math.min(0.05, (now - lastT) / 1000);
  lastT = now;

  if (state === 'playing') {
    game.update(dt * 1000);
    ui.setWarning(game.dangerCols.length > 0);
    renderer.setWarningCols(game.dangerCols);
    renderer.syncStacks(game.snapshot().stacks);
  }
  renderer.update(dt);
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

setState('menu');

// --- PWA service worker (skip on localhost so dev edits are never served stale) ---
const isLocalDev = ['localhost', '127.0.0.1'].includes(location.hostname);
if ('serviceWorker' in navigator && !isLocalDev) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {});
  });
}
