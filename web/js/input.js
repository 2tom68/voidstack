// VOIDSTACK — keyboard, on-screen buttons and canvas touch gesture input.
export class InputController {
  constructor({ canvas, onLeft, onRight, onPush, onPause }) {
    this.canvas = canvas;
    this.onLeft = onLeft;
    this.onRight = onRight;
    this.onPush = onPush;
    this.onPause = onPause;
    this.enabled = true;

    this._touchStart = null;
    this._bindKeyboard();
    this._bindCanvasTouch();
    this._bindButtons();
  }

  setEnabled(v) {
    this.enabled = v;
  }

  _bindKeyboard() {
    window.addEventListener('keydown', (e) => {
      if (!this.enabled) return;
      switch (e.code) {
        case 'ArrowLeft':
        case 'KeyA':
          this.onLeft();
          break;
        case 'ArrowRight':
        case 'KeyD':
          this.onRight();
          break;
        case 'Space':
        case 'ArrowUp':
        case 'KeyW':
          e.preventDefault();
          this.onPush();
          break;
        case 'Escape':
        case 'KeyP':
          this.onPause();
          break;
      }
    });
  }

  _bindCanvasTouch() {
    const COLS = 5;
    this.canvas.addEventListener(
      'touchstart',
      (e) => {
        if (!this.enabled) return;
        const t = e.changedTouches[0];
        this._touchStart = { x: t.clientX, y: t.clientY, time: performance.now() };
      },
      { passive: true }
    );

    this.canvas.addEventListener(
      'touchend',
      (e) => {
        if (!this.enabled || !this._touchStart) return;
        const t = e.changedTouches[0];
        const dx = t.clientX - this._touchStart.x;
        const dy = t.clientY - this._touchStart.y;
        const dt = performance.now() - this._touchStart.time;
        const dist = Math.hypot(dx, dy);

        if (dist < 18 && dt < 400) {
          const col = Math.floor((t.clientX / window.innerWidth) * COLS);
          this._selectAbsolute?.(col);
        } else if (dy < -40 && Math.abs(dy) > Math.abs(dx)) {
          this.onPush();
        } else if (Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy)) {
          if (dx < 0) this.onLeft();
          else this.onRight();
        }
        this._touchStart = null;
      },
      { passive: true }
    );
  }

  bindAbsoluteSelect(fn) {
    this._selectAbsolute = fn;
  }

  _bindButtons() {
    const left = document.getElementById('touch-left');
    const right = document.getElementById('touch-right');
    const push = document.getElementById('touch-push');
    const pause = document.getElementById('btn-pause');

    const tap = (el, fn) => {
      if (!el) return;
      el.addEventListener(
        'touchstart',
        (e) => {
          e.preventDefault();
          if (this.enabled) fn();
        },
        { passive: false }
      );
      el.addEventListener('click', () => {
        if (this.enabled) fn();
      });
    };

    tap(left, () => this.onLeft());
    tap(right, () => this.onRight());
    tap(push, () => this.onPush());
    tap(pause, () => this.onPause());
  }
}
