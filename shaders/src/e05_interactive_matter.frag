// Expérience 05 — Matière interactive.
// La goutte suit le doigt avec un ressort, s'étire dans le sens du geste, et
// se tend vers le point d'appui quand on appuie. Fond Aether procédural.
#include "../lib/header.glsl"

uniform vec2 uCenter;    // centre de la goutte, après ressort (Dart)
uniform vec2 uVelocity;  // vitesse du geste, px par image, lissée (Dart)
uniform float uPress;    // intensité de l'appui, 0 à 1, après ressort (Dart)

out vec4 fragColor;

#include "../lib/common.glsl"
#include "../lib/aether.glsl"

vec3 dmBackground(vec2 p) { return aether(p); }

#include "../lib/matter.glsl"

float sceneSdf(vec2 p) {
  float R = min(uSize.x, uSize.y) * 0.22;
  vec2 q = p - uCenter;
  // Étirement dans le sens du mouvement, plus fort au cœur qu'aux extrémités.
  vec2 v = clamp(uVelocity, vec2(-40.0), vec2(40.0));
  q -= v * 1.4 * exp(-dot(q, q) / (R * R * 1.6));
  float d = dmRoundBox(q, vec2(R * 0.9), R * 0.62);
  // Appui : la matière se tend vers le doigt, comme une goutte qu'on effleure.
  float pull = dmCircle(p - uPointer, R * 0.30 * uPress);
  d = mix(d, dmSmin(d, pull, R * 0.9), step(0.02, uPress));
  return d;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float d = sceneSdf(p);
  vec2 g = vec2(sceneSdf(p + vec2(1.0, 0.0)) - sceneSdf(p - vec2(1.0, 0.0)),
                sceneSdf(p + vec2(0.0, 1.0)) - sceneSdf(p - vec2(0.0, 1.0)));
  vec2 n = normalize(g + vec2(1e-5));

  vec3 bg = dmBackground(p);
  float sh = dropletShadow(sceneSdf(p - vec2(0.0, 18.0)), 34.0);
  bg *= 1.0 - sh * mix(0.18, 0.45, uTheme) * step(0.0, d);

  vec3 col = bg;
  float inside = clamp(0.5 - d, 0.0, 1.0);
  if (inside > 0.0) {
    float refr = 18.0 + 22.0 * uPress;
    vec3 m = dropletMatter(p, d, n, refr, 0.28 + 0.2 * uPress, 8.0, 0.12, 50.0);
    col = mix(bg, m, inside);
  }
  fragColor = vec4(col + dmDither(p), 1.0);
}
