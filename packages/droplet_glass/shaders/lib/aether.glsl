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
