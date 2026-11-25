# Architecture de rendu

## Trois bibliothèques, une application d'essai

| Paquet | Dépend de | Contenu |
| --- | --- | --- |
| `packages/droplet_core` | Flutter | Qualité, ressorts, jetons de mouvement, mesure des images, pointeur, polices |
| `packages/droplet_glass` | `droplet_core` | Shaders, rendu, matière, verre v2, eau (simulation et cartes), géométrie, lumière |
| `packages/droplet_ui` | `droplet_core`, `droplet_glass` | Composants : `WaterGlass`, `LiquidTabBar` |
| `sample/` | les trois | Application d'essai : huit expériences, réglages, mesure |

Les chemins ci-dessous sont relatifs à `packages/droplet_glass` sauf mention contraire. Les shaders d'un paquet se chargent avec le préfixe `packages/droplet_glass/shaders/…`.

## Les quatre sous-systèmes

| Sous-système | Code | Rôle |
| --- | --- | --- |
| Droplet Light | `shaders/lib/aether.glsl`, `lib/lighting/light_follower.dart` | Lumière diffuse, rais, reflets ; la lumière suit le doigt avec un ressort lent |
| Droplet Geometry | `shaders/lib/common.glsl`, `shaders/lib/morph.glsl`, `lib/geometry/` | Distances signées, union douce, cycle des formes |
| Droplet Matter | `shaders/lib/matter.glsl`, `lib/materials/` | La matière : réfraction des bords, dispersion, dépoli, liseré |
| Droplet Motion | `droplet_core/lib/src/motion/` | Ressorts 1D et 2D, jetons de durée et de courbe |

La logique de shader est séparée de l'interface : `sample/lib/experiments/*` ne contient que des paramètres et des uniformes, ou délègue à un composant de `droplet_ui`.

## L'eau

| Étape | Code | Où elle tourne |
| --- | --- | --- |
| Simulation des gouttes | `lib/src/water/rain_simulation.dart` | Processeur, Dart pur, testée |
| Cartes de hauteur et de buée | `lib/src/water/water_maps.dart` | GPU, `Picture.toImageSync`, demi-résolution |
| Optique | `shaders/src/water_glass.frag` | GPU, un passage plein écran |

La carte de hauteur est en 8 bits : le shader la lit avec une interpolation bilinéaire faite à la main (le filtrage des textures n'est pas garanti identique sur Impeller, Skia et le web) et la lisse sur une croix avant d'en tirer la pente.

## Le verre v2

`shaders/lib/glass.glsl` : profil de bord convexe y = (1 − (1 − x)⁴)^¼, normale tirée de la pente, réfraction de Snell (n = 1,5 ; trois indices proches en HIGH et ULTRA pour la dispersion), remplissage flou précalculé (`Backdrop.blurred`) au lieu de multiplier les échantillons, Fresnel, liseré spéculaire. Méthode publique de kube.io ; aucune équation reprise des frameworks d'Apple.

## Chaîne d'un shader

1. Les sources vivent dans `packages/droplet_glass/shaders/src/*.frag` et incluent `shaders/lib/*.glsl`.
2. `tool/build_shaders.py` produit des fichiers autonomes `shaders/*.frag`, car le compilateur de shaders de Flutter ne garantit pas les inclusions relatives. La CI échoue si un fichier généré n'est pas à jour.
3. Flutter compile ces fichiers au build (`flutter: shaders:` dans `pubspec.yaml`) ; l'app les charge une fois au démarrage (`ShaderLibrary.warmUp`), jamais pendant une animation.
4. Chaque image, `UniformWriter` renseigne les uniformes dans l'ordre de déclaration. Un test vérifie que le nombre de flottants déclarés par chaque shader correspond à ce que l'app écrit.
5. Tout uniforme de l'en-tête est utilisé dans chaque shader : un uniforme inutilisé pourrait être retiré par le compilateur et décaler les index.

## Par plateforme

| Plateforme | Technique | État dans le Lab |
| --- | --- | --- |
| Flutter (Android, iOS, web) | GLSL compilé par Flutter, `FragmentProgram`, `CustomPainter` | Implémenté |
| Android natif (Droplet ID) | AGSL avec `RuntimeShader`, disponible à partir d'Android 13 | À porter ; les fonctions GLSL se traduisent presque ligne à ligne |
| iOS natif | Metal Shading Language, via les modificateurs de shader de SwiftUI | Pas avant qu'une app iOS native existe |
| Sites web | WebGL 2 (Three.js ou OGL), même GLSL que le banc d'essai | Banc d'essai local uniquement |

## Réfracter de vrais widgets

Dans le Lab, la matière réfracte une image ou un fond calculé. Pour l'appliquer à l'interface réelle d'une app, il faut lui donner ce qui se trouve derrière elle :

- **Barre de navigation, feuilles** : capturer le contenu sous la barre dans une texture à basse résolution (`RepaintBoundary.toImage` à chaque image est trop lent ; préférer un `ImageFilter.shader` sur `BackdropFilter`, disponible avec Impeller dans les versions récentes de Flutter, à vérifier sur la version retenue).
- **Moments de marque** : fond calculé dans le shader, comme les expériences 05 et 06 ; aucun coût de capture.

C'est la première question technique à trancher avant l'intégration dans Droplet ID et Messenger.
