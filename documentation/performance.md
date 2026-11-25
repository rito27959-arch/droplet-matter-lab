# Performances

## Ce qui a été mesuré

Rien sur un vrai téléphone pour l'instant. Les captures de la CI viennent d'un Chromium sans GPU (rendu logiciel SwiftShader) : elles valident l'image, pas la fluidité.

## Comment mesurer sur un téléphone

1. Installer `droplet-matter-lab.apk` depuis la branche `captures`.
2. Ouvrir une expérience : le panneau du bas affiche la durée moyenne des images, les images par seconde estimées et la part d'images hors budget (16,7 ms). Ces chiffres viennent des durées réelles rapportées par le moteur (`FrameTiming`).
3. Désactiver « Qualité automatique », puis comparer BALANCED, HIGH et ULTRA sur chaque expérience.
4. Pour une mesure fine : `flutter run --profile` et l'outil Performance de DevTools.

## Coût attendu, par construction

| Expérience | Échantillons de fond par pixel (ULTRA) | Bruit fractal par pixel | Poids relatif |
| --- | --- | --- | --- |
| 01 Surface | 1 hors panneau ; 15 dans le panneau | 0 | moyen |
| 02 Morph | 0 | 16 octaves (Aether : 3 nappes et les rais) | moyen |
| 03 Aether | 0 | 16 octaves | moyen |
| 04 Morph prismatique | 1 hors forme ; 15 dans la forme | 0 | moyen |
| 05 Interactif | Aether recalculé 15 fois dans la forme | 15 × 16 octaves | **lourd** |
| 06 Signature | Aether recalculé 15 fois dans la forme | 15 × 16 octaves | **lourd** |
| 07 Pluie sur verre | 20 lectures de carte + 2 à 5 du fond | 0 | moyen ; plus le coût processeur de la simulation (≤ 260 gouttes) et de trois petites images par seconde × 60 |
| 08 Barre liquide | 1 hors barre ; 6 dans la barre, 12 sous la lentille | 0 | léger |

Les expériences 05 et 06 recalculent l'atmosphère pour chaque échantillon réfracté : c'est le point faible connu. La correction prévue : rendre l'Aether une fois par image dans une texture à demi-résolution, puis la réfracter comme une image. Coût divisé par environ quinze à l'intérieur de la forme.

## Garde-fous en place

- Niveaux LOW à ULTRA ; LOW n'exécute aucun shader.
- Baisse automatique d'un niveau quand plus d'un quart des images dépassent le budget pendant deux secondes.
- Shaders compilés au démarrage, jamais pendant une animation.
- Pas de sous-pas illimités : les ressorts intègrent au plus 0,1 s par image.
- Animations coupées quand l'utilisateur les a réduites.

## À mesurer ensuite

Images par seconde, température et consommation sur deux appareils au moins : un Android 13+ récent et un Android d'entrée de gamme. Les budgets cibles proposés : 60 i/s en HIGH sur le premier, 60 i/s en BALANCED sur le second.
