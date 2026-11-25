# Site d'exemple du Droplet Design Language

Une page d'accueil et une page de composants pour valider le système avant de l'appliquer aux sites Droplet. Astro 5 (compilé par Vite), aucun framework côté client.

- `src/styles/global.css` : jetons (primitifs puis sémantiques), rôles typographiques, boutons, verre.
- `src/scripts/rain.ts` : l'eau sur la vitre, même simulation que `packages/droplet_glass` et même shader (`src/shaders/water_glass.frag`, généré par `tool/build_shaders.py --webgl` à la racine du dépôt).
- `src/scripts/glass.ts` : réfraction de bord de la barre (Chromium seulement ; ailleurs, verre dépoli).
- `tool/fonds.py` : les deux fonds de la vitre, dessinés par programme.

```sh
npm install
npm run dev
```

Polices sous SIL Open Font License 1.1 (textes dans `public/fonts`).
