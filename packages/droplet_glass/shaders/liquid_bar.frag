// FICHIER GÉNÉRÉ par tool/build_shaders.py depuis packages/droplet_glass/shaders/src : ne pas modifier.
#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;
// Barre d'onglets liquide.
// Une capsule de verre posée sur un contenu qui défile, et une lentille de
// sélection plus épaisse qui glisse d'un onglet à l'autre. Quand on appuie,
// la lentille se soulève et fusionne avec la barre par union douce.
// ---- packages/droplet_glass/shaders/lib/header.glsl ----
// En-tête commun : uniformes partagés par toutes les expériences, dans cet ordre.
// L'ordre compte : Flutter les renseigne par index (voir lib/rendering/uniforms.dart).
uniform vec2 uSize;      // taille du canevas, pixels logiques
uniform float uTime;     // secondes
uniform float uQuality;  // 1 BALANCED, 2 HIGH, 3 ULTRA (LOW n'utilise pas de shader)
uniform float uTheme;    // 0 clair, 1 sombre
uniform vec2 uPointer;   // position du doigt ou du pointeur
uniform float uMotion;   // 1 normal, 0 animations réduites

uniform vec2 uImageSize;
uniform float uScroll;       // décalage vertical du contenu (px)
uniform vec2 uBarCenter;
uniform vec2 uBarSize;
uniform vec2 uLensCenter;
uniform vec2 uLensSize;
uniform float uLensStretch;  // étirement dans le sens du geste (px)
uniform float uPress;        // 0 au repos, 1 lentille soulevée
uniform sampler2D uScene;
uniform sampler2D uSceneBlur;

out vec4 fragColor;

// ---- packages/droplet_glass/shaders/lib/common.glsl ----
// ---------------------------------------------------------------------------
// Droplet Matter, bibliothèque commune.
// Bruit, distances signées (SDF), mélange doux, spectre, tramage.
// Toutes les distances sont en pixels logiques ; y croît vers le bas (Flutter).
// ---------------------------------------------------------------------------

float dmHash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float dmNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(dmHash(i), dmHash(i + vec2(1.0, 0.0)), u.x),
             mix(dmHash(i + vec2(0.0, 1.0)), dmHash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Bruit fractal à 4 octaves (borne constante, exigée par certains moteurs).
float dmFbm(vec2 p) {
  float a = 0.5;
  float s = 0.0;
  for (int i = 0; i < 4; i++) {
    s += a * dmNoise(p);
    p = p * 2.03 + vec2(17.0, 9.0);
    a *= 0.5;
  }
  return s;
}

// Union douce (Inigo Quilez, polynôme quadratique).
float dmSmin(float a, float b, float k) {
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

float dmCircle(vec2 p, float r) {
  return length(p) - r;
}

float dmRoundBox(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Capsule à rayons inégaux, pointe vers le haut (y négatif) : la goutte.
float dmDrop(vec2 p, float r1, float r2, float h) {
  p.y = -p.y;
  p.x = abs(p.x);
  float b = (r1 - r2) / h;
  float a = sqrt(1.0 - b * b);
  float k = dot(p, vec2(-b, a));
  if (k < 0.0) return length(p) - r1;
  if (k > a * h) return length(p - vec2(0.0, h)) - r2;
  return dot(p, vec2(a, b)) - r1;
}

// Spectre doux : trois cosinus décalés, utilisé seulement en liseré très fin.
vec3 dmSpectrum(float t) {
  return 0.5 + 0.5 * cos(6.28318 * (t + vec3(0.0, 0.33, 0.67)));
}

// Tramage pour éviter les bandes de dégradé sur les écrans 8 bits.
// Son amplitude dépend de la qualité, ce qui garde aussi uQuality référencé
// dans chaque shader (un uniforme inutilisé décalerait les index côté Dart).
float dmDither(vec2 p) {
  float amp = uQuality > 2.5 ? 1.0 : 0.8;
  return (dmHash(p + fract(uTime)) - 0.5) * amp / 255.0;
}

// Ombre portée douce, hors de la forme (d > 0) : décalée vers le bas.
float dropletShadow(float dShadow, float softness) {
  return exp(-max(dShadow, 0.0) / softness);
}

vec2 contentUv(vec2 p) {
  float s = uSize.x / uImageSize.x;
  vec2 ip = vec2(p.x / s, (p.y + uScroll) / s);
  ip.y = mod(ip.y, uImageSize.y);
  return clamp(ip / uImageSize, 0.0, 1.0);
}

vec3 glassSharp(vec2 p) { return texture(uScene, contentUv(p)).rgb; }
vec3 glassBlur(vec2 p) { return texture(uSceneBlur, contentUv(p)).rgb; }

// ---- packages/droplet_glass/shaders/lib/glass.glsl ----
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

float barSdf(vec2 p) {
  return dmRoundBox(p - uBarCenter, uBarSize * 0.5, uBarSize.y * 0.5);
}

float lensSdf(vec2 p) {
  vec2 hs = uLensSize * 0.5 + vec2(abs(uLensStretch) * 0.5, 0.0) + uPress * vec2(6.0, 5.0);
  return dmRoundBox(p - uLensCenter, hs, hs.y);
}

float sceneSdf(vec2 p) {
  return dmSmin(barSdf(p), lensSdf(p), 10.0 + 14.0 * uPress);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float d = sceneSdf(p);
  vec2 g = vec2(sceneSdf(p + vec2(1.0, 0.0)) - sceneSdf(p - vec2(1.0, 0.0)),
                sceneSdf(p + vec2(0.0, 1.0)) - sceneSdf(p - vec2(0.0, 1.0)));
  vec2 n = normalize(g + vec2(1e-5));

  vec3 bg = glassSharp(p);
  // Ombre douce sous la barre : plus marquée quand la lentille se soulève.
  float sh = dropletShadow(sceneSdf(p - vec2(0.0, 6.0 + 4.0 * uPress)), 16.0 + 10.0 * uPress);
  bg *= 1.0 - sh * mix(0.14, 0.35, uTheme) * step(0.0, d);

  vec3 col = bg;
  float inside = clamp(0.5 - d, 0.0, 1.0);
  if (inside > 0.0) {
    float ld = lensSdf(p);
    float inLens = clamp(0.5 - ld, 0.0, 1.0);
    // La barre : verre dépoli fin. La lentille : verre net, plus épais, qui grossit.
    vec3 bar = dropletGlass(p, d, n, 18.0, 16.0, 0.85, mix(0.20, 0.30, uTheme));
    vec3 lens = bar;
    if (inLens > 0.0) {
      vec2 zoom = (uLensCenter - p) * (0.10 + 0.08 * uPress);
      vec2 ln = normalize(vec2(lensSdf(p + vec2(1.0, 0.0)) - lensSdf(p - vec2(1.0, 0.0)),
                               lensSdf(p + vec2(0.0, 1.0)) - lensSdf(p - vec2(0.0, 1.0))) + vec2(1e-5));
      lens = dropletGlass(p + zoom, ld, ln, 16.0, 26.0 + 14.0 * uPress, 0.15 * (1.0 - uPress), 0.06);
    }
    col = mix(bg, mix(bar, lens, inLens), inside);
  }
  // Respiration du reflet de la lentille (coupée si animations réduites).
  col += inside * 0.012 * uMotion * sin(uTime * 2.0);
  fragColor = vec4(col + dmDither(p), 1.0);
}
