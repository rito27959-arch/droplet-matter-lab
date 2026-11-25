// FICHIER GÉNÉRÉ par tool/build_shaders.py depuis shaders/src : ne pas modifier.
#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;
// Expérience 03 — Atmosphère Aether.
// Lumière diffuse, trois nappes de brume en parallaxe, vignettage. Aucune texture.
// ---- shaders/lib/header.glsl ----
// En-tête commun : uniformes partagés par toutes les expériences, dans cet ordre.
// L'ordre compte : Flutter les renseigne par index (voir lib/rendering/uniforms.dart).
uniform vec2 uSize;      // taille du canevas, pixels logiques
uniform float uTime;     // secondes
uniform float uQuality;  // 1 BALANCED, 2 HIGH, 3 ULTRA (LOW n'utilise pas de shader)
uniform float uTheme;    // 0 clair, 1 sombre
uniform vec2 uPointer;   // position du doigt ou du pointeur
uniform float uMotion;   // 1 normal, 0 animations réduites

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
// ---- shaders/lib/aether.glsl ----
// ---------------------------------------------------------------------------
// Aether : profondeur atmosphérique procédurale.
// Trois nappes de brume à des profondeurs différentes, une source de lumière
// diffuse avec des rais très doux, un vignettage. Aucune texture.
// Dépend de : uSize, uTime, uTheme (0 clair, 1 sombre), uPointer, uMotion.
// ---------------------------------------------------------------------------

vec3 aether(vec2 p) {
  vec2 uv = p / uSize.y;                       // unités indépendantes du format
  float t = uTime * 0.035 * uMotion;
  vec2 par = (uPointer / uSize - 0.5) * uMotion; // parallaxe, coupée si mouvement réduit

  // Palettes : nuit profonde ou brume claire. Une seule lueur, froide.
  vec3 deep  = mix(vec3(0.835, 0.865, 0.895), vec3(0.018, 0.028, 0.042), uTheme);
  vec3 mist  = mix(vec3(0.690, 0.745, 0.800), vec3(0.070, 0.125, 0.165), uTheme);
  vec3 glowC = mix(vec3(1.000, 0.975, 0.930), vec3(0.560, 0.760, 0.900), uTheme);

  // Nappes de brume, de la plus lointaine à la plus proche.
  float f1 = dmFbm(uv * 1.3 + vec2(t, 0.0) + par * 0.02);
  float f2 = dmFbm(uv * 2.6 + vec2(-t * 1.6, t * 0.4) + par * 0.05 + 7.0);
  float f3 = dmFbm(uv * 5.0 + vec2(t * 2.4, -t) + par * 0.09 + 13.0);
  float fog = f1 * 0.55 + f2 * 0.30 + f3 * 0.15;

  // Lumière diffuse venant d'en haut à gauche, et ses rais.
  vec2 lp = vec2(0.18, -0.08) * uSize / uSize.y + par * 0.04;
  vec2 v = uv - lp;
  float dist = length(v);
  float glow = exp(-dist * 2.1);
  float ang = atan(v.y, v.x);
  float rays = dmFbm(vec2(ang * 7.0, t * 2.0)) * smoothstep(0.0, 0.6, dist);
  float light = glow * (0.70 + 0.55 * rays);

  vec3 col = mix(deep, mist, smoothstep(0.25, 0.85, fog));
  col += glowC * light * mix(0.50, 0.55, uTheme);

  // Vignettage léger : la profondeur se lit aussi aux bords.
  vec2 q = p / uSize - 0.5;
  col *= 1.0 - dot(q, q) * mix(0.30, 0.55, uTheme);
  return col;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  fragColor = vec4(aether(p) + dmDither(p), 1.0);
}
