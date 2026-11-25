// Les contrôles en verre liquide : comportement, clavier, accessibilité.
import { Spring, animate, lens, reducedMotion } from './liquid';

const clamp = (v: number, a: number, b: number) => Math.min(Math.max(v, a), b);

/* ---------- Interrupteur : le bouton devient une goutte de verre quand on le tient ---------- */
export function initSwitch(el: HTMLButtonElement) {
  const knob = el.querySelector<HTMLElement>('.lgs-pouce')!;
  const track = el.querySelector<HTMLElement>('.lgs-piste')!;
  lens(knob, { kind: 'loupe', bezel: 9, thickness: 10 });
  const travel = () => track.clientWidth - knob.offsetWidth - 4;
  const on = () => el.getAttribute('aria-checked') === 'true';
  const pos = new Spring(on() ? 1 : 0, 320, 0.62);
  const grow = new Spring(0, 420, 0.6);
  let dragging = false, moved = false, startX = 0, startPos = 0;
  const render = () => {
    const stretch = 1 + grow.x * 0.42 + Math.min(Math.abs(pos.v) * 0.04, 0.25);
    knob.style.transform = `translateX(${pos.x * travel()}px) scale(${stretch}, ${1 + grow.x * 0.28})`;
    knob.classList.toggle('verre-actif', grow.x > 0.15);
    track.style.setProperty('--rempli', String(clamp(pos.x, 0, 1)));
  };
  const run = () =>
    animate((dt) => {
      pos.step(dt);
      grow.step(dt);
      render();
      return dragging || !pos.resting || !grow.resting;
    });
  el.addEventListener('pointerdown', (e) => {
    dragging = true;
    moved = false;
    startX = e.clientX;
    startPos = pos.x;
    grow.target = 1;
    el.setPointerCapture(e.pointerId);
    run();
  });
  el.addEventListener('pointermove', (e) => {
    if (!dragging) return;
    const dx = e.clientX - startX;
    if (Math.abs(dx) > 3) moved = true;
    pos.target = clamp(startPos + dx / travel(), -0.08, 1.08);
  });
  const end = () => {
    if (!dragging) return;
    dragging = false;
    grow.target = 0;
    const next = moved ? pos.target > 0.5 : !on();
    el.setAttribute('aria-checked', String(next));
    pos.target = next ? 1 : 0;
    el.dispatchEvent(new Event('change', { bubbles: true }));
    run();
  };
  el.addEventListener('pointerup', end);
  el.addEventListener('pointercancel', end);
  el.addEventListener('keydown', (e) => {
    if (e.key !== ' ' && e.key !== 'Enter') return;
    e.preventDefault();
    el.setAttribute('aria-checked', String(!on()));
    pos.target = on() ? 1 : 0;
    el.dispatchEvent(new Event('change', { bubbles: true }));
    run();
  });
  render();
}

/* ---------- Curseur : le bouton se change en loupe pendant le geste ---------- */
export function initSlider(el: HTMLElement, onInput?: (v: number) => void) {
  const knob = el.querySelector<HTMLElement>('.lgc-pouce')!;
  const fill = el.querySelector<HTMLElement>('.lgc-rempli')!;
  lens(knob, { kind: 'loupe', bezel: 10, thickness: 12 });
  const min = Number(el.getAttribute('aria-valuemin') ?? 0), max = Number(el.getAttribute('aria-valuemax') ?? 100);
  let value = Number(el.getAttribute('aria-valuenow') ?? 50);
  const pos = new Spring((value - min) / (max - min), 520, 0.8);
  const grow = new Spring(0, 420, 0.6);
  let dragging = false;
  const set = (t: number, emit = true) => {
    t = clamp(t, 0, 1);
    value = Math.round(min + t * (max - min));
    el.setAttribute('aria-valuenow', String(value));
    el.setAttribute('aria-valuetext', el.dataset.unit ? `${value} ${el.dataset.unit}` : String(value));
    pos.target = t;
    if (emit) onInput?.(value);
  };
  const render = () => {
    const w = el.clientWidth - knob.offsetWidth;
    knob.style.transform = `translateX(${pos.x * w}px) scale(${1 + grow.x * 0.55 + Math.min(Math.abs(pos.v) * 0.03, 0.2)}, ${1 + grow.x * 0.35})`;
    knob.classList.toggle('verre-actif', grow.x > 0.15);
    fill.style.width = `${pos.x * w + knob.offsetWidth / 2}px`;
  };
  const run = () =>
    animate((dt) => {
      pos.step(dt);
      grow.step(dt);
      render();
      return dragging || !pos.resting || !grow.resting;
    });
  const fromEvent = (e: PointerEvent) => {
    const r = el.getBoundingClientRect();
    return (e.clientX - r.left - knob.offsetWidth / 2) / (r.width - knob.offsetWidth);
  };
  el.addEventListener('pointerdown', (e) => {
    dragging = true;
    grow.target = 1;
    el.setPointerCapture(e.pointerId);
    set(fromEvent(e));
    run();
  });
  el.addEventListener('pointermove', (e) => dragging && set(fromEvent(e)));
  const end = () => {
    dragging = false;
    grow.target = 0;
    run();
  };
  el.addEventListener('pointerup', end);
  el.addEventListener('pointercancel', end);
  el.addEventListener('keydown', (e) => {
    const step = e.shiftKey ? 0.1 : 0.02;
    const t = (value - min) / (max - min);
    if (e.key === 'ArrowRight' || e.key === 'ArrowUp') set(t + step);
    else if (e.key === 'ArrowLeft' || e.key === 'ArrowDown') set(t - step);
    else if (e.key === 'Home') set(0);
    else if (e.key === 'End') set(1);
    else return;
    e.preventDefault();
    run();
  });
  set(pos.x, false);
  requestAnimationFrame(render);
}

