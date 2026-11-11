// ---- Projection mapping building blocks (#586): distance to the nearest outline (jump flooding) ----
// A seed is vec4(position in texels of its pass, angle of the normal, 1 + strength); w = 0: no seed. The normal of a
// mask outline points into the surface, so the tangent (-n.y, n.x) runs around a shape the same way all along.

// Seeds on the outline of the mask in M.r (0..1, 0.5 is the outline), placed between the pixels where the mask
// crosses 0.5, so the outline is smooth although the pass is smaller than the picture.
vec4 jfa_seed_mask(sampler2D M, ivec2 p) {
    ivec2 hi = textureSize(M, 0) - 1;
    float c = texelFetch(M, p, 0).r;
    float l = texelFetch(M, clamp(p - ivec2(1, 0), ivec2(0), hi), 0).r;
    float r = texelFetch(M, clamp(p + ivec2(1, 0), ivec2(0), hi), 0).r;
    float d = texelFetch(M, clamp(p - ivec2(0, 1), ivec2(0), hi), 0).r;
    float u = texelFetch(M, clamp(p + ivec2(0, 1), ivec2(0), hi), 0).r;
    bool inside = c > 0.5;
    bool edge = (l > 0.5) != inside || (r > 0.5) != inside || (d > 0.5) != inside || (u > 0.5) != inside;
    if (!edge) return vec4(-1e4, -1e4, 0.0, 0.0);
    vec2 g = vec2(r - l, u - d) * 0.5;
    float gl = length(g);
    vec2 n = gl > 1e-5 ? g / gl : vec2(0.0, 1.0);
    float off = gl > 1e-4 ? clamp((0.5 - c) / gl, -0.75, 0.75) : 0.0;
    return vec4(vec2(p) + 0.5 + n * off, atan(n.y, n.x), 2.0);
}

// One step of the jump flood: the nearest seed among the 3 x 3 neighbours at the step size of pass k (1 = the
// biggest step). Ten passes reach every texel of a pass of up to 1024 texels.
vec4 jfa_step(sampler2D prev, ivec2 p, int k) {
    vec2 res = vec2(textureSize(prev, 0));
    float levels = ceil(log2(max(max(res.x, res.y), 2.0)));
    float s = exp2(levels - float(k));
    vec4 best = texelFetch(prev, p, 0);
    if (s < 1.0) return best;
    int si = int(s);
    vec2 pc = vec2(p) + 0.5;
    vec2 dd = best.xy - pc;
    float bd = best.w > 0.5 ? dot(dd, dd) : 1e20;
    ivec2 hi = ivec2(res) - 1;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            if (x == 0 && y == 0) continue;
            ivec2 q = p + ivec2(x, y) * si;
            if (q.x < 0 || q.y < 0 || q.x > hi.x || q.y > hi.y) continue;
            vec4 v = texelFetch(prev, q, 0);
            if (v.w < 0.5) continue;
            vec2 e = v.xy - pc;
            float d2 = dot(e, e);
            if (d2 < bd) { bd = d2; best = v; }
        }
    }
    return best;
}

// The nearest outline seen from fragCoord of the calling pass: the distance in pixels of the full picture (1e5: no
// outline at all), the place of its seed (uv), its normal and its strength (0..1).
float jfa_lookup(sampler2D J, vec2 fragCoord, out vec2 seed_uv, out vec2 normal, out float strength) {
    vec2 jres = vec2(textureSize(J, 0));
    vec2 q = fragCoord * jres / iResolution.xy;
    ivec2 c = ivec2(floor(q));
    ivec2 hi = ivec2(jres) - 1;
    float bd = 1e20;
    vec4 best = vec4(0.0);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec4 v = texelFetch(J, clamp(c + ivec2(x, y), ivec2(0), hi), 0);
            if (v.w < 0.5) continue;
            vec2 e = v.xy - q;
            float d2 = dot(e, e);
            if (d2 < bd) { bd = d2; best = v; }
        }
    }
    seed_uv = best.xy / jres;
    normal = vec2(cos(best.z), sin(best.z));
    strength = clamp(best.w - 1.0, 0.0, 1.0);
    if (bd > 1e19) return 1e5;
    return sqrt(bd) * (iResolution.x / PASS_SCALE) / jres.x;
}

// The signed distance to the outline of the mask in M.r (pixels of the full picture): negative inside the
// surface. The size from the jump flood, the side from the mask itself.
float jfa_signed(sampler2D J, sampler2D M, vec2 fragCoord, out vec2 normal) {
    vec2 suv;
    float strength;
    float d = jfa_lookup(J, fragCoord, suv, normal, strength);
    float inside = mp_bilinear_uv(M, fragCoord / iResolution.xy).r;
    return inside > 0.5 ? -d : d;
}
