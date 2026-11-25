// Le prototype des Gouttes : tout se passe dans la page, rien n'est envoyé.
// Les règles imitent celles du service (droplet-pay) : on ne crédite qu'après
// « confirmation de l'opérateur », un article définitif ne s'achète qu'une
// fois, on ne dépense jamais plus que le solde.

type Produit = { cle: string; famille: string; prix: number; nom: string; court: string; long: string; icone: string; c: string };
type Ligne = { id: string; nature: 'recharge' | 'achat' | 'cadeau'; titre: string; montant: number; date: string; icone?: string; c?: string; op?: 'mtn' | 'orange'; prix?: number; ref: string; pour?: string };

const $ = <T extends HTMLElement = HTMLElement>(s: string, r: ParentNode = document) => r.querySelector(s) as T;
const $$ = <T extends HTMLElement = HTMLElement>(s: string, r: ParentNode = document) => [...r.querySelectorAll(s)] as T[];
const donnees = JSON.parse($('#donnees').textContent!) as { produits: Produit[]; historique: Ligne[]; icones: Record<string, string> };
const produits = new Map(donnees.produits.map((p) => [p.cle, p]));
const fmt = (n: number) => n.toLocaleString('fr-FR');
const uuid = () => crypto.randomUUID();
const goutte = '<svg class="g" aria-hidden="true"><use href="#goutte"/></svg>';

const etat = {
  solde: 35,
  possedes: new Set<string>(['stickers_gerbes']),
  historique: donnees.historique,
  filtre: 'tout',
  pour: null as null | { cle: string; nom: string; initiale: string; c: string },
};

// ── Le solde, et son compteur qui roule ──
const soldeEl = $('#solde');
const navSolde = $('#nav-solde');
function afficherSolde(de: number, a: number) {
  const t0 = performance.now();
  const duree = Math.min(1400, 400 + Math.abs(a - de) * 6);
  const pas = (t: number) => {
    const x = Math.min(1, (t - t0) / duree);
    const v = Math.round(de + (a - de) * (1 - Math.pow(1 - x, 3)));
    soldeEl.textContent = fmt(v);
    navSolde.textContent = fmt(v);
    if (x < 1) requestAnimationFrame(pas);
  };
  requestAnimationFrame(pas);
}
function changerSolde(delta: number) {
  const avant = etat.solde;
  etat.solde += delta;
  afficherSolde(avant, etat.solde);
  if (delta > 0) {
    const e = $('#embleme');
    e.classList.remove('boit');
    void e.offsetWidth;
    e.classList.add('boit');
  }
  majPrix();
}

const defile = $('#defile');
const nav = $('#nav');
defile.addEventListener('scroll', () => nav.classList.toggle('est-defilee', defile.scrollTop > 190), { passive: true });

// ── Les feuilles ──
const voile = $('#voile');
const ouvertes: HTMLElement[] = [];
function ouvrir(f: HTMLElement) {
  voile.hidden = false;
  requestAnimationFrame(() => voile.classList.add('ouvert'));
  f.classList.toggle('au-dessus', ouvertes.length > 0);
  f.setAttribute('aria-hidden', 'false');
  requestAnimationFrame(() => f.classList.add('ouverte'));
  ouvertes.push(f);
}
function fermer(f = ouvertes.at(-1)) {
  if (!f) return;
  f.classList.remove('ouverte');
  f.setAttribute('aria-hidden', 'true');
  ouvertes.splice(ouvertes.indexOf(f), 1);
  if (!ouvertes.length) {
    voile.classList.remove('ouvert');
    setTimeout(() => { if (!ouvertes.length) voile.hidden = true; }, 300);
  }
  f.dispatchEvent(new Event('fermee'));
}
voile.addEventListener('click', () => fermer());
$$('[data-fermer]').forEach((b) => b.addEventListener('click', () => fermer(b.closest('.feuille') as HTMLElement)));
function etape(f: HTMLElement, nom: string) {
  $$('.etape[data-etape]', f).forEach((e) => (e.hidden = e.dataset.etape !== nom));
}

// ── Les segments ──
function segments(groupe: HTMLElement, surChoix: (b: HTMLElement) => void) {
  $$('button', groupe).forEach((b) => b.addEventListener('click', () => {
    $$('button', groupe).forEach((x) => x.setAttribute('aria-selected', String(x === b)));
    surChoix(b);
  }));
}
function montrerRayon(famille: string) {
  $$('#articles li').forEach((li) => (li.hidden = li.dataset.famille !== famille));
  $$('#rayons button').forEach((x) => x.setAttribute('aria-selected', String(x.dataset.famille === famille)));
}
segments($('#rayons'), (b) => montrerRayon(b.dataset.famille!));
segments($('#filtres'), (b) => { etat.filtre = b.dataset.filtre!; dessinerHistorique(); });

