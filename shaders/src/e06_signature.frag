// Expérience 06 — Signature.
// Les trois fondations réunies : une goutte de Droplet Matter qui se transforme
// lentement dans l'atmosphère Aether, et projette sous elle une caustique
// spectrale très faible, comme la lumière qui traverse une goutte d'eau.
#include "../lib/header.glsl"

uniform float uCycle;

out vec4 fragColor;

#include "../lib/common.glsl"
#include "../lib/aether.glsl"

vec3 dmBackground(vec2 p) { return aether(p); }

#include "../lib/matter.glsl"
#include "../lib/morph.glsl"

float sceneSdf(vec2 p) {
  float R = min(uSize.x, uSize.y) * 0.2;
  return dmMorph(p, uSize * vec2(0.5, 0.40), R, uCycle);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float R = min(uSize.x, uSize.y) * 0.2;
  float d = sceneSdf(p);
  vec2 g = vec2(sceneSdf(p + vec2(1.0, 0.0)) - sceneSdf(p - vec2(1.0, 0.0)),
                sceneSdf(p + vec2(0.0, 1.0)) - sceneSdf(p - vec2(0.0, 1.0)));
  vec2 n = normalize(g + vec2(1e-5));

  vec3 bg = dmBackground(p);

  // Ombre et caustique : la lumière concentrée par la goutte retombe plus bas.
  float dc = sceneSdf((p - vec2(0.0, R * 0.9) - uSize * vec2(0.5, 0.40)) * 1.25 + uSize * vec2(0.5, 0.40));
  float sh = dropletShadow(sceneSdf(p - vec2(0.0, R * 0.12)), R * 0.25);
  float caustic = exp(-abs(dc) / (R * 0.10)) * step(0.0, d);
  vec3 tintC = dmSpectrum(p.x / (R * 2.2) + uTime * 0.02 * uMotion);
  bg *= 1.0 - sh * mix(0.16, 0.42, uTheme) * step(0.0, d);
  bg += (tintC - 0.4) * caustic * mix(0.05, 0.08, uTheme);

  vec3 col = bg;
  float inside = clamp(0.5 - d, 0.0, 1.0);
  if (inside > 0.0) {
    vec3 m = dropletMatter(p, d, n, 34.0, 0.42, 7.0, 0.06, 52.0);
    col = mix(bg, m, inside);
  }
  fragColor = vec4(col + dmDither(p), 1.0);
}
