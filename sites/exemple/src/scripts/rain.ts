// De l'eau sur la vitre, pour le web.
// Même simulation que packages/droplet_glass/lib/src/water/rain_simulation.dart,
// même shader que l'app (water_glass.frag, compilé en WebGL 2).
import shaderSource from '../shaders/water_glass.frag?raw';

type Drop = { x: number; y: number; r: number; vx: number; vy: number; stick: number; trail: number; dead?: boolean };

function rng(seed: number) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

class Rain {
  drops: Drop[] = [];
  t = 0;
  readonly ms = 0.5;
  mw: number;
  mh: number;
  micro: HTMLCanvasElement;
  clear: HTMLCanvasElement;
  height: HTMLCanvasElement;
  private sprite: HTMLCanvasElement;
  private R: () => number;
  private fogAcc = 0;
  private microBudget = 0;
  private spawnBudget = 0;
  private fingerTravel = 0;

  size: number;

  constructor(public w: number, public h: number, seed = 7, public rate = 7) {
    this.R = rng(seed);
    // Sur grand écran, des gouttes un peu plus grosses : la vitre est vue de plus loin.
    this.size = w > 900 ? 1.35 : 1;
    this.mw = Math.ceil(w * this.ms);
    this.mh = Math.ceil(h * this.ms);
    const make = () => {
      const c = document.createElement('canvas');
      c.width = this.mw;
      c.height = this.mh;
      const g = c.getContext('2d', { willReadFrequently: false })!;
      g.fillStyle = '#000';
      g.fillRect(0, 0, c.width, c.height);
      return c;
    };
    this.micro = make();
    this.clear = make();
    this.height = make();
    this.sprite = this.makeSprite(64);
  }

  // Profil d'une goutte posée : bord raide, sommet arrondi, h(d) = (1 − d²)^0,55.
  private makeSprite(n: number) {
    const c = document.createElement('canvas');
    c.width = c.height = n;
    const g = c.getContext('2d')!;
    const im = g.createImageData(n, n);
    for (let y = 0; y < n; y++)
      for (let x = 0; x < n; x++) {
        const dx = ((x + 0.5) / n) * 2 - 1;
        const dy = ((y + 0.5) / n) * 2 - 1;
        const d = Math.sqrt(dx * dx + dy * dy);
        let v = d < 1 ? Math.pow(1 - d * d, 0.55) : 0;
        v *= Math.min(1, Math.max(0, (1 - d) * n * 0.5));
        const i = (y * n + x) * 4;
        im.data[i] = im.data[i + 1] = im.data[i + 2] = Math.round(v * 255);
        im.data[i + 3] = 255;
      }
    g.putImageData(im, 0, 0);
    return c;
  }

  spawn(x: number, y: number, r: number) {
    this.drops.push({ x, y, r, vx: 0, vy: 0, stick: 0, trail: 0 });
  }

  private eraseMicro(strokes: (g: CanvasRenderingContext2D) => void) {
    const mg = this.micro.getContext('2d')!;
    mg.globalCompositeOperation = 'source-over';
    mg.strokeStyle = '#000';
    mg.lineCap = 'round';
    strokes(mg);
  }

