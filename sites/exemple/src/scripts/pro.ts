// Prototype Droplet Pro — le comportement (voir src/pages/pro/index.astro).
// Rien n'est envoyé : le paiement est simulé, le numéro reste dans la page.

type Avantage = { cle: string; titre: string; court: string; long: string };
const { avantages, palette } = JSON.parse(document.getElementById('donnees')!.textContent!) as {
  avantages: Avantage[];
  palette: string[];
};
const $ = <T extends Element = HTMLElement>(s: string, r: ParentNode = document) => r.querySelector(s) as T;
const $$ = <T extends Element = HTMLElement>(s: string, r: ParentNode = document) => [...r.querySelectorAll(s)] as T[];
const calme = matchMedia('(prefers-reduced-motion: reduce)').matches;
const vibre = (ms: number | number[]) => {
  try {
    navigator.vibrate?.(ms);
  } catch {}
};

// ── L'offre choisie ─────────────────────────────────────────────
const offres = {
  pro: { nom: 'Droplet Pro', duree: 'une fois, à vie', prix: '1 000', titre: 'Droplet Pro activé', texte: 'Le badge Pro accompagne votre nom, et toutes les icônes et tous les fonds vous sont ouverts.' },
  pack: { nom: 'Le pack', duree: 'une fois', prix: '500', titre: 'Pack débloqué', texte: 'Les dix icônes et les huit fonds du pack vous sont ouverts, dans les réglages.' },
};
let offre: keyof typeof offres = 'pro';
function choisirOffre(o: keyof typeof offres) {
  offre = o;
  $$('.offre').forEach((b) => b.setAttribute('aria-checked', String(b.dataset.offre === o)));
  const v = offres[o];
  $('#cta-prix').textContent = v.prix;
  $$('.prix-courant').forEach((e) => (e.textContent = v.prix));
  $('#montant').textContent = v.prix;
  $('#recap-nom').textContent = v.nom;
  $('#recap-duree').textContent = v.duree;
  $('#succes-titre').textContent = v.titre;
  $('#succes-texte').textContent = v.texte;
}
$$('.offre').forEach((b) =>
  b.addEventListener('click', () => {
    vibre(8);
    choisirOffre(b.dataset.offre as keyof typeof offres);
  }),
);

// ── La barre du haut ────────────────────────────────────────────
const defile = $('#defile');
const nav = $('#nav');
defile.addEventListener('scroll', () => nav.classList.toggle('est-defilee', defile.scrollTop > 170), { passive: true });

