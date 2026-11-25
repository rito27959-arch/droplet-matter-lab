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
    const file = `${out}/${s.name}-${theme === 'dark' ? 'sombre' : 'clair'}.png`;
    await page.screenshot({ path: file });
    console.log(`${file}${errors.length ? '  ERREURS : ' + errors.join(' | ').slice(0, 800) : ''}`);
    if (errors.length) failures++;
    await page.close();
  }
}
await browser.close();
console.log(failures ? `${failures} capture(s) avec erreurs console` : 'Aucune erreur console');
