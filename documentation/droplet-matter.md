# Droplet Matter — spécification de la matière

Implémentation de référence : `shaders/lib/matter.glsl`, fonction `dropletMatter`.

## Modèle

Pour chaque pixel à l'intérieur d'une forme, on connaît sa distance signée au bord `d` (négative dedans, en pixels) et la normale sortante `n`. Tout le comportement en découle.

| Propriété | Règle | Paramètre |
| --- | --- | --- |
| Zone de lentille | `e = clamp(1 + d / rim, 0, 1)` : 0 au cœur, 1 au bord | `rim`, 28 à 52 px selon la taille |
| Réfraction | déviation `−n · e⁴ · refr` : nulle au cœur, maximale au bord | `refr`, 16 à 34 px |
| Dispersion | rouge dévié de `1 + disp`, bleu de `1 − disp` : séparation visible seulement au bord | `disp`, 0 à 0,6 |
| Dépoli | moyenne sur un disque de Vogel tourné au hasard par pixel : grain fin, pas d'images doublées | `frost`, 0 à 20 px |
| Teinte de surface | mélange vers un blanc laiteux (clair) ou une encre (sombre) | `tint`, 0 à 1 |
| Fresnel | `e⁵` ajouté en lumière : le bord renvoie plus que le centre | fixe, selon le thème |
| Bord clair | en thème clair, un trait légèrement plus sombre dessine la goutte | fixe |
| Reflet | `max(n · L, 0)¹⁸` près du bord, `L` vers la lumière | la lumière suit le doigt |
| Liseré spectral | 1 à 3 px au bord, teinte selon l'angle de la normale | proportionnel à `disp` |
| Ombre | ombre portée douce, décalée vers le bas, hors de la forme | `dropletShadow` |

## Ce que la matière ne fait pas

- **Ce n'est pas une simulation physique.** Il n'y a ni indice de réfraction, ni loi de Snell, ni lancer de rayons : la déviation est une approximation artistique, choisie pour être lisible et peu coûteuse.
- **Elle ne réfracte que ce qu'on lui donne.** Dans le Lab, l'arrière-plan est une image (expériences 01 et 04) ou l'atmosphère Aether calculée dans le même shader (05 et 06). Réfracter de vrais widgets Flutter demande de capturer la scène dans une texture : voir `architecture.md`.

## Niveaux de qualité

| Niveau | Shader | Échantillons de fond par pixel | Ce qui change |
| --- | --- | --- | --- |
| LOW | non | 0 | Repli dessiné au canevas : disque translucide, liseré, ombre |
| BALANCED | oui | 1 | Réfraction seule, pas de dispersion ni de dépoli |
| HIGH | oui | 3 + 6 | Dispersion, dépoli à 6 échantillons |
| ULTRA | oui | 3 + 12 | Dépoli à 12 échantillons |

Le Lab baisse la qualité d'un cran quand plus d'un quart des images dépassent 16,7 ms pendant deux secondes (option « Qualité automatique »).

## Règles d'usage

- Une seule surface de matière par écran au repos ; jamais de matière sur de la matière.
- Jamais de texte courant derrière une zone de lentille : le texte posé sur la matière doit être au cœur, là où rien n'est dévié.
- La matière est réservée à la couche de navigation et aux moments forts (approbation Droplet ID, envoi Drop, signature de marque).
- Avec « Réduire les animations », la matière reste mais ne bouge plus ; avec « Réduire la transparence » (à brancher dans les apps), elle passe en LOW.
