// Capture chaque expérience dans Chromium (rendu WebGL logiciel), à temps figé.
// Ces images servent à vérifier le rendu, pas les performances : un navigateur
// sans GPU ne dit rien de la fluidité sur un téléphone.
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';

const base = 'http://127.0.0.1:8080/';
const out = 'out/captures';
mkdirSync(out, { recursive: true });

const shots = [
  { name: '00-accueil', query: 'q=ultra' },
  { name: '01-surface', query: 'e=1&q=ultra&t=12' },
  { name: '02-morph', query: 'e=2&q=ultra&t=12&cycle=2.2' },
  { name: '03-aether', query: 'e=3&q=ultra&t=12' },
  { name: '04-morph-prismatique', query: 'e=4&q=ultra&t=12&cycle=3.3' },
  { name: '05-interactive', query: 'e=5&q=ultra&t=12' },
  { name: '06-signature', query: 'e=6&q=ultra&t=12&cycle=2.15' },
  { name: '06-signature-balanced', query: 'e=6&q=balanced&t=12&cycle=2.15' },
  { name: '01-surface-low', query: 'e=1&q=low&t=12' },
  { name: '07-pluie', query: 'e=7&q=ultra&t=12', wipe: true },
  { name: '08-barre-liquide', query: 'e=8&q=ultra&t=12', drag: true },
];

const browser = await chromium.launch({
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
let failures = 0;
for (const theme of ['dark', 'light']) {
  for (const s of shots) {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto(`${base}?${s.query}&theme=${theme}`, { waitUntil: 'networkidle' });
    await page.waitForSelector('flt-glass-pane, flutter-view', { timeout: 60000 }).catch(() => {});
    await page.waitForTimeout(6000);
    if (s.wipe) {
      // Un doigt essuie la buée en zigzag.
      await page.mouse.move(60, 330);
      await page.mouse.down();
      for (let i = 0; i <= 30; i++) await page.mouse.move(60 + i * 9, 330 + Math.sin(i / 3) * 26, { steps: 2 });
      await page.mouse.up();
      await page.waitForTimeout(1200);
    }
    if (s.drag) {
      // La lentille est tenue entre deux onglets : elle se soulève et s'étire.
      await page.mouse.move(80, 718);
      await page.mouse.down();
      await page.mouse.move(170, 718, { steps: 12 });
      await page.waitForTimeout(250);
    }
    const file = `${out}/${s.name}-${theme === 'dark' ? 'sombre' : 'clair'}.png`;
    await page.screenshot({ path: file });
    if (s.drag) await page.mouse.up();
    console.log(`${file}${errors.length ? '  ERREURS : ' + errors.join(' | ').slice(0, 800) : ''}`);
    if (errors.length) failures++;
    await page.close();
  }
}
await browser.close();
console.log(failures ? `${failures} capture(s) avec erreurs console` : 'Aucune erreur console');