/* ---------- Sélection liquide : une lentille qui glisse et s'étire (segmenté, onglets) ---------- */
export function initLiquidSelect(group: HTMLElement, items: HTMLElement[], lensEl: HTMLElement, onSelect?: (i: number) => void, attr = 'aria-checked') {
  lens(lensEl, { kind: 'loupe' });
  let index = Math.max(0, items.findIndex((b) => b.getAttribute(attr) === 'true' || b.getAttribute(attr) === 'page'));
  const x = new Spring(0, 300, 0.7);
  const w = new Spring(0, 300, 0.8);
  const grow = new Spring(0, 420, 0.6);
  let dragging = false, first = true, dragStart = 0, dragOrigin = 0;
  const geo = (i: number) => ({ left: items[i].offsetLeft, width: items[i].offsetWidth });
  const render = () => {
    const sx = 1 + Math.min(Math.abs(x.v) / 2600, 0.3) + grow.x * 0.12;
    const sy = 1 / Math.sqrt(sx) + grow.x * 0.16;
    lensEl.style.width = `${w.x}px`;
    lensEl.style.transform = `translateX(${x.x}px) scale(${sx}, ${sy})`;
    lensEl.classList.toggle('verre-actif', grow.x > 0.15 || Math.abs(x.v) > 60);
  };
  const run = () =>
    animate((dt) => {
      x.step(dt);
      w.step(dt);
      grow.step(dt);
      render();
      return dragging || !x.resting || !w.resting || !grow.resting;
    });
  const select = (i: number, focus = false) => {
    index = i;
    items.forEach((b, j) => {
      if (attr === 'aria-current') j === i ? b.setAttribute('aria-current', 'page') : b.removeAttribute('aria-current');
      else b.setAttribute(attr, String(i === j));
      b.tabIndex = i === j ? 0 : -1;
    });
    const g = geo(i);
    x.target = g.left;
    w.target = g.width;
    if (first || reducedMotion()) {
      x.x = g.left;
      w.x = g.width;
      first = false;
    }
    if (focus) items[i].focus();
    onSelect?.(i);
    run();
  };
  items.forEach((b, i) => {
    b.addEventListener('click', () => select(i));
    b.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowRight') select((i + 1) % items.length, true);
      else if (e.key === 'ArrowLeft') select((i - 1 + items.length) % items.length, true);
    });
  });
  // On peut aussi attraper la lentille et la faire glisser.
  group.addEventListener('pointerdown', (e) => {
    dragging = true;
    dragStart = e.clientX;
    dragOrigin = x.x;
    grow.target = 1;
    run();
  });
  addEventListener('pointermove', (e) => {
    if (!dragging) return;
    const dx = e.clientX - dragStart;
    if (Math.abs(dx) < 4) return;
    const maxX = group.clientWidth - w.x;
    x.target = clamp(dragOrigin + dx, 0, maxX);
  });
  addEventListener('pointerup', () => {
    if (!dragging) return;
    dragging = false;
    grow.target = 0;
    const centre = x.target + w.x / 2;
    let best = index, bd = Infinity;
    items.forEach((b, i) => {
      const d = Math.abs(b.offsetLeft + b.offsetWidth / 2 - centre);
      if (d < bd) (bd = d), (best = i);
    });
    select(best);
  });
  addEventListener('resize', () => select(index));
  requestAnimationFrame(() => select(index));
  return { select, get index() { return index; } };
}

