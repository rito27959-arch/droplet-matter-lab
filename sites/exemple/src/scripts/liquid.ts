// Moteur du verre liquide Droplet, version 3.
//
// Pour chaque forme, on calcule une fois deux images à partir du même profil
// physique (bord convexe y = (1 − (1 − x)⁴)^¼, loi de Snell, n = 1,5) :
//   1. une carte de déplacement : où chaque pixel du fond doit être lu ;
//   2. une carte de reflets : le bord éclairé par la lumière (en haut à gauche),
//      le contre-reflet en bas à droite, et la tranche assombrie en bas.
// La carte de déplacement est appliquée au fond par un filtre SVG, trois fois,
// une par canal, avec trois indices proches : c'est la dispersion qui irise le
// bord. Méthode publiée par kube.io. Seul Chromium applique un filtre SVG au
// fond ; les autres navigateurs gardent le dépoli et les reflets (qui, eux,
// marchent partout).

export type LensKind = 'bord' | 'loupe';

const profile = (x: number) => Math.pow(1 - Math.pow(1 - Math.min(Math.max(x, 0), 1), 4), 0.25);

function roundSdf(px: number, py: number, w: number, h: number, r: number) {
  const qx = Math.abs(px - w / 2) - (w / 2 - r);
  const qy = Math.abs(py - h / 2) - (h / 2 - r);
  return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
}

type Maps = { displacement: string; specular: string; scale: number };
const cache = new Map<string, Maps>();

// Lumière : en haut à gauche, comme la lumière par défaut d'Apple et de Droplet.
const LX = -0.62, LY = -0.78;

function computeMaps(w: number, h: number, r: number, kind: LensKind, bezel: number, thickness: number): Maps {
  const key = `${w}x${h}r${r}${kind}${bezel}t${thickness}`;
  const hit = cache.get(key);
  if (hit) return hit;
  const ox = new Float32Array(w * h), oy = new Float32Array(w * h);
  const spec = new Uint8ClampedArray(w * h * 4);
  const eta = 1 / 1.5;
  const cx = w / 2, cy = h / 2;
  let max = 1;
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      const px = x + 0.5, py = y + 0.5, i = y * w + x;
      const d = roundSdf(px, py, w, h, r);
      if (d >= 0) continue;
      const t = -d / bezel;
      let dx = 0, dy = 0;
      if (t < 1) {
        const gx = roundSdf(px + 1, py, w, h, r) - roundSdf(px - 1, py, w, h, r);
        const gy = roundSdf(px, py + 1, w, h, r) - roundSdf(px, py - 1, w, h, r);
        const gl = Math.hypot(gx, gy) || 1;
        const nx = gx / gl, ny = gy / gl;
        const e = 0.003;
        const slope = ((profile(t + e) - profile(Math.max(t - e, 0))) / (t + e - Math.max(t - e, 0))) * (thickness / bezel);
        let Nx = nx * slope, Ny = ny * slope, Nz = 1;
        const nl = Math.hypot(Nx, Ny, Nz);
        Nx /= nl; Ny /= nl; Nz /= nl;
        const k = 1 - eta * eta * (1 - Nz * Nz);
        const f = eta * Nz - Math.sqrt(Math.max(k, 0));
        const Tz = -eta + f * Nz;
        const travel = thickness * (0.4 + 0.6 * profile(t));
        dx = ((f * Nx) / Math.max(-Tz, 0.2)) * travel;
        dy = ((f * Ny) / Math.max(-Tz, 0.2)) * travel;

        // Reflets : le bord tourné vers la lumière brille, l'autre bord renvoie
        // un reflet plus faible ; la tranche du bas s'assombrit.
        const facing = nx * LX + ny * LY;
        const edge = Math.pow(1 - t, 6);
        const thin = Math.max(0, 1 - t * 12);
        const hi = Math.min(1, Math.max(facing, 0) ** 1.4 * edge * 0.9 + Math.max(-facing, 0) ** 2 * edge * 0.45 + thin * 0.28);
        const shade = Math.max(ny, 0) ** 2 * Math.pow(1 - t, 3) * 0.1;
        // Blanc posé sur noir, en alpha prémultiplié : pas de cassure entre les deux.
        const a = hi + shade * (1 - hi);
        const j = i * 4;
        if (a > 0) {
          const v = Math.round((hi / a) * 255);
          spec[j] = spec[j + 1] = spec[j + 2] = v;
          spec[j + 3] = Math.round(a * 255);
        }
      }
      if (kind === 'loupe') {
        dx += (cx - px) * 0.3;
        dy += (cy - py) * 0.3;
      }
      ox[i] = dx;
      oy[i] = dy;
      max = Math.max(max, Math.abs(dx), Math.abs(dy));
    }
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const g = c.getContext('2d')!;
  const im = g.createImageData(w, h);
  for (let i = 0; i < w * h; i++) {
    im.data[i * 4] = Math.round(128 + (ox[i] / max) * 127);
    im.data[i * 4 + 1] = Math.round(128 + (oy[i] / max) * 127);
    im.data[i * 4 + 2] = 128;
    im.data[i * 4 + 3] = 255;
  }
  g.putImageData(im, 0, 0);
  const displacement = c.toDataURL();
  g.clearRect(0, 0, w, h);
  g.putImageData(new ImageData(spec, w, h), 0, 0);
  const specular = c.toDataURL();
  // feDisplacementMap lit (C − 0,5) × scale : scale = 2 × déplacement maximal.
  const maps = { displacement, specular, scale: (max * 2 * 127) / 128 };
  cache.set(key, maps);
  return maps;
}