  step(dt: number) {
    dt = Math.min(dt, 0.05);
    this.t += dt;
    const R = this.R;
    const s = this.ms;

    this.spawnBudget += this.rate * dt;
    while (this.spawnBudget >= 1) {
      this.spawnBudget -= 1;
      this.spawn(R() * this.w, R() * this.h * 0.95, (3 + Math.pow(R(), 2.2) * 11) * this.size);
    }

    const mg = this.micro.getContext('2d')!;
    mg.globalCompositeOperation = 'lighten';
    this.microBudget += dt * (this.t < 2 ? 500 : 60) * (this.w * this.h) / (390 * 844);
    let m = Math.floor(this.microBudget);
    this.microBudget -= m;
    while (m-- > 0) {
      const x = R() * this.mw, y = R() * this.mh, r = (0.8 + R() * 2.1) * s;
      mg.globalAlpha = 0.1 + R() * 0.12;
      mg.drawImage(this.sprite, x - r, y - r, 2 * r, 2 * r);
    }
    mg.globalAlpha = 1;

    // La buée revient, par paliers (une carte 8 bits ne décroît pas de moins d'un niveau).
    const cg = this.clear.getContext('2d')!;
    this.fogAcc += dt;
    if (this.fogAcc >= 0.25) {
      cg.globalCompositeOperation = 'source-over';
      cg.fillStyle = `rgba(0,0,0,${this.fogAcc / 9})`;
      cg.fillRect(0, 0, this.mw, this.mh);
      this.fogAcc = 0;
    }

    const born: Drop[] = [];
    cg.strokeStyle = '#fff';
    cg.lineCap = 'round';
    for (const d of this.drops) {
      const ox = d.x, oy = d.y;
      if (d.r > 8.5 * this.size) {
        if (d.stick > 0) {
          d.stick -= dt;
          d.vy *= Math.pow(0.02, dt);
        } else {
          d.vy = Math.min(d.vy + 900 * Math.min(1, (d.r - 8.5 * this.size) / 6) * dt, 60 + d.r * 22);
          if (R() < dt * 1.6) d.stick = 0.05 + R() * 0.35;
        }
        d.vx = (d.vx + (R() - 0.5) * dt * 120) * Math.pow(0.05, dt);
      } else {
        d.vy *= Math.pow(0.01, dt);
        d.vx *= 0.5;
      }
      d.x += d.vx * dt;
      d.y += d.vy * dt;
      if (d.vy > 4) {
        d.trail += d.vy * dt;
        if (d.trail > d.r * (1.1 + R() * 1.4)) {
          d.trail = 0;
          const tr = d.r * (0.22 + R() * 0.16);
          born.push({ x: d.x + (R() - 0.5) * d.r * 0.3, y: d.y - d.r * 1.05, r: tr, vx: 0, vy: 0, stick: 0, trail: 0 });
          d.r = Math.cbrt(Math.max(d.r ** 3 - tr ** 3, 1));
        }
      }
      // L'eau essuie la buée et absorbe la condensation sur son passage.
      cg.lineWidth = d.r * s * 2.85;
      cg.beginPath();
      cg.moveTo(ox * s, oy * s);
      cg.lineTo(d.x * s, d.y * s + 0.01);
      cg.stroke();
      mg.globalCompositeOperation = 'source-over';
      mg.strokeStyle = '#000';
      mg.lineCap = 'round';
      mg.lineWidth = d.r * s * 3;
      mg.beginPath();
      mg.moveTo(ox * s, oy * s);
      mg.lineTo(d.x * s, d.y * s + 0.01);
      mg.stroke();
    }
    this.drops.push(...born);

    // Fusion à volume constant : r = ∛(r₁³ + r₂³).
    this.drops.sort((a, b) => a.y - b.y);
    for (let i = 0; i < this.drops.length; i++) {
      const a = this.drops[i];
      if (a.dead) continue;
      for (let j = i + 1; j < this.drops.length; j++) {
        const b = this.drops[j];
        if (b.dead) continue;
        if (b.y - a.y > a.r + b.r) break;
        const dx = a.x - b.x, dy = a.y - b.y, reach = (a.r + b.r) * 0.75;
        if (dx * dx + dy * dy < reach * reach) {
          const va = a.r ** 3, vb = b.r ** 3;
          const big = va >= vb ? a : b, small = big === a ? b : a;
          big.x = (a.x * va + b.x * vb) / (va + vb);
          big.y = Math.max(a.y, b.y);
          big.r = Math.cbrt(va + vb);
          big.vy = Math.max(a.vy, b.vy);
          big.stick = 0;
          small.dead = true;
        }
      }
    }
    this.drops = this.drops.filter((d) => !d.dead && d.y - d.r < this.h && d.r > 0.8);
    const max = Math.round(260 * Math.min(2.5, (this.w * this.h) / (390 * 844)));
    if (this.drops.length > max) this.drops.splice(0, this.drops.length - max);
  }

  // Le doigt essuie : la buée part, l'eau est ramassée et repoussée en perles au bord du sillon.
  wipe(x0: number, y0: number, x1: number, y1: number) {
    const s = this.ms, R = this.R, fr = 23;
    const cg = this.clear.getContext('2d')!;
    cg.strokeStyle = '#fff';
    cg.lineCap = 'round';
    cg.lineWidth = fr * 2 * s;
    cg.beginPath();
    cg.moveTo(x0 * s, y0 * s);
    cg.lineTo(x1 * s, y1 * s + 0.01);
    cg.stroke();
    this.eraseMicro((g) => {
      g.lineWidth = (fr * 2 + 4) * s;
      g.beginPath();
      g.moveTo(x0 * s, y0 * s);
      g.lineTo(x1 * s, y1 * s + 0.01);
      g.stroke();
    });
    const sx = x1 - x0, sy = y1 - y0, len2 = Math.max(1, sx * sx + sy * sy);
    let gathered = 0;
    for (const d of this.drops) {
      const t = Math.max(0, Math.min(1, ((d.x - x0) * sx + (d.y - y0) * sy) / len2));
      const px = x0 + sx * t, py = y0 + sy * t;
      if ((d.x - px) ** 2 + (d.y - py) ** 2 < (fr + d.r * 0.5) ** 2) {
        gathered += d.r ** 3;
        d.dead = true;
      }
    }
    this.drops = this.drops.filter((d) => !d.dead);
    const len = Math.hypot(sx, sy);
    this.fingerTravel += len;
    if (len > 0 && this.fingerTravel > 16) {
      this.fingerTravel = 0;
      const nx = -sy / len, ny = sx / len, side = R() < 0.5 ? -1 : 1, off = fr + 4 + R() * 4;
      this.spawn(x1 + nx * side * off, y1 + ny * side * off, Math.min(Math.cbrt(gathered + (3 + R() * 4) ** 3), 13));
    }
  }

