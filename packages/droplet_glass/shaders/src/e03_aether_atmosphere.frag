// Expérience 03 — Atmosphère Aether.
// Lumière diffuse, trois nappes de brume en parallaxe, vignettage. Aucune texture.
#include "../lib/header.glsl"

out vec4 fragColor;

#include "../lib/common.glsl"
#include "../lib/aether.glsl"

void main() {
  vec2 p = FlutterFragCoord().xy;
  fragColor = vec4(aether(p) + dmDither(p), 1.0);
}