export const lensSupported = (() => {
  const brands = (navigator as Navigator & { userAgentData?: { brands: { brand: string }[] } }).userAgentData?.brands ?? [];
  return brands.some((b) => /Chromium|Google Chrome|Microsoft Edge/.test(b.brand));
})();

let defs: SVGSVGElement | null = null;
let counter = 0;
const NS = 'http://www.w3.org/2000/svg';
const make = <K extends keyof SVGElementTagNameMap>(tag: K, attrs: Record<string, string>) => {
  const el = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
  return el;
};

export type LensOptions = { kind?: LensKind; bezel?: number; thickness?: number; dispersion?: number };

/** Donne à `el` le verre complet : réfraction dispersive (Chromium) et reflets (partout). */
export function lens(el: HTMLElement, opts: LensOptions = {}) {
  if (el.dataset.lensDone) return;
  el.dataset.lensDone = '1';
  const useFilter = lensSupported;
  if (useFilter) document.documentElement.classList.add('lens');
  if (useFilter && !defs) {
    defs = make('svg', { width: '0', height: '0', 'aria-hidden': 'true' });
    defs.style.position = 'absolute';
    document.body.append(defs);
  }
  const id = `lg${++counter}`;
  let filter: SVGFilterElement | null = null;
  let image: SVGFEImageElement | null = null;
  const disps: SVGFEDisplacementMapElement[] = [];
  const dispersion = opts.dispersion ?? 0.035;
  if (useFilter) {
    filter = make('filter', { id, 'color-interpolation-filters': 'sRGB', filterUnits: 'userSpaceOnUse', x: '0', y: '0' });
    image = make('feImage', { result: 'map', preserveAspectRatio: 'none' });
    filter.append(image);
    // Un passage par canal : le bleu dévie un peu plus que le rouge.
    const channels: [string, string][] = [
      ['r', '1 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0'],
      ['g', '0 0 0 0 0  0 1 0 0 0  0 0 0 0 0  0 0 0 1 0'],
      ['b', '0 0 0 0 0  0 0 0 0 0  0 0 1 0 0  0 0 0 1 0'],
    ];
    channels.forEach(([c, m]) => {
      const dm = make('feDisplacementMap', { in: 'SourceGraphic', in2: 'map', xChannelSelector: 'R', yChannelSelector: 'G', result: `d${c}` });
      disps.push(dm);
      filter!.append(dm, make('feColorMatrix', { in: `d${c}`, type: 'matrix', values: m, result: c }));
    });
    filter.append(make('feBlend', { in: 'r', in2: 'g', mode: 'screen', result: 'rg' }), make('feBlend', { in: 'rg', in2: 'b', mode: 'screen' }));
    defs!.append(filter);
    el.style.setProperty('--lg-filtre', `url(#${id})`);
  }

  let key = '';
  const update = () => {
    const w = Math.round(el.offsetWidth), h = Math.round(el.offsetHeight);
    if (!w || !h) return;
    const r = Math.min(parseFloat(getComputedStyle(el).borderTopLeftRadius) || 0, w / 2, h / 2);
    const short = Math.min(w, h);
    // Le biseau occupe une grande part de la forme : c'est ce qui donne l'épaisseur.
    const bezel = Math.min(opts.bezel ?? Math.max(12, short * 0.42), short / 2);
    const thickness = opts.thickness ?? bezel * 1.6;
    const k = `${w}x${h}${r}${bezel}${thickness}`;
    if (k === key) return;
    key = k;
    const big = w * h > 140000;
    const s = big ? 0.5 : 1;
    const maps = computeMaps(Math.round(w * s), Math.round(h * s), r * s, opts.kind ?? 'bord', bezel * s, thickness * s);
    el.style.setProperty('--lg-reflet', `url(${maps.specular})`);
    if (filter && image) {
      filter.setAttribute('width', String(w));
      filter.setAttribute('height', String(h));
      image.setAttribute('width', String(w));
      image.setAttribute('height', String(h));
      image.setAttribute('href', maps.displacement);
      const sc = maps.scale / s;
      disps.forEach((d, i) => d.setAttribute('scale', String(sc * (1 - dispersion + i * dispersion))));
    }
  };
  new ResizeObserver(update).observe(el);
  update();
}

