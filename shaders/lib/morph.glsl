// ---------------------------------------------------------------------------
// Morph : une géométrie vivante.
// Quatre états (sphère, pavé arrondi, goutte, grappe de trois gouttes) reliés
// par une interpolation de distances signées. Chaque état est tenu un moment
// puis glisse vers le suivant ; une ondulation lente garde la forme vivante.
// Dépend de : uTime, uMotion, common.glsl.
// ---------------------------------------------------------------------------

float dmShape(vec2 q, float R, float k, float t) {
  if (k < 0.5) return dmCircle(q, R);
  if (k < 1.5) return dmRoundBox(q, vec2(R * 0.92), R * 0.42);
  if (k < 2.5) return dmDrop(q - vec2(0.0, R * 0.28), R * 0.86, R * 0.10, R * 1.30);
  // Grappe : trois gouttes qui tournent et fusionnent par union douce.
  float a = t * 0.6;
  float c1 = dmCircle(q - R * 0.42 * vec2(cos(a), sin(a)), R * 0.56);
  float c2 = dmCircle(q - R * 0.42 * vec2(cos(a + 2.094), sin(a + 2.094)), R * 0.56);
  float c3 = dmCircle(q - R * 0.42 * vec2(cos(a + 4.189), sin(a + 4.189)), R * 0.56);
  return dmSmin(dmSmin(c1, c2, R * 0.5), c3, R * 0.5);
}

// s : position dans le cycle (une unité par forme). Retourne la distance signée.
float dmMorph(vec2 p, vec2 c, float R, float s) {
  vec2 q = p - c;
  float k = mod(floor(s), 4.0);
  float kn = mod(k + 1.0, 4.0);
  float f = smoothstep(0.55, 1.0, fract(s));   // tenue, puis transition
  float t = uTime * uMotion;
  float d = mix(dmShape(q, R, k, t), dmShape(q, R, kn, t), f);
  // Ondulation organique : très faible, coupée si l'utilisateur réduit les animations.
  float ang = atan(q.y, q.x);
  d += sin(ang * 3.0 + t * 1.3) * R * 0.018 * uMotion;
  return d;
}
