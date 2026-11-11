//@settings dtype=float32 format=rgba renderscale=0.5
// --- GrowBranches, pass M: where it may grow, at the size of the simulation. r: the soil (Mask role), g: 1 on the
// outlines of the mask, b: the mask, a: the direction across the outline (angle) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 px = 1.0 / iResolution.xy;
    float m = mp_mask(uv);
    float ml = mp_mask(uv - vec2(px.x, 0.0));
    float mr = mp_mask(uv + vec2(px.x, 0.0));
    float md = mp_mask(uv - vec2(0.0, px.y));
    float mu = mp_mask(uv + vec2(0.0, px.y));
    bool inside = m > 0.5;
    bool edge = (ml > 0.5) != inside || (mr > 0.5) != inside || (md > 0.5) != inside || (mu > 0.5) != inside;
    if (mp_mask_mode() == 4) edge = false;
    vec2 g = vec2(mr - ml, mu - md);
    float ang = dot(g, g) > 1e-6 ? atan(g.y, g.x) : 0.0;
    fragColor = vec4(gr_soil(m), edge ? 1.0 : 0.0, m, ang);
}
