// ============================================================================
// L'EAU SUR LA VITRE — écran des discussions, au retour après une longue absence.
// Repris de Droplet Matter Lab (water_glass.frag), avec un fondu global
// (uFade) pour entrer et sortir sans saut. Voir lib/shared/eau/vitre_embuee.dart.
// ⚠️ L'ORDRE DES UNIFORMES COMPTE : Dart les renseigne par index.
// ============================================================================
#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;
// De l'eau sur une vitre.
//
// La simulation (Dart) dessine à chaque image deux cartes à demi-résolution :
//   uHeight : hauteur d'eau (0 vitre sèche, 1 sommet d'une grosse goutte)
//   uClear  : là où l'eau a essuyé la buée (gouttes, traînées, doigt)
// Ici, chaque pixel est rendu selon ce qu'il y a dessus : vitre embuée, vitre
// essuyée, ou goutte d'eau traversée par la lumière.
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
uniform float uFog;         // 0 vitre sèche, 1 buée complète
uniform float uRefraction;  // distance apparente du fond derrière l'eau (px)
uniform float uDropHeight;  // hauteur d'une goutte (px) : règle la pente
uniform vec2 uMapSize;      // taille des cartes en texels
uniform float uFade;        // 0 invisible, 1 pleinement là (fondu d'entrée et de sortie)
uniform sampler2D uScene;
uniform sampler2D uSceneBlur;
uniform sampler2D uHeight;
uniform sampler2D uClear;

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

vec2 coverUv(vec2 p) {
  float s = max(uSize.x / uImageSize.x, uSize.y / uImageSize.y);
  vec2 ip = (p - uSize * 0.5) / s + uImageSize * 0.5;
  return clamp(ip / uImageSize, 0.0, 1.0);
}

vec3 sharpAt(vec2 p) { return texture(uScene, coverUv(p)).rgb; }
vec3 blurAt(vec2 p) { return texture(uSceneBlur, coverUv(p)).rgb; }
// Lecture bilinéaire faite à la main : le filtrage des textures n'est pas
// garanti identique sur tous les moteurs de rendu (Impeller, Skia, web).
// (Le web n'accepte pas de sampler en paramètre : une fonction par carte.)
vec2 mapBase(vec2 p, out vec2 f) {
  vec2 t = clamp(p / uSize, 0.0, 1.0) * uMapSize - 0.5;
  vec2 i = floor(t);
  f = t - i;
  return (i + 0.5) / uMapSize;
}
float heightAt(vec2 p) {
  vec2 f;
  vec2 b = mapBase(p, f);
  vec2 px = 1.0 / uMapSize;
  return mix(mix(texture(uHeight, b).r, texture(uHeight, b + vec2(px.x, 0.0)).r, f.x),
             mix(texture(uHeight, b + vec2(0.0, px.y)).r, texture(uHeight, b + px).r, f.x), f.y);
}
float clearAt(vec2 p) {
  vec2 f;
  vec2 b = mapBase(p, f);
  vec2 px = 1.0 / uMapSize;
  return mix(mix(texture(uClear, b).r, texture(uClear, b + vec2(px.x, 0.0)).r, f.x),
             mix(texture(uClear, b + vec2(0.0, px.y)).r, texture(uClear, b + px).r, f.x), f.y);
}

