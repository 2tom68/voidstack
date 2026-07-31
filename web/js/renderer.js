// VOIDSTACK — Three.js neon renderer: bloom postprocessing, particle bursts, camera shake.
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { SMAAPass } from 'three/addons/postprocessing/SMAAPass.js';
import { COLS, ROWS } from './game.js';

const CELL = 1.25;
const MARKED_COLOR = new THREE.Color('#ff3e6a');
const SAFE_COLOR = new THREE.Color('#3ec8ff');
const CYAN = new THREE.Color('#4be9ff');
const MAGENTA = new THREE.Color('#ff3ec8');

function colToX(col) {
  return (col - (COLS - 1) / 2) * CELL;
}
function rowToZ(row) {
  return -row * CELL;
}

function makeSoftDotTexture() {
  const size = 64;
  const c = document.createElement('canvas');
  c.width = c.height = size;
  const ctx = c.getContext('2d');
  const g = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  g.addColorStop(0, 'rgba(255,255,255,1)');
  g.addColorStop(0.4, 'rgba(255,255,255,0.7)');
  g.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, size, size);
  const tex = new THREE.CanvasTexture(c);
  tex.needsUpdate = true;
  return tex;
}

export class VoidStackRenderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.clock = new THREE.Clock();
    this.stackVisuals = new Map(); // stack id -> { group, pos, rotX, marked, roll }
    this.particles = [];
    this.shakeTime = 0;
    this.shakeAmp = 0;
    this.warningCols = new Set();
    this._time = 0;

    this._initScene();
    this.dotTexture = makeSoftDotTexture();
    this._initPost();
    this._buildBoard();
    this._buildBackdrop();
    window.addEventListener('resize', () => this.resize());
  }

  _initScene() {
    const renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      antialias: false,
      alpha: false,
      powerPreference: 'high-performance',
    });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 0.95;
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer = renderer;

    const scene = new THREE.Scene();
    scene.background = new THREE.Color('#05030f');
    scene.fog = new THREE.FogExp2(0x05030f, 0.032);
    this.scene = scene;

    const aspect = window.innerWidth / window.innerHeight;
    const camera = new THREE.PerspectiveCamera(48, aspect, 0.1, 100);
    this.baseCamPos = new THREE.Vector3(0, 8.6, 6.4);
    camera.position.copy(this.baseCamPos);
    camera.lookAt(0, 0, rowToZ(ROWS * 0.42));
    this.camera = camera;

    scene.add(new THREE.AmbientLight(0x2a3a66, 0.8));
    const key = new THREE.PointLight(0x4be9ff, 9, 30, 2);
    key.position.set(0, 6, 2);
    scene.add(key);
    const rim = new THREE.PointLight(0xff3ec8, 7, 30, 2);
    rim.position.set(0, 4, rowToZ(ROWS));
    scene.add(rim);
  }

  _initPost() {
    const composer = new EffectComposer(this.renderer);
    composer.addPass(new RenderPass(this.scene, this.camera));
    const bloom = new UnrealBloomPass(
      new THREE.Vector2(window.innerWidth, window.innerHeight),
      0.55, // strength
      0.4, // radius
      0.42 // threshold
    );
    this.bloom = bloom;
    composer.addPass(bloom);
    composer.addPass(new SMAAPass(window.innerWidth * this.renderer.getPixelRatio(), window.innerHeight * this.renderer.getPixelRatio()));
    composer.addPass(new OutputPass());
    this.composer = composer;
  }

  _buildBoard() {
    const boardW = COLS * CELL;
    const boardD = ROWS * CELL;

    const floor = new THREE.Mesh(
      new THREE.PlaneGeometry(boardW + 2, boardD + 4),
      new THREE.MeshStandardMaterial({ color: 0x0a0a1e, emissive: 0x090418, emissiveIntensity: 0.6, roughness: 0.75, metalness: 0.2 })
    );
    floor.rotation.x = -Math.PI / 2;
    floor.position.set(0, -0.01, rowToZ(ROWS / 2 - 0.5));
    this.scene.add(floor);

    const grid = new THREE.GridHelper(Math.max(boardW, boardD) + 4, Math.max(COLS, ROWS) + 4, 0x7ff0ff, 0x2a4a7a);
    grid.position.set(0, 0.005, rowToZ(ROWS / 2 - 0.5));
    grid.material.transparent = true;
    grid.material.opacity = 0.85;
    this.scene.add(grid);

    // front edge (player line) — glowing magenta bar
    const edge = new THREE.Mesh(
      new THREE.BoxGeometry(boardW + 0.6, 0.08, 0.12),
      new THREE.MeshStandardMaterial({ color: MAGENTA, emissive: MAGENTA, emissiveIntensity: 1.3 })
    );
    edge.position.set(0, 0.04, rowToZ(-0.5));
    this.scene.add(edge);

    // column lanes (subtle glowing separators)
    for (let c = 0; c <= COLS; c++) {
      const x = colToX(c - 0.5) + CELL / 2;
      const points = [new THREE.Vector3(x, 0.02, rowToZ(-0.6)), new THREE.Vector3(x, 0.02, rowToZ(ROWS - 0.4))];
      const geo = new THREE.BufferGeometry().setFromPoints(points);
      const mat = new THREE.LineBasicMaterial({ color: 0x1c3868, transparent: true, opacity: 0.6 });
      this.scene.add(new THREE.Line(geo, mat));
    }

    // selector reticle
    const reticleGeo = new THREE.RingGeometry(CELL * 0.34, CELL * 0.42, 24);
    const reticleMat = new THREE.MeshBasicMaterial({ color: CYAN, transparent: true, opacity: 0.9, side: THREE.DoubleSide });
    const reticle = new THREE.Mesh(reticleGeo, reticleMat);
    reticle.rotation.x = -Math.PI / 2;
    reticle.position.set(0, 0.03, rowToZ(0));
    this.scene.add(reticle);
    this.reticle = reticle;
  }

  _buildBackdrop() {
    const count = 500;
    const positions = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) {
      positions[i * 3] = (Math.random() - 0.5) * 60;
      positions[i * 3 + 1] = Math.random() * 30;
      positions[i * 3 + 2] = rowToZ(ROWS / 2) + (Math.random() - 0.5) * 80;
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    const mat = new THREE.PointsMaterial({ color: 0x4be9ff, size: 0.16, map: this.dotTexture, transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false });
    this.dust = new THREE.Points(geo, mat);
    this.scene.add(this.dust);
  }

  _stackHeightWorld(h) {
    return h * 0.62;
  }

  _makeStackMesh(stack) {
    const group = new THREE.Group();
    const color = stack.marked ? MARKED_COLOR : SAFE_COLOR;
    for (let i = 0; i < stack.height; i++) {
      const size = 0.94 * CELL;
      const cubeH = 0.58;
      const geo = new THREE.BoxGeometry(size, cubeH, size);
      const mat = new THREE.MeshStandardMaterial({
        color: stack.marked ? 0x220a14 : 0x0a1622,
        emissive: color,
        emissiveIntensity: stack.marked ? 0.85 : 0.5,
        roughness: 0.4,
        metalness: 0.2,
      });
      const cube = new THREE.Mesh(geo, mat);
      cube.position.y = i * (cubeH + 0.03) + cubeH / 2;
      const edges = new THREE.LineSegments(
        new THREE.EdgesGeometry(geo),
        new THREE.LineBasicMaterial({ color, transparent: true, opacity: 0.9 })
      );
      cube.add(edges);
      group.add(cube);
    }
    this.scene.add(group);
    return group;
  }

  /** Creates a stack instantly at its spawn cell (no animation). */
  spawnStack(stack) {
    if (this.stackVisuals.has(stack.id)) return;
    const group = this._makeStackMesh(stack);
    const pos = new THREE.Vector3(colToX(stack.col), 0, rowToZ(stack.row));
    group.position.copy(pos);
    this.stackVisuals.set(stack.id, { group, pos, rotX: 0, marked: stack.marked, roll: null });
  }

  /** Rolls (tumbles) a stack one cell forward to its new row — no gliding, a discrete pivot roll per tick. */
  rollStack(stack) {
    const visual = this.stackVisuals.get(stack.id);
    if (!visual) {
      this.spawnStack(stack);
      return;
    }
    const toPos = new THREE.Vector3(colToX(stack.col), 0, rowToZ(stack.row));
    visual.roll = {
      fromPos: visual.pos.clone(),
      toPos,
      fromRot: visual.rotX,
      toRot: visual.rotX - Math.PI / 2,
      elapsed: 0,
      duration: 0.22,
    };
  }

  removeStack(id) {
    const visual = this.stackVisuals.get(id);
    if (!visual) return;
    this._disposeGroup(visual.group);
    this.stackVisuals.delete(id);
  }

  clearStacks() {
    for (const id of [...this.stackVisuals.keys()]) this.removeStack(id);
  }

  _disposeGroup(group) {
    this.scene.remove(group);
    group.traverse((obj) => {
      if (obj.geometry) obj.geometry.dispose();
      if (obj.material) obj.material.dispose();
    });
  }

  setSelected(col) {
    this._selectedCol = col;
  }

  setWarningCols(cols) {
    this.warningCols = new Set(cols);
  }

  burst(col, row, marked) {
    const color = marked ? MARKED_COLOR : SAFE_COLOR;
    const n = 46;
    const positions = new Float32Array(n * 3);
    const velocities = new Float32Array(n * 3);
    const origin = new THREE.Vector3(colToX(col), 0.5, rowToZ(row));
    for (let i = 0; i < n; i++) {
      positions[i * 3] = origin.x;
      positions[i * 3 + 1] = origin.y;
      positions[i * 3 + 2] = origin.z;
      const theta = Math.random() * Math.PI * 2;
      const phi = Math.random() * Math.PI;
      const speed = 2.2 + Math.random() * 3.2;
      velocities[i * 3] = Math.sin(phi) * Math.cos(theta) * speed;
      velocities[i * 3 + 1] = Math.abs(Math.cos(phi)) * speed + 1.5;
      velocities[i * 3 + 2] = Math.sin(phi) * Math.sin(theta) * speed;
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    const mat = new THREE.PointsMaterial({ color, size: 0.26, map: this.dotTexture, transparent: true, opacity: 1, blending: THREE.AdditiveBlending, depthWrite: false });
    const points = new THREE.Points(geo, mat);
    this.scene.add(points);
    this.particles.push({ points, velocities, life: 0, maxLife: 0.9 });
  }

  shake(amp = 0.35, time = 0.35) {
    this.shakeAmp = amp;
    this.shakeTime = time;
  }

  resize() {
    const w = window.innerWidth;
    const h = window.innerHeight;
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
    this.composer.setSize(w, h);
    this.bloom.setSize(w, h);
  }

  update(dt) {
    this._time += dt;

    for (const visual of this.stackVisuals.values()) {
      const group = visual.group;
      if (visual.roll) {
        const r = visual.roll;
        r.elapsed += dt;
        const t = Math.min(1, r.elapsed / r.duration);
        const eased = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
        const hop = Math.sin(Math.PI * t) * 0.22;
        group.position.x = r.fromPos.x + (r.toPos.x - r.fromPos.x) * eased;
        group.position.z = r.fromPos.z + (r.toPos.z - r.fromPos.z) * eased;
        group.position.y = r.fromPos.y + (r.toPos.y - r.fromPos.y) * eased + hop;
        group.rotation.x = r.fromRot + (r.toRot - r.fromRot) * eased;
        if (t >= 1) {
          visual.pos.copy(r.toPos);
          visual.rotX = r.toRot;
          group.position.copy(r.toPos);
          group.rotation.x = r.toRot;
          visual.roll = null;
        }
      }
      if (visual.marked) {
        const pulse = 0.75 + Math.sin(this._time * 6) * 0.35;
        group.children.forEach((cube) => {
          if (cube.material) cube.material.emissiveIntensity = pulse;
        });
      }
    }

    if (this.reticle && this._selectedCol !== undefined) {
      const tx = colToX(this._selectedCol);
      this.reticle.position.x += (tx - this.reticle.position.x) * Math.min(1, dt * 12);
      const s = 1 + Math.sin(this._time * 8) * 0.08;
      this.reticle.scale.set(s, s, 1);
      const isDanger = this.warningCols.has(this._selectedCol);
      this.reticle.material.color.copy(isDanger ? MARKED_COLOR : CYAN);
    }

    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.life += dt;
      const pos = p.points.geometry.attributes.position;
      for (let j = 0; j < pos.count; j++) {
        pos.array[j * 3] += p.velocities[j * 3] * dt;
        pos.array[j * 3 + 1] += (p.velocities[j * 3 + 1] - 6 * p.life) * dt;
        pos.array[j * 3 + 2] += p.velocities[j * 3 + 2] * dt;
      }
      pos.needsUpdate = true;
      p.points.material.opacity = Math.max(0, 1 - p.life / p.maxLife);
      if (p.life >= p.maxLife) {
        this.scene.remove(p.points);
        p.points.geometry.dispose();
        p.points.material.dispose();
        this.particles.splice(i, 1);
      }
    }

    if (this.dust) this.dust.rotation.y += dt * 0.01;

    if (this.shakeTime > 0) {
      this.shakeTime -= dt;
      const f = Math.max(0, this.shakeTime);
      const amp = this.shakeAmp * f;
      this.camera.position.set(
        this.baseCamPos.x + (Math.random() - 0.5) * amp,
        this.baseCamPos.y + (Math.random() - 0.5) * amp,
        this.baseCamPos.z + (Math.random() - 0.5) * amp
      );
    } else {
      this.camera.position.copy(this.baseCamPos);
    }

    this.composer.render();
  }
}