// ── Le tourbillon d'étoiles autour de l'emblème ────────────────
function tourbillon(canvas: HTMLCanvasElement, couleurs: () => string[], dense = 70) {
  const ctx = canvas.getContext('2d')!;
  const dpr = Math.min(devicePixelRatio || 1, 2);
  let w = 0, h = 0;
  const taille = () => {
    w = canvas.clientWidth; h = canvas.clientHeight;
    canvas.width = w * dpr; canvas.height = h * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  };
  taille();
  addEventListener('resize', taille);
  const etoiles = Array.from({ length: dense }, (_, i) => ({
    a: Math.random() * Math.PI * 2,
    r: 0.35 + Math.random() * 0.65,
    v: (0.15 + Math.random() * 0.35) * (i % 2 ? 1 : 1),
    t: 0.6 + Math.random() * 1.6,
    c: i % 4,
  }));
  let actif = true;
  const image = (ms: number) => {
    if (!actif) return;
    ctx.clearRect(0, 0, w, h);
    const cx = w / 2, cy = h * 0.5, rx = w * 0.46, ry = h * 0.36;
    const cs = couleurs();
    for (const e of etoiles) {
      const a = e.a + (calme ? 0 : (ms / 1000) * e.v);
      const x = cx + Math.cos(a) * rx * e.r;
      const y = cy + Math.sin(a) * ry * e.r * 0.55;
      const devant = Math.sin(a) > 0;
      const s = e.t * (devant ? 1.2 : 0.7);
      ctx.globalAlpha = devant ? 0.95 : 0.4;
      ctx.fillStyle = cs[e.c % cs.length];
      ctx.beginPath();
      // Une petite étoile à quatre branches.
      ctx.moveTo(x, y - s * 2);
      ctx.quadraticCurveTo(x, y, x + s * 2, y);
      ctx.quadraticCurveTo(x, y, x, y + s * 2);
      ctx.quadraticCurveTo(x, y, x - s * 2, y);
      ctx.quadraticCurveTo(x, y, x, y - s * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
    requestAnimationFrame(image);
  };
  requestAnimationFrame(image);
  return { arreter: () => (actif = false), relancer: () => { if (!actif) { actif = true; requestAnimationFrame(image); } } };
}
tourbillon($<HTMLCanvasElement>('#etoiles'), () => ['#8E7BFF', '#E151B0', '#FFA932', '#ffffff']);

// ── Les feuilles ────────────────────────────────────────────────
const voile = $('#voile');
const demo = $('#demo');
const paiement = $('#paiement');
function ouvrir(f: HTMLElement) {
  voile.hidden = false;
  requestAnimationFrame(() => {
    voile.classList.add('ouvert');
    f.classList.add('ouverte');
    f.setAttribute('aria-hidden', 'false');
  });
}
function fermer(f: HTMLElement) {
  f.classList.remove('ouverte');
  f.setAttribute('aria-hidden', 'true');
  if (!demo.classList.contains('ouverte') && !paiement.classList.contains('ouverte')) {
    voile.classList.remove('ouvert');
    setTimeout(() => {
      if (!voile.classList.contains('ouvert')) voile.hidden = true;
    }, 300);
  }
}
voile.addEventListener('click', () => {
  fermer(paiement);
  fermer(demo);
});

// ── 2. La présentation : le glissement des téléphones ──────────
const scene = $('#demo-scene');
const pages = $$('.page');
const points = $$('#points i');
const titre = $('#demo-titre');
const long = $('#demo-long');
const texte = $('.demo__texte');
const n = pages.length;
let pos = 0; // position continue (0 = première page)
let cible = 0;
let glisse = false;
let courante = -1;
const deco = $<HTMLCanvasElement>('#deco');
const ctxDeco = tourbillon(deco, () => ['#ffffff', '#ffffff', palette[Math.round(pos)] ?? '#fff'], 46);

function poser() {
  const largeur = scene.clientWidth;
  pages.forEach((p, i) => {
    const d = i - pos; // −1..1 autour de la page courante
    let m = Math.max(-1.5, Math.min(1.5, d));
    m *= Math.abs(m);
    const tel = p.firstElementChild as HTMLElement;
    p.style.transform = `translateX(${d * largeur}px)`;
    p.style.visibility = Math.abs(d) > 1.2 ? 'hidden' : 'visible';
    // Le téléphone s'écarte, tourne et s'enfonce un peu en quittant le
    // centre — la perspective de la présentation de Telegram.
    const haut = tel.classList.contains('tel--haut');
    tel.style.transform = `translateX(${m * 50}px) translateY(${(haut ? 1 : -1) * Math.abs(m) * 24}px) rotateY(${m * -28}deg) scale(${1 - Math.abs(m) * 0.06})`;
  });
  const proche = Math.round(pos);
  points.forEach((e, i) => e.classList.toggle('actif', i === proche));
  // La couleur de la scène suit l'avantage, en fondu.
  const a = Math.floor(Math.max(0, Math.min(n - 1, pos)));
  const b = Math.min(n - 1, a + 1);
  const t = Math.max(0, Math.min(1, pos - a));
  deco.style.background = `linear-gradient(160deg, ${melange(palette[a], palette[b], t)}, #1c1c1e 92%)`;
  if (proche !== courante && !glisse) montrer(proche);
}
function melange(x: string, y: string, t: number) {
  const p = (c: string) => [1, 3, 5].map((k) => parseInt(c.slice(k, k + 2), 16));
  const [a, b] = [p(x), p(y)];
  return `rgb(${a.map((v, i) => Math.round(v + (b[i] - v) * t)).join(',')})`;
}
function montrer(i: number) {
  courante = i;
  titre.textContent = avantages[i].titre;
  long.textContent = avantages[i].long;
  texte.classList.remove('change');
  void texte.offsetWidth;
  texte.classList.add('change');
  // La scène du téléphone courant rejoue depuis le début.
  pages.forEach((p, k) => p.classList.toggle('joue', false));
  void pages[i].offsetWidth;
  pages[i].classList.add('joue');
  vibre(6);
}
let anim = 0;
function vers(i: number) {
  cible = Math.max(0, Math.min(n - 1, i));
  cancelAnimationFrame(anim);
  const pas = () => {
    // Un ressort amorti, image par image.
    pos += (cible - pos) * (calme ? 1 : 0.16);
    if (Math.abs(cible - pos) < 0.002) pos = cible;
    poser();
    if (pos !== cible) anim = requestAnimationFrame(pas);
  };
  anim = requestAnimationFrame(pas);
}
let x0 = 0, p0 = 0, t0 = 0;
scene.addEventListener('pointerdown', (e) => {
  if ((e.target as HTMLElement).closest('button')) return;
  glisse = true;
  x0 = e.clientX; p0 = pos; t0 = performance.now();
  cancelAnimationFrame(anim);
  scene.setPointerCapture(e.pointerId);
});
scene.addEventListener('pointermove', (e) => {
  if (!glisse) return;
  let p = p0 - (e.clientX - x0) / scene.clientWidth;
  // Au-delà des bords, on résiste.
  if (p < 0) p *= 0.35;
  if (p > n - 1) p = n - 1 + (p - n + 1) * 0.35;
  pos = p;
  poser();
});
const lacher = (e: PointerEvent) => {
  if (!glisse) return;
  glisse = false;
  const dx = e.clientX - x0;
  const vitesse = dx / (performance.now() - t0);
  let i = Math.round(pos);
  if (Math.abs(vitesse) > 0.35 && Math.round(pos) === Math.round(p0)) i = Math.round(p0) - Math.sign(vitesse);
  vers(i);
  setTimeout(() => montrer(Math.round(cible)), 0);
};
scene.addEventListener('pointerup', lacher);
scene.addEventListener('pointercancel', lacher);
points.forEach((e, i) => e.addEventListener('click', () => vers(i)));

$$('.avantage').forEach((b) =>
  b.addEventListener('click', () => {
    vibre(8);
    const i = Number(b.dataset.page);
    pos = cible = i;
    courante = -1;
    ouvrir(demo);
    ctxDeco.relancer();
    requestAnimationFrame(() => poser());
  }),
);
$('#demo-fermer').addEventListener('click', () => fermer(demo));

// ── 3. Le paiement (simulé) ─────────────────────────────────────
const etapes = $$('.etape', paiement);
const etape = (nom: string) => etapes.forEach((e) => (e.hidden = e.dataset.etape !== nom));
const numero = $<HTMLInputElement>('#numero');
const payer = $<HTMLButtonElement>('#payer');
function ouvrirPaiement() {
  vibre(10);
  etape('saisie');
  if (demo.classList.contains('ouverte')) fermer(demo);
  ouvrir(paiement);
}
$('#cta').addEventListener('click', ouvrirPaiement);
$$('[data-payer]').forEach((b) => b.addEventListener('click', ouvrirPaiement));
$('#paiement-fermer').addEventListener('click', () => fermer(paiement));
$$('.operateurs button').forEach((b) =>
  b.addEventListener('click', () => {
    vibre(6);
    $$('.operateurs button').forEach((x) => x.setAttribute('aria-checked', String(x === b)));
    $('#code-op').textContent = b.dataset.op === 'mtn' ? '*126#' : '#150#';
  }),
);
numero.addEventListener('input', () => {
  const c = numero.value.replace(/\D/g, '').slice(0, 9);
  numero.value = c.replace(/^(\d{3})(\d{0,2})(\d{0,2})(\d{0,2}).*$/, (_, a, b, d, e) => [a, b, d, e].filter(Boolean).join(' ')) || c;
  payer.disabled = c.length !== 9;
});
payer.addEventListener('click', () => {
  vibre(12);
  etape('attente');
  setTimeout(() => {
    vibre([20, 60, 30]);
    etape('succes');
    bouquet();
  }, 3200);
});
$('#termine').addEventListener('click', () => fermer(paiement));

// Le bouquet : des étoiles qui jaillissent derrière l'emblème.
function bouquet() {
  const c = $<HTMLCanvasElement>('#bouquet');
  const ctx = c.getContext('2d')!;
  const dpr = Math.min(devicePixelRatio || 1, 2);
  const w = c.clientWidth, h = c.clientHeight;
  c.width = w * dpr; c.height = h * dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  const parts = Array.from({ length: calme ? 0 : 90 }, () => {
    const a = Math.random() * Math.PI * 2, v = 2 + Math.random() * 5;
    return { x: w / 2, y: 90, vx: Math.cos(a) * v, vy: Math.sin(a) * v - 2, c: palette[(Math.random() * palette.length) | 0], s: 2 + Math.random() * 3, vie: 1 };
  });
  const image = () => {
    ctx.clearRect(0, 0, w, h);
    let vivantes = 0;
    for (const p of parts) {
      if (p.vie <= 0) continue;
      vivantes++;
      p.x += p.vx; p.y += p.vy; p.vy += 0.12; p.vx *= 0.985; p.vie -= 0.012;
      ctx.globalAlpha = Math.max(0, p.vie);
      ctx.fillStyle = p.c;
      ctx.fillRect(p.x, p.y, p.s, p.s * 1.6);
    }
    if (vivantes) requestAnimationFrame(image);
  };
  requestAnimationFrame(image);
}

choisirOffre('pro');
