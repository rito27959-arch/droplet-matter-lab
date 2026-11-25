# Droplet Matter Lab

Les bibliothèques visuelles de Droplet, et l'application qui sert à les essayer. Le dépôt est organisé comme un monorepo : trois bibliothèques Flutter dans `packages/`, une application d'essai dans `sample/`.

| Bibliothèque | Contenu |
| --- | --- |
| `droplet_core` | Niveaux de qualité (LOW à ULTRA), ressorts, jetons de mouvement, mesure des images, saisie du pointeur, polices Commissioner et Martian Mono |
| `droplet_glass` | Shaders et rendu : Droplet Matter, verre v2 à profil physique, eau sur vitre (simulation et cartes), arrière-plans, géométrie, lumière |
| `droplet_ui` | Composants prêts à l'emploi : `WaterGlass` (de l'eau qui glisse sur l'écran) et `LiquidTabBar` (barre d'onglets en verre liquide) |

## Les expériences

| # | Expérience | Ce qu'elle teste |
| --- | --- | --- |
| 01 | Surface prismatique | Droplet Matter posée sur un contenu réel : réfraction des bords, dispersion, dépoli, opacité |
| 02 | Objet en métamorphose | Sphère, pavé, goutte, grappe : interpolation de distances signées |
| 03 | Atmosphère Aether | Lumière diffuse, rais, brume en parallaxe |
| 04 | Morph prismatique | La forme vivante faite de matière |
| 05 | Matière interactive | Ressorts : la goutte suit le doigt et s'étire avec le geste |
| 06 | Signature | Tout ensemble, avec le nom « Droplet » |
| 07 | Pluie sur verre | Gouttes qui glissent par à-coups, traînées, fusion, buée essuyée au doigt qui revient |
| 08 | Barre liquide | Verre à profil physique, lentille de sélection qu'on fait glisser, union douce avec la barre |

Sur le web, l'adresse ouvre une expérience précise : `?e=7` (pluie), `?e=8` (barre), avec `&theme=light` et `&q=balanced|high|ultra`.

## Utiliser un composant

```dart
import 'package:droplet_glass/droplet_glass.dart';
import 'package:droplet_ui/droplet_ui.dart';

final backdrop = await Backdrop.fromAsset('assets/images/fond.jpg');

WaterGlass(backdrop: backdrop, fog: 1, rain: const RainSettings(dropsPerSecond: 9));
```

## Comment l'eau est rendue

1. **Simulation** (`droplet_glass/lib/src/water/rain_simulation.dart`, Dart pur) : une petite goutte adhère ; au-delà d'un rayon, elle glisse avec un frottement statique puis dynamique, laisse des gouttelettes et perd du volume. Deux gouttes qui se touchent fusionnent en conservant le volume, r = ∛(r₁³ + r₂³). Le doigt ramasse l'eau et la repousse en perles sur le bord du sillon.
2. **Cartes** (`water_maps.dart`) : à chaque image, le GPU dessine à demi-résolution une carte de hauteur (calottes d'eau, plus la condensation) et une carte « essuyée » qui s'éteint lentement : la buée revient.
3. **Shader** (`shaders/src/water_glass.frag`) : la normale vient de la pente de la carte de hauteur ; le fond est réfracté par la loi de Snell (eau, n ≈ 1,333, un indice par canal pour la dispersion), d'où l'image renversée dans chaque goutte. S'y ajoutent Fresnel (F₀ = 0,02), bord sombre où la pente est forte, caustique côté opposé à la lumière, reflet, ombre de contact. Hors de l'eau, la vitre est embuée : fond flou, voile, grain de condensation.

Le verre v2 (`shaders/lib/glass.glsl`) suit la méthode décrite publiquement par kube.io : profil de bord convexe y = (1 − (1 − x)⁴)^¼, normale tirée de la pente, réfraction de Snell (n = 1,5). Les principes d'Apple présentés à la WWDC 2025 (le verre courbe la lumière au lieu de la diffuser, il est réservé à la navigation, jamais de verre sur du verre) guident son usage. Aucune équation extraite des frameworks d'Apple n'est reprise.

## Lancer

```sh
cd sample && flutter run          # Android, iOS ou web
python3 tool/build_shaders.py     # après toute modification de packages/droplet_glass/shaders/src ou lib
```

Chaque poussée sur `main` est compilée par GitHub Actions : analyse et tests des trois bibliothèques et de l'application, web, APK, captures dans un navigateur. Résultats sur la branche [`captures`](../../tree/captures). La version web est publiée par Vercel (`vercel.json`, `vercel-build.sh`).

## Ce qui n'est pas encore vérifié

- Rien n'a été mesuré sur un vrai téléphone : fluidité, chauffe et batterie sont inconnues.
- Les captures viennent d'un navigateur sans GPU (rendu logiciel) : elles valident l'image, pas la vitesse.
- La barre liquide réfracte une image qu'elle fait défiler, pas encore l'arbre de widgets réel.

## Organisation

| Dossier | Rôle |
| --- | --- |
| `packages/droplet_core` | Fondations partagées |
| `packages/droplet_glass/shaders/src`, `…/shaders/lib` | Sources GLSL ; `…/shaders/*.frag` : shaders autonomes générés |
| `packages/droplet_glass/lib` | Rendu, matière, eau, géométrie, lumière |
| `packages/droplet_ui/lib` | Composants |
| `sample/` | Application d'essai : les huit expériences |
| `tool/` | Assemblage des shaders, captures |
| `documentation/` | Manifeste, spécification, architecture, performances, plateformes, feuille de route |

## Licences

Code : tous droits réservés, Droplet. Polices Commissioner et Martian Mono : SIL Open Font License 1.1 (textes dans `packages/droplet_core/assets/fonts`).
