// ---------------------------------------------------------------------------
// Droplet Matter : la matière propriétaire.
//
// Différence avec un verre dépoli : la surface est presque mate au centre ;
// la lumière ne se courbe que près du bord, comme dans une goutte d'eau, et se
// sépare en spectre sur un liseré de un à trois pixels seulement.
//
// Le shader qui inclut ce fichier doit définir avant lui :
//   vec3 dmBackground(vec2 p)   ce qui se trouve derrière la matière (pixels)
// et les uniformes uSize, uTime, uQuality, uTheme, uPointer.
//
// Paramètres :
//   d      distance signée au bord (px, négative à l'intérieur)
//   n      normale sortante unitaire
//   refr   déviation maximale au bord (px)
//   disp   dispersion chromatique (0 à 0,6)
//   frost  rayon du dépoli (px)
//   tint   quantité de teinte de surface (0 à 1)
//   rim    largeur de la zone de lentille (px)
// ---------------------------------------------------------------------------

vec3 dropletMatter(vec2 p, float d, vec2 n, float refr, float disp, float frost, float tint, float rim) {
  float e = clamp(1.0 + d / rim, 0.0, 1.0);   // 0 au cœur, 1 au bord
  float lens = e * e * e * e;                   // la courbure se concentre au bord
  vec2 off = -n * lens * refr;                  // la lumière est déviée vers l'intérieur

  vec3 col;
  if (uQuality < 1.5) {
    // BALANCED : un seul échantillon, pas de dispersion.
    col = dmBackground(p + off);
  } else {
    // HIGH et ULTRA : trois longueurs d'onde déviées différemment.
    col.r = dmBackground(p + off * (1.0 + disp)).r;
    col.g = dmBackground(p + off).g;
    col.b = dmBackground(p + off * (1.0 - disp)).b;
  }

  // Dépoli : 6 échantillons en HIGH, 12 en ULTRA, sur un disque de Vogel tourné
  // au hasard à chaque pixel : le flou devient un grain fin au lieu d'images doublées.
  if (frost > 0.0 && uQuality > 1.5) {
    vec3 acc = col;
    float count = 1.0;
    float taps = uQuality > 2.5 ? 12.0 : 6.0;
    float rot = dmHash(p) * 6.28318;
    for (int i = 0; i < 12; i++) {
      float fi = float(i);
      if (fi >= taps) break;
      float a = fi * 2.39996 + rot;
      float r = frost * sqrt((fi + 0.5) / taps);
      acc += dmBackground(p + off + vec2(cos(a), sin(a)) * r);
      count += 1.0;
    }
    col = acc / count;
  }

  // Teinte de surface : laiteuse en clair, encre en sombre.
  vec3 surface = mix(vec3(0.985, 0.990, 1.0), vec3(0.055, 0.070, 0.090), uTheme);
  col = mix(col, surface, tint);

  // Fresnel : le bord renvoie plus de lumière que le centre.
  float fres = pow(e, 5.0);
  col += fres * mix(0.06, 0.16, uTheme);

  // En clair, un bord légèrement plus sombre dessine la goutte : comme une
  // goutte réelle sur un fond clair, qui renvoie l'environnement plus sombre.
  float edgeLine = smoothstep(-7.0, -1.5, d) * (1.0 - smoothstep(-1.5, 0.0, d));
  col -= edgeLine * (1.0 - uTheme) * 0.10;

  // Reflet spéculaire qui suit la lumière (le doigt ou le pointeur).
  vec2 L = normalize(uPointer - p + vec2(0.0001));
  float spec = pow(max(dot(n, L), 0.0), 18.0) * smoothstep(0.6, 1.0, e);
  col += spec * mix(0.45, 0.60, uTheme);

  // Liseré spectral : 1 à 3 px au bord, teinte selon l'orientation du bord.
  float band = smoothstep(-3.0, -0.8, d) * (1.0 - smoothstep(-0.8, 0.0, d) * 0.4);
  float ang = atan(n.y, n.x) / 6.28318 + 0.5 + uTime * 0.01 * uMotion;
  vec3 spectral = dmSpectrum(ang);
  col += (spectral - 0.45) * band * disp * 0.9;

  return col;
}
