# Droplet Matter Lab

Laboratoire de la matière visuelle **Prismatic Aether** de Droplet : six expériences Flutter qui mettent au point la lumière, la géométrie, la matière et le mouvement avant leur intégration dans les apps.

| # | Expérience | Ce qu'elle teste |
| --- | --- | --- |
| 01 | Surface prismatique | Droplet Matter posée sur un contenu réel : réfraction des bords, dispersion, dépoli, opacité réglables |
| 02 | Objet en métamorphose | Sphère, pavé, goutte, grappe : interpolation de distances signées, relief calculé |
| 03 | Atmosphère Aether | Lumière diffuse, rais, trois nappes de brume en parallaxe |
| 04 | Morph prismatique | La forme vivante faite de matière : la lumière suit la géométrie |
| 05 | Matière interactive | Ressorts : la goutte suit le doigt, s'étire avec le geste, se tend vers l'appui |
| 06 | Signature | Tout ensemble, avec le nom « Droplet » dont l'axe Flair respire avec la forme |

## Lancer

```sh
flutter run                 # Android, iOS ou web
python3 tool/build_shaders.py   # après toute modification de shaders/src ou shaders/lib
```

Chaque poussée sur `main` est compilée par GitHub Actions : analyse, tests, web, APK, puis captures des expériences dans un navigateur. Résultats sur la branche [`captures`](../../tree/captures) : images, `droplet-matter-lab.apk`, journaux.

## Organisation

| Dossier | Rôle |
| --- | --- |
| `shaders/src`, `shaders/lib` | Sources GLSL : bibliothèque commune, Aether, Morph, Droplet Matter |
| `shaders/*.frag` | Shaders autonomes générés pour Flutter |
| `lib/core` | Qualité (LOW à ULTRA), réglages, mesure des images |
| `lib/rendering` | Chargement des shaders, écriture des uniformes, peintre |
| `lib/materials`, `lib/geometry`, `lib/lighting`, `lib/motion`, `lib/interactions` | Les quatre sous-systèmes et la saisie |
| `lib/experiments` | Les six expériences |
| `tool/` | Assemblage des shaders, captures |
| `documentation/` | Manifeste, spécification, architecture, performances, plateformes, feuille de route |

## Licences

Code : tous droits réservés, Droplet. Polices Commissioner et Martian Mono : SIL Open Font License 1.1 (textes dans `assets/fonts`).
