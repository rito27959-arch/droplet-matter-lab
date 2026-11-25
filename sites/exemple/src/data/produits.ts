// Les produits de l'écosystème, tels que leurs dépôts les décrivent.
// Une page produit n'existe ici que pour Messenger ; les autres suivront le même gabarit.
export type Produit = {
  id: string;
  nom: string;
  phrase: string;
  plateforme: string;
  page?: string;
  externe?: string;
};

export const produits: Produit[] = [
  {
    id: 'messenger',
    nom: 'Messenger',
    phrase: 'La messagerie qui passe, même sans réseau.',
    plateforme: 'Android 7.0+',
    page: '/produits/messenger/',
  },
  {
    id: 'id',
    nom: 'Droplet ID',
    phrase: 'Se connecter aux apps et aux sites d’un geste, sans mot de passe ni numéro.',
    plateforme: 'Android 12+',
  },
  {
    id: 'drop',
    nom: 'Drop',
    phrase: 'Envoyer des fichiers aux appareils autour de soi, par le réseau local.',
    plateforme: 'Réseau local',
    externe: 'https://drop.dropletmesh.app',
  },
  {
    id: 'web',
    nom: 'Web',
    phrase: 'Ses conversations dans le navigateur, même téléphone éteint.',
    plateforme: 'Navigateur',
  },
  {
    id: 'os',
    nom: 'Droplet OS',
    phrase: 'Un système qui démarre sur ordinateur, avec sa propre identité.',
    plateforme: 'x86-64, v0.1',
  },
];
