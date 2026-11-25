// Expérience 02 — Objet en métamorphose.
// Une forme mate et nacrée passe de la sphère au pavé, à la goutte, à la grappe.
// Le relief est déduit de la distance signée : aucune géométrie 3D.
#include "../lib/header.glsl"

uniform float uCycle;   // position dans le cycle des formes, pilotée par Dart

out vec4 fragColor;

#include "../lib/common.glsl"
#include "../lib/aether.glsl"
#include "../lib/morph.glsl"

float sceneSdf(vec2 p) {
  float R = min(uSize.x, uSize.y) * 0.24;
  return dmMorph(p, uSize * vec2(0.5, 0.46), R, uCycle);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float R = min(uSize.x, uSize.y) * 0.24;
  float d = sceneSdf(p);
  vec2 g = vec2(sceneSdf(p + vec2(1.0, 0.0)) - sceneSdf(p - vec2(1.0, 0.0)),
                sceneSdf(p + vec2(0.0, 1.0)) - sceneSdf(p - vec2(0.0, 1.0)));
  vec2 n = normalize(g + vec2(1e-5));

  vec3 bg = aether(p);
  float sh = dropletShadow(sceneSdf(p - vec2(0.0, R * 0.16)), R * 0.22);
  bg *= 1.0 - sh * mix(0.22, 0.55, uTheme) * step(0.0, d);

  // Relief : pente forte au bord, plate au centre.
  float slope = 1.0 - smoothstep(0.0, R * 0.55, -d);
  vec3 N = normalize(vec3(n * slope * 1.7, 1.0));
  vec3 Ld = normalize(vec3((uPointer - p) / uSize.y, 0.75));
  float diff = max(dot(N, Ld), 0.0);
  float spec = pow(max(dot(reflect(-Ld, N), vec3(0.0, 0.0, 1.0)), 0.0), 42.0);
  float rimL = pow(slope, 3.0);

  vec3 pearl = mix(vec3(0.930, 0.945, 0.960), vec3(0.150, 0.175, 0.200), uTheme);
  vec3 col = pearl * (0.62 + 0.45 * diff) + spec * 0.35 + rimL * mix(0.04, 0.10, uTheme);

  float inside = clamp(0.5 - d, 0.0, 1.0);
  fragColor = vec4(mix(bg, col, inside) + dmDither(p), 1.0);
}
