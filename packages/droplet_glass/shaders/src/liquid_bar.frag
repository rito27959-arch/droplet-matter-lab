// Barre d'onglets liquide.
// Une capsule de verre posée sur un contenu qui défile, et une lentille de
// sélection plus épaisse qui glisse d'un onglet à l'autre. Quand on appuie,
// la lentille se soulève et fusionne avec la barre par union douce.
#include "../lib/header.glsl"

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

#include "../lib/common.glsl"

vec2 contentUv(vec2 p) {
  float s = uSize.x / uImageSize.x;
  vec2 ip = vec2(p.x / s, (p.y + uScroll) / s);
  ip.y = mod(ip.y, uImageSize.y);
  return clamp(ip / uImageSize, 0.0, 1.0);
}

vec3 glassSharp(vec2 p) { return texture(uScene, contentUv(p)).rgb; }
vec3 glassBlur(vec2 p) { return texture(uSceneBlur, contentUv(p)).rgb; }

#include "../lib/glass.glsl"

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