function majPrix() {
  $$('[data-prix-de]').forEach((el) => {
    const p = produits.get(el.dataset.prixDe!)!;
    const possede = !etat.pour && etat.possedes.has(p.cle) && p.famille !== 'cadeaux';
    el.classList.toggle('possede', possede);
    el.innerHTML = possede ? 'À vous' : `${goutte}${p.prix}`;
  });
}

// ── L'historique ──
function iconeDe(l: Ligne) {
  if (l.nature === 'recharge') return `<span class="op op--${l.op}">${l.op === 'mtn' ? 'M' : 'O'}</span>`;
  return `<span class="carre" style="--c:${l.c}"><svg viewBox="0 0 24 24">${donnees.icones[l.icone!]}</svg></span>`;
}
function dessinerHistorique(nouveau?: string) {
  const liste = etat.historique.filter((l) => etat.filtre === 'tout' || (etat.filtre === 'recharge' ? l.nature === 'recharge' : l.nature !== 'recharge'));
  $('#historique').innerHTML = liste.map((l) => `
    <li class="${l.id === nouveau ? 'histo__nouveau' : ''}"><button class="ligne" type="button" data-ligne="${l.id}">
      ${iconeDe(l)}
      <span class="ligne__txt"><b>${l.titre}</b><small>${l.pour ? `Offert à ${l.pour} · ` : ''}${l.date}</small></span>
      <span class="histo__montant ${l.montant > 0 ? 'plus' : ''}">${l.montant > 0 ? '+' : '−'}${fmt(Math.abs(l.montant))}${goutte}</span>
    </button></li>`).join('') || '<li><p class="pied">Rien ici pour l’instant.</p></li>';
  $$('#historique [data-ligne]').forEach((b) => b.addEventListener('click', () => ouvrirRecu(b.dataset.ligne!)));
}
function maintenant() {
  return `Aujourd’hui, ${new Date().toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}`;
}

// ── 2. Recharger ──
const recharge = $('#recharge');
let palier = { cle: 'g100', gouttes: 100, prix: 1000 };
let operateur: 'mtn' | 'orange' = 'mtn';
let apresRecharge: null | (() => void) = null;
function choisirPalier(b: HTMLElement) {
  $$('.paliers [role=radio]').forEach((x) => x.setAttribute('aria-checked', String(x === b)));
  palier = { cle: b.dataset.palier!, gouttes: Number(b.dataset.gouttes), prix: Number(b.dataset.prix) };
  $('#continuer-prix').textContent = fmt(palier.prix);
}
$$('.paliers [role=radio]').forEach((b) => b.addEventListener('click', () => choisirPalier(b)));

function ouvrirRecharge(manque = 0) {
  etape(recharge, 'palier');
  const aide = $('#manque-aide');
  aide.hidden = !manque;
  aide.className = 'etape__aide manque';
  aide.textContent = manque ? `Il vous manque ${fmt(manque)} Gouttes.` : '';
  // Le plus petit palier qui couvre le manque, comme BalanceNeededScreen.
  const boutons = $$('.paliers [role=radio]');
  choisirPalier(boutons.find((b) => Number(b.dataset.gouttes) >= manque) ?? boutons.at(-1)!);
  ouvrir(recharge);
}
$('#recharger').addEventListener('click', () => ouvrirRecharge());
$('#continuer').addEventListener('click', () => {
  $('#recap').textContent = `${fmt(palier.gouttes)} Gouttes`;
  $('#montant').textContent = fmt(palier.prix);
  $$('.prix-courant', recharge).forEach((e) => (e.textContent = fmt(palier.prix)));
  etape(recharge, 'paiement');
});
$$('.operateurs [role=radio]').forEach((b) => b.addEventListener('click', () => {
  $$('.operateurs [role=radio]').forEach((x) => x.setAttribute('aria-checked', String(x === b)));
  operateur = b.dataset.op as 'mtn' | 'orange';
}));
const numero = $<HTMLInputElement>('#numero');
const payer = $<HTMLButtonElement>('#payer');
numero.addEventListener('input', () => {
  const ch = numero.value.replace(/\D/g, '').slice(0, 9);
  numero.value = ch.replace(/(\d)(\d{2})?(\d{2})?(\d{2})?(\d{2})?/, (_, a, b, c, d, e) => [a + (b ?? ''), c, d, e].filter(Boolean).join(' '));
  payer.disabled = !/^6\d{8}$/.test(ch);
});
payer.addEventListener('click', () => {
  $('#attente-aide').textContent = `Tapez votre code ${operateur === 'mtn' ? 'MTN MoMo' : 'Orange Money'} dans l'invite qui s'affiche.`;
  etape(recharge, 'attente');
  // Le prototype « reçoit » la confirmation de l'opérateur au bout de 2,6 s.
  setTimeout(() => {
    etape(recharge, 'succes');
    $('#succes-gouttes').textContent = `+${fmt(palier.gouttes)}`;
    pluie($('[data-etape=succes] .pluie', recharge));
    const l: Ligne = { id: uuid(), nature: 'recharge', titre: `Recharge ${operateur === 'mtn' ? 'MTN MoMo' : 'Orange Money'}`, montant: palier.gouttes, date: maintenant(), op: operateur, prix: palier.prix, ref: uuid() };
    etat.historique.unshift(l);
    recharge.addEventListener('fermee', () => {
      changerSolde(palier.gouttes);
      dessinerHistorique(l.id);
      const suite = apresRecharge;
      apresRecharge = null;
      suite?.();
    }, { once: true });
  }, 2600);
});