void main() {
  vec2 p = FlutterFragCoord().xy;

  // Hauteur lissée sur une croix : la carte est en 8 bits, à demi-résolution.
  float e = 1.0;
  float hC = heightAt(p);
  float hR = heightAt(p + vec2(e, 0.0));
  float hL = heightAt(p - vec2(e, 0.0));
  float hD = heightAt(p + vec2(0.0, e));
  float hU = heightAt(p - vec2(0.0, e));
  float h = (hC * 2.0 + hR + hL + hD + hU) / 6.0;
  vec2 grad = vec2(hR - hL, hD - hU) / (2.0 * e) * uDropHeight;
  vec3 N = normalize(vec3(-grad, 1.0));

  // --- La vitre : buée là où rien ne l'a essuyée -------------------------
  float clearMask = clearAt(p);
  float fog = uFog * (1.0 - clearMask);
  vec3 fogTint = mix(vec3(0.94, 0.955, 0.97), vec3(0.58, 0.64, 0.70), uTheme);
  vec3 fogged = mix(blurAt(p), fogTint, mix(0.20, 0.12, uTheme));
  // Micro-gouttelettes de condensation : un grain très fin, fixe.
  fogged += (dmHash(floor(p * 0.85)) - 0.5) * 0.04 * fog;
  vec3 glass = mix(sharpAt(p), fogged, fog);

  // Lumière : suit le doigt, sinon en haut à droite (Droplet Light).
  vec3 L = normalize(vec3((uPointer - p) / max(uSize.y, 1.0) * 1.4, 0.85));
  vec2 L2 = normalize(L.xy + vec2(0.0001));

  // Ombre de contact : l'eau assombrit très légèrement la vitre juste à côté
  // d'elle, du côté opposé à la lumière.
  float hShadow = heightAt(p + L2 * 4.0);
  glass *= 1.0 - clamp(hShadow - h, 0.0, 1.0) * 0.22;

  vec3 col = glass;
  float cover = smoothstep(0.012, 0.07, h);
  if (cover > 0.0) {
    // --- La goutte : une lentille d'eau (n ≈ 1,333) -----------------------
    // Le fond est loin derrière la vitre : la goutte le renverse et le
    // rapetisse, comme une vraie goutte sur une fenêtre.
    float depth = uRefraction * (0.30 + h);
    vec3 inside;
    vec3 tg = refract(vec3(0.0, 0.0, -1.0), N, 1.0 / 1.333);
    if (uQuality < 1.5) {
      inside = sharpAt(p + tg.xy / max(-tg.z, 0.2) * depth);
    } else {
      vec3 tr = refract(vec3(0.0, 0.0, -1.0), N, 1.0 / 1.329);
      vec3 tb = refract(vec3(0.0, 0.0, -1.0), N, 1.0 / 1.341);
      inside = vec3(
        sharpAt(p + tr.xy / max(-tr.z, 0.2) * depth).r,
        sharpAt(p + tg.xy / max(-tg.z, 0.2) * depth).g,
        sharpAt(p + tb.xy / max(-tb.z, 0.2) * depth).b);
    }
    inside *= 0.95;

    // Fresnel de Schlick (eau, F0 = 0,02) : les bords reflètent le ciel flou.
    float F = 0.02 + 0.98 * pow(1.0 - N.z, 5.0);
    vec3 env = mix(blurAt(p - N.xy * 160.0) * 1.18, fogTint, 0.30);
    vec3 drop = mix(inside, env, clamp(F * 1.3, 0.0, 0.85));

    // Bord sombre : là où la pente est forte, la lumière se réfléchit
    // à l'intérieur de la goutte au lieu de la traverser.
    float slope = length(grad);
    drop *= 1.0 - smoothstep(1.1, 3.2, slope) * 0.5;

    // Caustique intérieure : la goutte concentre la lumière sur son côté
    // opposé à la source.
    drop += pow(max(dot(N.xy, -L2), 0.0), 1.5) * smoothstep(0.05, 0.6, h) * 0.30;

    // Reflets : un point vif et un halo doux.
    vec3 Hh = normalize(L + vec3(0.0, 0.0, 1.0));
    float nh = max(dot(N, Hh), 0.0);
    // Le reflet vit très légèrement, comme l'eau qui tremble (coupé si animations réduites).
    float shimmer = 1.0 + 0.08 * uMotion * sin(uTime * 3.0 + p.x * 0.05);
    drop += (pow(nh, 180.0) * 1.5 + pow(nh, 22.0) * 0.07) * shimmer;

    col = mix(glass, drop, cover);
  }

  fragColor = vec4(col + dmDither(p), 1.0) * uFade;
}
