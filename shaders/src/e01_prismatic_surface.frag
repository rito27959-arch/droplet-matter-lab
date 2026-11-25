// Expérience 01 — Surface prismatique.
// Un panneau de Droplet Matter posé sur un contenu réel (image).
#include "../lib/header.glsl"

uniform vec2 uImageSize;
uniform float uRefraction;
uniform float uDispersion;
uniform float uFrost;
uniform float uTint;
uniform vec2 uPanelCenter;
uniform vec2 uPanelSize;
uniform sampler2D uScene;

out vec4 fragColor;

#include "../lib/common.glsl"

// Image en mode « couvrir », comme BoxFit.cover.
vec3 dmBackground(vec2 p) {
  float s = max(uSize.x / uImageSize.x, uSize.y / uImageSize.y);
  vec2 ip = (p - uSize * 0.5) / s + uImageSize * 0.5;
  return texture(uScene, clamp(ip / uImageSize, 0.0, 1.0)).rgb;
}

#include "../lib/matter.glsl"

float sceneSdf(vec2 p) {
  return dmRoundBox(p - uPanelCenter, uPanelSize * 0.5, 36.0);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float d = sceneSdf(p);
  vec2 g = vec2(sceneSdf(p + vec2(1.0, 0.0)) - sceneSdf(p - vec2(1.0, 0.0)),
                sceneSdf(p + vec2(0.0, 1.0)) - sceneSdf(p - vec2(0.0, 1.0)));
  vec2 n = normalize(g + vec2(1e-5));

  vec3 bg = dmBackground(p);
  float sh = dropletShadow(sceneSdf(p - vec2(0.0, 14.0)), 26.0);
  bg *= 1.0 - sh * mix(0.18, 0.40, uTheme) * step(0.0, d);

  vec3 col = bg;
  float inside = clamp(0.5 - d, 0.0, 1.0);
  if (inside > 0.0) {
    vec3 m = dropletMatter(p, d, n, uRefraction, uDispersion, uFrost, uTint, 28.0);
    col = mix(bg, m, inside);
  }
  fragColor = vec4(col + dmDither(p), 1.0);
}