function pluie(zone: HTMLElement) {
  zone.innerHTML = Array.from({ length: 26 }, () => {
    const s = `left:${Math.random() * 100}%;--d:${1.4 + Math.random() * 1.2}s;--r:${Math.random() * 0.9}s;--rot:${(Math.random() - 0.5) * 70}deg;transform:scale(${0.6 + Math.random() * 0.8})`;
    return `<svg style="${s}"><use href="#goutte"/></svg>`;
  }).join('');
}

// ── 3. Acheter ou offrir ──
const achat = $('#achat');
let courant: Produit | null = null;
function ouvrirAchat(cle: string) {
  const p = produits.get(cle)!;
  courant = p;
  etape(achat, 'resume');
  const ic = $('#achat-icone');
  ic.style.setProperty('--c', p.c);
  ic.innerHTML = `<svg viewBox="0 0 24 24">${donnees.icones[p.icone]}</svg>`;
  $('#achat-nom').textContent = p.nom;
  $('#achat-texte').textContent = p.long;
  $('#achat-pour').textContent = etat.pour ? etat.pour.nom : 'Moi';
  $('#achat-prix').textContent = String(p.prix);
  $('#achat-offrir').hidden = Boolean(etat.pour);

  const bouton = $<HTMLButtonElement>('#acheter');
  const dejaAMoi = !etat.pour && etat.possedes.has(p.cle) && p.famille !== 'cadeaux';
  const manque = p.prix - etat.solde;
  $('#achat-apres').innerHTML = dejaAMoi ? '—' : manque > 0 ? `<span style="color:var(--or)">il manque ${fmt(manque)}</span>` : `${goutte}${fmt(etat.solde - p.prix)}`;
  bouton.disabled = dejaAMoi;
  bouton.dataset.mode = manque > 0 ? 'recharger' : 'acheter';
  $('#acheter-txt').innerHTML = dejaAMoi ? 'Déjà à vous' : manque > 0 ? `Recharger ${fmt(manque)} Gouttes manquantes` : `${etat.pour ? 'Offrir' : 'Acheter'} pour ${goutte.replace('class="g"', 'class="g" style="display:inline-block;vertical-align:-3px"')} ${p.prix}`;
  if (!achat.classList.contains('ouverte')) ouvrir(achat);
}
$$('#articles [data-produit]').forEach((b) => b.addEventListener('click', () => ouvrirAchat(b.dataset.produit!)));

