// Verre à profil physique pour le web : la barre courbe ce qui passe dessous.
//
// Même modèle que packages/droplet_glass/shaders/lib/glass.glsl : bord convexe
// y = (1 − (1 − x)⁴)^¼, normale tirée de la pente, réfraction de Snell (n = 1,5).
// Le déplacement de chaque pixel est écrit dans une image, puis appliqué au fond
// par un filtre SVG (feDisplacementMap) dans `backdrop-filter` — méthode publiée
// par kube.io. Seul Chromium sait appliquer un filtre SVG au fond : ailleurs,
// la barre garde un verre dépoli classique.

const profile = (x: number) => Math.pow(1 - Math.pow(1 - Math.min(Math.max(x, 0), 1), 4), 0.25);

function pillSdf(px: number, py: number, w: number, h: number) {
  const r = h / 2;
  const qx = Math.abs(px - w / 2) - (w / 2 - r);
  const qy = Math.abs(py - h / 2) - (h / 2 - r);
  const ox = Math.max(qx, 0), oy = Math.max(qy, 0);
  return Math.hypot(ox, oy) + Math.min(Math.max(qx, qy), 0) - r;
}

function displacementMap(w: number, h: number, bezel: number, thickness: number, scale: number) {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const g = c.getContext('2d')!;
  const im = g.createImageData(w, h);
  const eta = 1 / 1.5;
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      const px = x + 0.5, py = y + 0.5;
      const d = pillSdf(px, py, w, h);
      let ox = 0, oy = 0;
      const t = -d / bezel;
      if (d < 0 && t < 1) {
        const gx = pillSdf(px + 1, py, w, h) - pillSdf(px - 1, py, w, h);
        const gy = pillSdf(px, py + 1, w, h) - pillSdf(px, py - 1, w, h);
        const gl = Math.hypot(gx, gy) || 1;
        const nx = gx / gl, ny = gy / gl;
        const e = 0.004;
        const slope = ((profile(t + e) - profile(Math.max(t - e, 0))) / (t + e - Math.max(t - e, 0))) * (thickness / bezel);
        // Normale 3D, puis réfraction d'un rayon vertical : T = η·I + (η·cosθi − √k)·N.
        let Nx = nx * slope, Ny = ny * slope, Nz = 1;
        const nl = Math.hypot(Nx, Ny, Nz);
        Nx /= nl; Ny /= nl; Nz /= nl;
        const cosi = Nz; // −I·N avec I = (0, 0, −1)
        const k = 1 - eta * eta * (1 - cosi * cosi);
        const f = eta * cosi - Math.sqrt(Math.max(k, 0));
        const Tx = f * Nx, Ty = f * Ny, Tz = -eta + f * Nz;
        const travel = thickness * (0.35 + 0.65 * profile(t));
        ox = (Tx / Math.max(-Tz, 0.25)) * travel;
        oy = (Ty / Math.max(-Tz, 0.25)) * travel;
      }
      const i = (y * w + x) * 4;
      im.data[i] = Math.round(128 + (ox / scale) * 255);
      im.data[i + 1] = Math.round(128 + (oy / scale) * 255);
      im.data[i + 2] = 128;
      im.data[i + 3] = 255;
    }
  g.putImageData(im, 0, 0);
  return c.toDataURL();
}

export function lensSupported() {
  const brands = (navigator as Navigator & { userAgentData?: { brands: { brand: string }[] } }).userAgentData?.brands ?? [];
  return brands.some((b) => /Chromium|Google Chrome|Microsoft Edge/.test(b.brand));
}

/** Donne à `el` une réfraction de bord, si le navigateur le permet. */
export function applyLens(el: HTMLElement, id: string, bezel = 16, thickness = 18) {
  if (!lensSupported()) return;
  document.documentElement.classList.add('lens');
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('width', '0');
  svg.setAttribute('height', '0');
  svg.setAttribute('aria-hidden', 'true');
  svg.style.position = 'absolute';
  const filter = document.createElementNS(ns, 'filter');
  filter.id = id;
  filter.setAttribute('color-interpolation-filters', 'sRGB');
  filter.setAttribute('filterUnits', 'userSpaceOnUse');
  const image = document.createElementNS(ns, 'feImage');
  image.setAttribute('result', 'map');
  const disp = document.createElementNS(ns, 'feDisplacementMap');
  disp.setAttribute('in', 'SourceGraphic');
  disp.setAttribute('in2', 'map');
  disp.setAttribute('xChannelSelector', 'R');
  disp.setAttribute('yChannelSelector', 'G');
  filter.append(image, disp);
  svg.append(filter);
  document.body.append(svg);

  const scale = 60;
  let key = '';
  const update = () => {
    const w = Math.round(el.offsetWidth), h = Math.round(el.offsetHeight);
    if (!w || !h || `${w}x${h}` === key) return;
    key = `${w}x${h}`;
    filter.setAttribute('x', '0');
    filter.setAttribute('y', '0');
    filter.setAttribute('width', String(w));
    filter.setAttribute('height', String(h));
    image.setAttribute('width', String(w));
    image.setAttribute('height', String(h));
    image.setAttribute('href', displacementMap(w, h, bezel, thickness, scale));
    disp.setAttribute('scale', String(scale));
  };
  new ResizeObserver(update).observe(el);
  update();
}
