// Expérience 04 — Morph prismatique.
// La géométrie de l'expérience 02, faite de Droplet Matter, sur un contenu réel.
// La réponse lumineuse suit la forme : la normale change, la réfraction aussi.
#include "../lib/header.glsl"

uniform vec2 uImageSize;
uniform float uCycle;
uniform float uRefraction;
uniform float uDispersion;
uniform sampler2D uScene;

out vec4 fragColor;

#include "../lib/common.glsl"

vec3 dmBackground(vec2 p) {
  float s = max(uSize.x / uImageSize.x, uSize.y / uImageSize.y);
  vec2 ip = (p - uSize * 0.5) / s + uImageSize * 0.5;
  return texture(uScene, clamp(ip / uImageSize, 0.0, 1.0)).rgb;
}

#include "../lib/matter.glsl"
#include "../lib/morph.glsl"

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
