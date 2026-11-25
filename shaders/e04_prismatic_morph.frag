// FICHIER GÉNÉRÉ par tool/build_shaders.py depuis shaders/src : ne pas modifier.
#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;
// Expérience 04 — Morph prismatique.
// La géométrie de l'expérience 02, faite de Droplet Matter, sur un contenu réel.
// La réponse lumineuse suit la forme : la normale change, la réfraction aussi.
// ---- shaders/lib/header.glsl ----
// En-tête commun : uniformes partagés par toutes les expériences, dans cet ordre.
// L'ordre compte : Flutter les renseigne par index (voir lib/rendering/uniforms.dart).
uniform vec2 uSize;      // taille du canevas, pixels logiques
uniform float uTime;     // secondes
uniform float uQuality;  // 1 BALANCED, 2 HIGH, 3 ULTRA (LOW n'utilise pas de shader)
uniform float uTheme;    // 0 clair, 1 sombre
uniform vec2 uPointer;   // position du doigt ou du pointeur
uniform float uMotion;   // 1 normal, 0 animations réduites

uniform vec2 uImageSize;
uniform float uCycle;
uniform float uRefraction;
uniform float uDispersion;
uniform sampler2D uScene;

out vec4 fragColor;

// ---- shaders/lib/common.glsl ----
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

vec3 dmBackground(vec2 p) {
  float s = max(uSize.x / uImageSize.x, uSize.y / uImageSize.y);
  vec2 ip = (p - uSize * 0.5) / s + uImageSize * 0.5;
  return texture(uScene, clamp(ip / uImageSize, 0.0, 1.0)).rgb;
}

// ---- shaders/lib/matter.glsl ----
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
// ---- shaders/lib/morph.glsl ----
// ---------------------------------------------------------------------------
// Morph : une géométrie vivante.
// Quatre états (sphère, pavé arrondi, goutte, grappe de trois gouttes) reliés
// par une interpolation de distances signées. Chaque état est tenu un moment
// puis glisse vers le suivant ; une ondulation lente garde la forme vivante.
// Dépend de : uTime, uMotion, common.glsl.
// ---------------------------------------------------------------------------

float dmShape(vec2 q, float R, float k, float t) {
  if (k < 0.5) return dmCircle(q, R);
  if (k < 1.5) return dmRoundBox(q, vec2(R * 0.92), R * 0.42);
  if (k < 2.5) return dmDrop(q - vec2(0.0, R * 0.28), R * 0.86, R * 0.10, R * 1.30);
  // Grappe : trois gouttes qui tournent et fusionnent par union douce.
  float a = t * 0.6;
  float c1 = dmCircle(q - R * 0.42 * vec2(cos(a), sin(a)), R * 0.56);
  float c2 = dmCircle(q - R * 0.42 * vec2(cos(a + 2.094), sin(a + 2.094)), R * 0.56);
  float c3 = dmCircle(q - R * 0.42 * vec2(cos(a + 4.189), sin(a + 4.189)), R * 0.56);
  return dmSmin(dmSmin(c1, c2, R * 0.5), c3, R * 0.5);
}

// s : position dans le cycle (une unité par forme). Retourne la distance signée.
float dmMorph(vec2 p, vec2 c, float R, float s) {
  vec2 q = p - c;
  float k = mod(floor(s), 4.0);
  float kn = mod(k + 1.0, 4.0);
  float f = smoothstep(0.55, 1.0, fract(s));   // tenue, puis transition
  float t = uTime * uMotion;
  float d = mix(dmShape(q, R, k, t), dmShape(q, R, kn, t), f);
  // Ondulation organique : très faible, coupée si l'utilisateur réduit les animations.
  float ang = atan(q.y, q.x);
  d += sin(ang * 3.0 + t * 1.3) * R * 0.018 * uMotion;
  return d;
}

float sceneSdf(vec2 p) {
  float R = min(uSize.x, uSize.y) * 0.26;
  return dmMorph(p, uSize * vec2(0.5, 0.42), R, uCycle);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float d = sceneSdf(p);
  vec2 g = vec2(sceneSdf(p + vec2(1.0, 0.0)) - sceneSdf(p - vec2(1.0, 0.0)),
                sceneSdf(p + vec2(0.0, 1.0)) - sceneSdf(p - vec2(0.0, 1.0)));
  vec2 n = normalize(g + vec2(1e-5));

  vec3 bg = dmBackground(p);
  float sh = dropletShadow(sceneSdf(p - vec2(0.0, 16.0)), 30.0);
  bg *= 1.0 - sh * mix(0.20, 0.45, uTheme) * step(0.0, d);

  vec3 col = bg;
  float inside = clamp(0.5 - d, 0.0, 1.0);
  if (inside > 0.0) {
    vec3 m = dropletMatter(p, d, n, uRefraction, uDispersion, 6.0, 0.10, 46.0);
    col = mix(bg, m, inside);
  }
  fragColor = vec4(col + dmDither(p), 1.0);
}