/* ---------- Pas à pas ---------- */
export function initStepper(el: HTMLElement) {
  const out = el.querySelector<HTMLOutputElement>('output')!;
  const [minus, plus] = el.querySelectorAll<HTMLButtonElement>('button');
  const min = Number(el.dataset.min ?? 0), max = Number(el.dataset.max ?? 10);
  let v = Number(out.value);
  const set = (n: number) => {
    v = clamp(n, min, max);
    out.value = String(v);
    minus.disabled = v <= min;
    plus.disabled = v >= max;
    out.animate?.([{ transform: 'scale(1.25)' }, { transform: 'scale(1)' }], { duration: 260, easing: 'cubic-bezier(0.34,1.36,0.64,1)' });
  };
  minus.addEventListener('click', () => set(v - 1));
  plus.addEventListener('click', () => set(v + 1));
  set(v);
}

/* ---------- Le verre qui naît du bouton : menus, popovers, feuilles d'action ---------- */
export function initMorph(trigger: HTMLElement, panel: HTMLElement, opts: { place?: 'dessous' | 'dessus'; align?: 'debut' | 'fin' } = {}) {
  const p = new Spring(0, 300, 0.78);
  let open = false;
  const container = panel.offsetParent as HTMLElement | null;
  lens(panel);
  const geometry = () => {
    const host = (panel.offsetParent as HTMLElement) ?? document.body;
    const hr = host.getBoundingClientRect();
    const tr = trigger.getBoundingClientRect();
    panel.style.visibility = 'hidden';
    panel.style.transform = 'none';
    panel.style.width = '';
    panel.style.height = '';
    const pw = panel.offsetWidth, ph = panel.offsetHeight;
    panel.style.visibility = '';
    const from = { x: tr.left - hr.left, y: tr.top - hr.top, w: tr.width, h: tr.height };
    let x = opts.align === 'fin' ? from.x + from.w - pw : from.x;
    x = clamp(x, 8, hr.width - pw - 8);
    const y = opts.place === 'dessus' ? from.y - ph - 10 : from.y + from.h + 10;
    return { from, to: { x, y, w: pw, h: ph } };
  };
  let g = geometry();
  const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
  const render = () => {
    const t = clamp(p.x, 0, 1.08);
    const k = Math.max(t, 0);
    panel.style.left = `${lerp(g.from.x, g.to.x, k)}px`;
    panel.style.top = `${lerp(g.from.y, g.to.y, k)}px`;
    panel.style.width = `${lerp(g.from.w, g.to.w, k)}px`;
    panel.style.height = `${lerp(g.from.h, g.to.h, k)}px`;
    panel.style.borderRadius = `${lerp(g.from.h / 2, 26, Math.min(k * 1.6, 1))}px`;
    panel.style.setProperty('--contenu', String(clamp((t - 0.45) * 2.2, 0, 1)));
    panel.style.opacity = String(clamp(t * 6, 0, 1));
    panel.hidden = t < 0.01 && !open;
    trigger.style.opacity = String(clamp(1 - t * 3, 0, 1));
  };
  const set = (o: boolean) => {
    if (o === open) return;
    open = o;
    trigger.setAttribute('aria-expanded', String(o));
    if (o) {
      panel.hidden = false;
      g = geometry();
    }
    p.target = o ? 1 : 0;
    if (reducedMotion()) p.x = p.target;
    animate((dt) => {
      p.step(dt);
      render();
      return !p.resting;
    });
    if (o) requestAnimationFrame(() => panel.querySelector<HTMLElement>('[role=menuitem], button, a, input')?.focus());
    else trigger.focus();
  };
  trigger.setAttribute('aria-expanded', 'false');
  trigger.addEventListener('click', (e) => {
    e.stopPropagation();
    set(!open);
  });
  panel.addEventListener('click', (e) => {
    if ((e.target as HTMLElement).closest('[role=menuitem], [data-ferme]')) set(false);
    e.stopPropagation();
  });
  document.addEventListener('click', () => set(false));
  document.addEventListener('keydown', (e) => {
    if (!open) return;
    if (e.key === 'Escape') set(false);
    const items = [...panel.querySelectorAll<HTMLElement>('[role=menuitem]')];
    const i = items.indexOf(document.activeElement as HTMLElement);
    if (e.key === 'ArrowDown') items[(i + 1) % items.length]?.focus();
    if (e.key === 'ArrowUp') items[(i - 1 + items.length) % items.length]?.focus();
  });
  void container;
  panel.hidden = true;
  return { set };
}