  render() {
    const s = this.ms;
    const hg = this.height.getContext('2d')!;
    hg.globalCompositeOperation = 'source-over';
    hg.globalAlpha = 1;
    hg.drawImage(this.micro, 0, 0);
    hg.globalCompositeOperation = 'lighten';
    for (const d of this.drops) {
      hg.globalAlpha = Math.min(1, 0.45 + d.r / 22);
      const st = Math.min(d.vy * 0.004, 0.35);
      const rx = d.r * (1 - st * 0.4) * s, ry = d.r * (1 + st) * s;
      hg.drawImage(this.sprite, d.x * s - rx, d.y * s - ry * 1.1, 2 * rx, 2 * ry);
    }
    hg.globalAlpha = 1;
    hg.globalCompositeOperation = 'source-over';
  }
}

export type WaterOptions = { fog?: number; refraction?: number; rate?: number; dark: boolean };

/** Monte la vitre mouillée dans `canvas`. Renvoie une fonction de nettoyage, ou null sans WebGL 2. */
export function mountWater(canvas: HTMLCanvasElement, images: { dark: string; light: string }, opts: () => WaterOptions) {
  const gl = canvas.getContext('webgl2', { premultipliedAlpha: false, antialias: false });
  if (!gl) return null;
  const reduce = matchMedia('(prefers-reduced-motion: reduce)');

  const vs = '#version 300 es\nin vec2 a;void main(){gl_Position=vec4(a,0.,1.);}';
  const fs = shaderSource.replace(
    '#define FlutterFragCoord() vec2(gl_FragCoord.x, uSize.y - gl_FragCoord.y)',
    'uniform float uDpr;\n#define FlutterFragCoord() (vec2(gl_FragCoord.x, uSize.y * uDpr - gl_FragCoord.y) / uDpr)',
  );
  const compile = (type: number, src: string) => {
    const o = gl.createShader(type)!;
    gl.shaderSource(o, src);
    gl.compileShader(o);
    if (!gl.getShaderParameter(o, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(o) ?? 'shader');
    return o;
  };
  const prog = gl.createProgram()!;
  try {
    gl.attachShader(prog, compile(gl.VERTEX_SHADER, vs));
    gl.attachShader(prog, compile(gl.FRAGMENT_SHADER, fs));
  } catch (e) {
    console.warn(e);
    return null;
  }
  gl.linkProgram(prog);
  if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) return null;
  gl.useProgram(prog);
  const buf = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buf);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
  const loc = gl.getAttribLocation(prog, 'a');
  gl.enableVertexAttribArray(loc);
  gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);

  const tex = (unit: number) => {
    const t = gl.createTexture()!;
    gl.activeTexture(gl.TEXTURE0 + unit);
    gl.bindTexture(gl.TEXTURE_2D, t);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, unit >= 2 ? gl.NEAREST : gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([0, 0, 0, 255]));
    return t;
  };
  const tScene = tex(0), tBlur = tex(1), tHeight = tex(2), tClear = tex(3);
  ['uScene', 'uSceneBlur', 'uHeight', 'uClear'].forEach((n, i) => gl.uniform1i(gl.getUniformLocation(prog, n), i));
  const U = (n: string) => gl.getUniformLocation(prog, n);

  let imgSize = [1, 1];
  let loadedTheme: boolean | null = null;
  async function loadScene(dark: boolean) {
    loadedTheme = dark;
    const img = new Image();
    img.src = dark ? images.dark : images.light;
    await img.decode();
    if (loadedTheme !== dark) return;
    imgSize = [img.naturalWidth, img.naturalHeight];
    const b = document.createElement('canvas');
    b.width = img.naturalWidth / 2;
    b.height = img.naturalHeight / 2;
    const bg = b.getContext('2d')!;
    bg.filter = 'blur(11px)';
    bg.drawImage(img, 0, 0, b.width, b.height);
    gl!.activeTexture(gl!.TEXTURE0);
    gl!.bindTexture(gl!.TEXTURE_2D, tScene);
    gl!.texImage2D(gl!.TEXTURE_2D, 0, gl!.RGBA, gl!.RGBA, gl!.UNSIGNED_BYTE, img);
    gl!.activeTexture(gl!.TEXTURE1);
    gl!.bindTexture(gl!.TEXTURE_2D, tBlur);
    gl!.texImage2D(gl!.TEXTURE_2D, 0, gl!.RGBA, gl!.RGBA, gl!.UNSIGNED_BYTE, b);
    canvas.dataset.ready = 'true';
  }

  let rain: Rain | null = null;
  let w = 0, h = 0, dpr = 1;
  function resize() {
    const r = canvas.getBoundingClientRect();
    dpr = Math.min(devicePixelRatio || 1, 2);
    const nw = Math.round(r.width), nh = Math.round(r.height);
    canvas.width = Math.round(nw * dpr);
    canvas.height = Math.round(nh * dpr);
    if (!rain || Math.abs(nw - w) > 40 || Math.abs(nh - h) > 120) {
      w = nw;
      h = nh;
      rain = new Rain(w, h, 7, opts().rate ?? 7);
      // Pluie simulée avant la première image : la vitre ne part pas vide.
      for (let i = 0; i < 8 * 30; i++) rain.step(1 / 30);
    }
  }
  const ro = new ResizeObserver(resize);
  ro.observe(canvas);
  resize();

  let last: { x: number; y: number } | null = null;
  const pos = (e: PointerEvent) => {
    const r = canvas.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  };
  const down = (e: PointerEvent) => {
    last = pos(e);
    rain?.wipe(last.x, last.y, last.x, last.y);
  };
  const move = (e: PointerEvent) => {
    if (!last) return;
    const p = pos(e);
    rain?.wipe(last.x, last.y, p.x, p.y);
    last = p;
  };
  const up = () => (last = null);
  canvas.addEventListener('pointerdown', down);
  canvas.addEventListener('pointermove', move);
  window.addEventListener('pointerup', up);

  let visible = true;
  const io = new IntersectionObserver(([e]) => (visible = e.isIntersecting));
  io.observe(canvas);

  let raf = 0, prev = performance.now();
  function frame(now: number) {
    raf = requestAnimationFrame(frame);
    const dt = Math.min((now - prev) / 1000, 0.05);
    prev = now;
    if (!visible || document.hidden || !rain) return;
    const o = opts();
    if (loadedTheme !== o.dark) loadScene(o.dark);
    rain.rate = o.rate ?? 7;
    // Animations réduites : la vitre reste figée, seul le doigt agit.
    if (!reduce.matches) rain.step(dt);
    rain.render();
    gl!.activeTexture(gl!.TEXTURE2);
    gl!.bindTexture(gl!.TEXTURE_2D, tHeight);
    gl!.texImage2D(gl!.TEXTURE_2D, 0, gl!.RGBA, gl!.RGBA, gl!.UNSIGNED_BYTE, rain.height);
    gl!.activeTexture(gl!.TEXTURE3);
    gl!.bindTexture(gl!.TEXTURE_2D, tClear);
    gl!.texImage2D(gl!.TEXTURE_2D, 0, gl!.RGBA, gl!.RGBA, gl!.UNSIGNED_BYTE, rain.clear);
    gl!.uniform2f(U('uSize'), w, h);
    gl!.uniform1f(U('uDpr'), dpr);
    gl!.uniform1f(U('uTime'), rain.t);
    gl!.uniform1f(U('uQuality'), 3);
    gl!.uniform1f(U('uTheme'), o.dark ? 1 : 0);
    gl!.uniform2f(U('uPointer'), w * 0.82, h * 0.08);
    gl!.uniform1f(U('uMotion'), reduce.matches ? 0 : 1);
    gl!.uniform2f(U('uImageSize'), imgSize[0], imgSize[1]);
    gl!.uniform1f(U('uFog'), o.fog ?? 1);
    gl!.uniform1f(U('uRefraction'), o.refraction ?? 300);
    gl!.uniform1f(U('uDropHeight'), 14);
    gl!.uniform2f(U('uMapSize'), rain.mw, rain.mh);
    gl!.viewport(0, 0, canvas.width, canvas.height);
    gl!.drawArrays(gl!.TRIANGLE_STRIP, 0, 4);
  }
  raf = requestAnimationFrame(frame);

  return () => {
    cancelAnimationFrame(raf);
    ro.disconnect();
    io.disconnect();
    window.removeEventListener('pointerup', up);
  };
}
