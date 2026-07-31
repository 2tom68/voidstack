// VOIDSTACK — core game logic (framework-agnostic, no DOM/rendering dependencies)
// Original ruleset inspired by the "push the marked stack off the grid before it
// reaches you" puzzle genre. All identifiers, names and numbers are original.

export const COLS = 5;
export const ROWS = 9; // row 0 = front/player edge, ROWS-1 = spawn edge
export const START_LIVES = 3;

const BASE_TICK_MS = 950;
const MIN_TICK_MS = 340;
const TICK_STEP_PER_LEVEL = 55;
const CLEARS_PER_LEVEL = 8;

let uid = 1;

class Emitter {
  constructor() { this._l = new Map(); }
  on(evt, fn) {
    if (!this._l.has(evt)) this._l.set(evt, new Set());
    this._l.get(evt).add(fn);
    return () => this._l.get(evt)?.delete(fn);
  }
  emit(evt, payload) {
    this._l.get(evt)?.forEach((fn) => fn(payload));
  }
}

export class VoidStackGame extends Emitter {
  constructor(rng = Math.random) {
    super();
    this.rng = rng;
    this.reset();
  }

  reset() {
    this.stacks = new Map(); // col -> stack
    this.selectedCol = Math.floor(COLS / 2);
    this.score = 0;
    this.combo = 0;
    this.bestCombo = 0;
    this.level = 1;
    this.lives = START_LIVES;
    this.clearsThisLevel = 0;
    this.elapsedMs = 0;
    this._accum = 0;
    this.gameOver = false;
    this.running = false;
    this.emit('reset', this.snapshot());
  }

  start() {
    this.running = true;
    this.emit('start', this.snapshot());
  }

  get tickMs() {
    return Math.max(MIN_TICK_MS, BASE_TICK_MS - (this.level - 1) * TICK_STEP_PER_LEVEL);
  }

  selectDelta(delta) {
    if (this.gameOver || !this.running) return;
    this.selectedCol = Math.min(COLS - 1, Math.max(0, this.selectedCol + delta));
    this.emit('select', this.selectedCol);
  }

  selectCol(col) {
    if (this.gameOver || !this.running) return;
    this.selectedCol = Math.min(COLS - 1, Math.max(0, col));
    this.emit('select', this.selectedCol);
  }

  push() {
    if (this.gameOver || !this.running) return;
    const stack = this.stacks.get(this.selectedCol);
    if (!stack) {
      this.emit('pushEmpty', { col: this.selectedCol });
      return;
    }
    this.stacks.delete(this.selectedCol);
    if (stack.marked) {
      const multiplier = 1 + this.combo * 0.25;
      const gained = Math.round(100 * stack.height * multiplier);
      this.score += gained;
      this.combo += 1;
      this.bestCombo = Math.max(this.bestCombo, this.combo);
      this.clearsThisLevel += 1;
      this.emit('clearedMarked', { stack, gained, combo: this.combo });
      this._maybeLevelUp();
    } else {
      this.combo = 0;
      this._loseLife('pushedSafe', stack);
    }
    this.emit('score', this.score);
    this.emit('combo', this.combo);
  }

  _maybeLevelUp() {
    if (this.clearsThisLevel >= CLEARS_PER_LEVEL) {
      this.clearsThisLevel = 0;
      this.level += 1;
      this.emit('levelUp', this.level);
    }
  }

  _loseLife(reason, stack) {
    this.lives -= 1;
    this.emit('lifeLost', { reason, stack, lives: this.lives });
    if (this.lives <= 0) this._end();
  }

  _end() {
    this.gameOver = true;
    this.running = false;
    this.emit('gameOver', { score: this.score, bestCombo: this.bestCombo, level: this.level });
  }

  _spawn() {
    const freeCols = [];
    for (let c = 0; c < COLS; c++) if (!this.stacks.has(c)) freeCols.push(c);
    if (freeCols.length === 0) return;

    const spawnChance = Math.min(0.85, 0.45 + this.level * 0.04);
    const markedChance = Math.min(0.62, 0.32 + this.level * 0.03);

    for (const col of freeCols) {
      if (this.rng() > spawnChance) continue;
      const stack = {
        id: uid++,
        col,
        row: ROWS - 1,
        height: 1 + Math.floor(this.rng() * 3),
        marked: this.rng() < markedChance,
      };
      this.stacks.set(col, stack);
      this.emit('spawn', stack);
    }
  }

  _advance() {
    for (const [col, stack] of [...this.stacks.entries()]) {
      stack.row -= 1;
      if (stack.row < 0) {
        this.stacks.delete(col);
        if (stack.marked) {
          this._loseLife('escaped', stack);
        } else {
          this.score += 10;
          this.emit('score', this.score);
          this.emit('passedSafe', stack);
        }
      } else {
        this.emit('advance', stack);
      }
    }
    this._spawn();
    this.emit('tick', this.snapshot());
  }

  /** Advance the simulation by dt (ms). Call every animation frame. */
  update(dt) {
    if (!this.running || this.gameOver) return;
    this.elapsedMs += dt;
    this._accum += dt;
    const interval = this.tickMs;
    while (this._accum >= interval) {
      this._accum -= interval;
      this._advance();
    }
  }

  get dangerCols() {
    const cols = [];
    for (const [col, stack] of this.stacks) {
      if (stack.marked && stack.row <= 2) cols.push(col);
    }
    return cols;
  }

  snapshot() {
    return {
      stacks: [...this.stacks.values()].map((s) => ({ ...s })),
      selectedCol: this.selectedCol,
      score: this.score,
      combo: this.combo,
      level: this.level,
      lives: this.lives,
      gameOver: this.gameOver,
    };
  }
}
