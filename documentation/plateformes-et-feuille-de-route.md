# Plateformes et feuille de route

## Adaptation par plateforme

| Plateforme | Ce qui reste identique | Ce qui s'adapte |
| --- | --- | --- |
| Android | Matière, lumière, formes, ressorts | Retour système, gestes de navigation, haptique Android ; AGSL natif pour Droplet ID |
| iOS | Idem | Gestes iOS, haptique iOS ; Metal si une app native arrive |
| Web | Idem, via WebGL 2 | Clavier complet, survol, focus visible ; niveau BALANCED par défaut |
| Ordinateur | Idem | Densité plus forte, matière réservée aux surfaces de navigation |

## Feuille de route

| Étape | Livrable | Condition pour passer à la suite |
| --- | --- | --- |
| 1 Lab v0.1 (fait) | Six expériences, bibliothèque de shaders, CI | Compile, tests verts, captures sans erreur |
| 1 bis Lab v0.2 (fait) | Monorepo core / glass / ui, eau sur vitre, verre v2, barre liquide, version web sur Vercel | Retours du fondateur sur le rendu |
| 2 Mesures | Images par seconde sur deux vrais téléphones | Budgets atteints, ou corrections identifiées |
| 3 Aether en texture | Fond rendu une fois par image puis réfracté | 05 et 06 au niveau des autres |
| 4 Matière sur vrais widgets | Barre de navigation en Droplet Matter sur une liste réelle | Lisible au soleil, fluide en BALANCED |
| 5 Jetons | Paramètres de matière et de mouvement dans le dépôt de jetons DDL | Une source pour Flutter, Compose, web |
| 6 Intégration | Droplet ID (approbation), puis Messenger (barres) | Validation sur appareils |

## Questions ouvertes

- Réfraction de widgets réels : `ImageFilter.shader` avec `BackdropFilter` sur la version de Flutter retenue, ou capture de texture ?
- Niveau par défaut sur les téléphones d'entrée de gamme : BALANCED ou LOW ?
- Haptique : quels retours accompagnent l'appui sur la matière (expérience 05) ?