$('#acheter').addEventListener('click', (e) => {
  const p = courant!;
  if ((e.currentTarget as HTMLElement).dataset.mode === 'recharger') {
    // Il manque des Gouttes : on recharge, puis on revient à l'article.
    apresRecharge = () => ouvrirAchat(p.cle);
    fermer(achat);
    setTimeout(() => ouvrirRecharge(p.prix - etat.solde), 350);
    return;
  }
  const pour = etat.pour;
  if (!pour && p.famille !== 'cadeaux') etat.possedes.add(p.cle);
  const l: Ligne = { id: uuid(), nature: pour ? 'cadeau' : 'achat', titre: p.nom, montant: -p.prix, date: maintenant(), icone: p.icone, c: p.c, ref: uuid(), pour: pour?.nom };
  etat.historique.unshift(l);
  etape(achat, 'succes');
  const ic = $('#fait-icone');
  ic.style.setProperty('--c', p.c);
  ic.innerHTML = `<svg viewBox="0 0 24 24">${donnees.icones[p.icone]}</svg>`;
  pluie($('[data-etape=succes] .pluie', achat));
  $('#fait-titre').textContent = pour ? `Offert à ${pour.nom}` : p.famille === 'cadeaux' ? 'Il est à vous' : 'C’est à vous';
  $('#fait-texte').textContent = pour
    ? `${pour.nom} le reçoit tout de suite, et voit que c'est vous.`
    : p.famille === 'cadeaux' ? 'Il s’affiche maintenant sur votre profil.' : 'Sur ce téléphone, et sur tous ceux de votre compte Droplet ID.';
  achat.addEventListener('fermee', () => {
    changerSolde(-p.prix);
    dessinerHistorique(l.id);
    if (pour) annulerPour();
  }, { once: true });
});

// ── Offrir : choisir la personne, puis l'article ──
const contactsF = $('#contacts');
let offrirDepuisAchat = false;
$('#offrir').addEventListener('click', () => { offrirDepuisAchat = false; ouvrir(contactsF); });
$('#achat-offrir').addEventListener('click', () => { offrirDepuisAchat = true; ouvrir(contactsF); });
$$('#contacts [data-contact]').forEach((b) => b.addEventListener('click', () => {
  etat.pour = { cle: b.dataset.contact!, nom: b.dataset.nom!, initiale: b.dataset.initiale!, c: getComputedStyle(b).getPropertyValue('--c') };
  $('#pour').hidden = false;
  $('#pour-nom').textContent = etat.pour.nom;
  const av = $('#pour-avatar');
  av.textContent = etat.pour.initiale;
  av.style.setProperty('--c', etat.pour.c);
  majPrix();
  fermer(contactsF);
  if (offrirDepuisAchat && courant) {
    ouvrirAchat(courant.cle);
  } else {
    montrerRayon('cadeaux');
    // Pas de scrollIntoView : il ferait aussi défiler l'écran du téléphone
    // (overflow: hidden), et les feuilles fermées apparaîtraient en bas.
    defile.scrollTo({ top: $('#pour').offsetTop - 112, behavior: 'smooth' });
  }
}));
function annulerPour() {
  etat.pour = null;
  $('#pour').hidden = true;
  majPrix();
}
$('#pour-annuler').addEventListener('click', annulerPour);

// ── 4. Le reçu ──
const recu = $('#recu');
function ouvrirRecu(id: string) {
  const l = etat.historique.find((x) => x.id === id)!;
  const ic = $('#recu-icone');
  if (l.nature === 'recharge') {
    ic.style.setProperty('--c', l.op === 'mtn' ? '#FFCC00' : '#FF7900');
    ic.innerHTML = `<b style="font-size:30px;color:${l.op === 'mtn' ? '#1A1400' : '#fff'}">${l.op === 'mtn' ? 'M' : 'O'}</b>`;
  } else {
    ic.style.setProperty('--c', l.c!);
    ic.innerHTML = `<svg viewBox="0 0 24 24">${donnees.icones[l.icone!]}</svg>`;
  }
  const m = $('#recu-montant');
  m.className = `recu__montant ${l.montant > 0 ? 'plus' : ''}`;
  m.textContent = `${l.montant > 0 ? '+' : '−'}${fmt(Math.abs(l.montant))} Gouttes`;
  $('#recu-titre').textContent = l.titre;
  const lignes: [string, string][] = [
    ['Date', l.date],
    ...(l.nature === 'recharge' ? [['Payé', `${fmt(l.prix!)} F`], ['Opérateur', l.op === 'mtn' ? 'MTN MoMo (direct)' : 'Orange Money (via Fapshi)']] as [string, string][] : []),
    ...(l.pour ? [['Offert à', l.pour]] as [string, string][] : []),
    ['État', l.nature === 'recharge' ? 'Confirmé par l’opérateur' : 'Payé'],
    ['Opération', `<span class="mono">${l.ref.slice(0, 8)}…${l.ref.slice(-4)}</span>`],
  ];
  $('#recu-lignes').innerHTML = lignes.map(([k, v]) => `<li><span>${k}</span><b>${v}</b></li>`).join('');
  ouvrir(recu);
}

// ── 5. Comment ça marche ──
const explication = $('#explication');
$('#info').addEventListener('click', () => ouvrir(explication));
$('#info-bas').addEventListener('click', () => ouvrir(explication));

dessinerHistorique();
majPrix();
