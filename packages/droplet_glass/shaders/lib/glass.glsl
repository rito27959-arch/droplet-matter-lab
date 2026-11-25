// ---------------------------------------------------------------------------
// Droplet Glass v2 : verre à profil physique.
//
// La surface est un pavé dont le bord descend selon un profil « squircle »
// convexe, y(x) = (1 − (1 − x)⁴)^¼, x allant de 0 (bord) à 1 (fin du biseau).
// La normale est déduite de la pente du profil ; le rayon de vue est réfracté
// par la loi de Snell (n = eta), et traverse l'épaisseur locale du verre avant
// de toucher le fond. Méthode décrite publiquement par kube.io (« Liquid Glass
// in the Browser ») ; implémentation propre à Droplet.
//
// L'includeur définit avant ce fichier :
//   vec3 glassSharp(vec2 p)   fond net, en pixels
//   vec3 glassBlur(vec2 p)    fond flou (remplissage du dépoli)
// ---------------------------------------------------------------------------

float glassProfile(float x) {
  x = clamp(x, 0.0, 1.0);
  return pow(1.0 - pow(1.0 - x, 4.0), 0.25);
}

// Pente du profil, en pixels de hauteur par pixel de largeur.
float glassSlope(float x, float bezel, float thickness) {
  float e = 0.004;
  float a = glassProfile(x + e);
  float b = glassProfile(max(x - e, 0.0));
  return (a - b) / (x + e - max(x - e, 0.0)) * thickness / bezel;
}

// Décalage d'un rayon réfracté à travers le verre, pour un indice donné.
vec2 glassOffset(vec3 N, float eta, float travel) {
  vec3 T = refract(vec3(0.0, 0.0, -1.0), N, 1.0 / eta);
  return T.xy / max(-T.z, 0.25) * travel;
}

// d : distance signée (px), n : normale 2D sortante, bezel : largeur du biseau,
// thickness : épaisseur (px), frost : 0 net, 1 dépoli, tintAmt : voile de surface.
vec3 dropletGlass(vec2 p, float d, vec2 n, float bezel, float thickness, float frost, float tintAmt) {
  float x = clamp(-d / bezel, 0.0, 1.0);
  float y = glassProfile(x);
  float slope = glassSlope(x, bezel, thickness);
  vec3 N = normalize(vec3(n * slope, 1.0));
  float travel = thickness * (0.35 + 0.65 * y);

  vec3 sharp;
  vec3 soft;
  if (uQuality < 1.5) {
    vec2 o = glassOffset(N, 1.5, travel);
    sharp = glassSharp(p + o);
    soft = glassBlur(p + o);
  } else {
    // Dispersion : trois indices proches, comme un verre réel (verre crown).
    vec2 orr = glassOffset(N, 1.495, travel);
    vec2 og = glassOffset(N, 1.510, travel);
    vec2 ob = glassOffset(N, 1.530, travel);
    sharp = vec3(glassSharp(p + orr).r, glassSharp(p + og).g, glassSharp(p + ob).b);
    soft = vec3(glassBlur(p + orr).r, glassBlur(p + og).g, glassBlur(p + ob).b);
  }
  vec3 col = mix(sharp, soft, frost);

  // Adaptation : le verre compresse les très fortes luminances pour rester lisible.
  float Y = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col = mix(col, col * (0.86 + 0.14 * (1.0 - Y)), 0.6);

  // Voile de surface (le « blanc laiteux » du verre clair, l'encre du sombre).
  vec3 tintCol = mix(vec3(1.0), vec3(0.06, 0.07, 0.09), uTheme);
  col = mix(col, tintCol, tintAmt);

  // Fresnel de Schlick : le bord réfléchit l'environnement.
  float F = 0.04 + 0.96 * pow(1.0 - N.z, 5.0);
  col = mix(col, glassBlur(p - n * 60.0) * 1.12 + 0.06, clamp(F, 0.0, 0.6));

  // Liseré spéculaire : la lumière (le doigt) éclaire un côté du bord,
  // le côté opposé renvoie un reflet plus faible.
  vec2 Ld = normalize(uPointer - p + vec2(0.0001));
  float rim = 1.0 - smoothstep(0.0, 0.10, x);
  float front = pow(max(dot(n, Ld), 0.0), 2.0);
  float back = pow(max(dot(n, -Ld), 0.0), 2.0);
  col += rim * (front * 0.55 + back * 0.18);
  return col;
}