/** Applique le verre à tous les éléments `.lg` (ou marqués `data-lens`) pas encore traités. */
export function lensAll(root: ParentNode = document) {
  root.querySelectorAll<HTMLElement>('.lg, [data-lens]').forEach((el) => lens(el, { kind: (el.dataset.lens as LensKind) || 'bord' }));
}

/** Garde la lumière cohérente sur toute la page (variable --lg-angle, pour les rares effets CSS qui la lisent). */
export function followLight() {
  const root = document.documentElement;
  addEventListener(
    'pointermove',
    (e) => {
      const a = (Math.atan2(e.clientY / innerHeight - 0.5, e.clientX / innerWidth - 0.5) * 180) / Math.PI + 90;
      root.style.setProperty('--lg-angle', `${a.toFixed(0)}deg`);
    },
    { passive: true },
  );
}

/** Ressort amorti, intégré à pas fixe (même modèle que Spring1D de droplet_core). */
export class Spring {
  v = 0;
  target: number;
  constructor(public x: number, public k = 260, public zeta = 0.72) {
    this.target = x;
  }
  step(dt: number) {
    let rest = Math.min(dt, 0.064);
    const c = 2 * this.zeta * Math.sqrt(this.k);
    while (rest > 0) {
      const h = Math.min(rest, 0.004);
      this.v += ((this.target - this.x) * this.k - this.v * c) * h;
      this.x += this.v * h;
      rest -= h;
    }
  }
  get resting() {
    return Math.abs(this.target - this.x) < 0.05 && Math.abs(this.v) < 0.05;
  }
}

/** Boucle d'animation partagée : chaque tâche renvoie true tant qu'elle bouge. */
const tasks = new Set<(dt: number) => boolean>();
let looping = false;
export function animate(task: (dt: number) => boolean) {
  tasks.add(task);
  if (looping) return;
  looping = true;
  let prev = performance.now();
  const frame = (now: number) => {
    const dt = Math.min((now - prev) / 1000, 0.05);
    prev = now;
    for (const t of [...tasks]) if (!t(dt)) tasks.delete(t);
    if (tasks.size) requestAnimationFrame(frame);
    else looping = false;
  };
  requestAnimationFrame(frame);
}

export const reducedMotion = () => matchMedia('(prefers-reduced-motion: reduce)').matches;
