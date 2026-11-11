//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskPhysarum, pass H: the slime as a height field for lib/relief.glsl. r: height 0..1, two layers: the thick
// veins from the trail and the agents of a 5 x 5 neighbourhood (smoothed, so the dots of single agents do not show; a
// root makes them round) and on top the capillaries, the thin trail of a few agents at the full size of the
// simulation (#892). g, b: the trail vector over the trail (the colour of the strains, ph_albedo), a: glow (the food) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D Y2;
uniform sampler2D M;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 c = ivec2(fragCoord);
    ivec2 hi = ivec2(iResolution.xy) - 1;
    vec3 t = vec3(0.0);
    float dens = 0.0;
    float ws = 0.0;
    float fine = 0.0;
    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            float w = exp(-float(x * x + y * y) / 4.0);
            vec4 s = texelFetch(Y2, clamp(c + ivec2(x, y), ivec2(0), hi), 0);
            t += vec3(max(s.r, 0.0), s.gb) * w;
            dens += step(0.5, s.a) * w;
            ws += w;
            if (abs(x) + abs(y) <= 1) fine += max(s.r, 0.0) * (x == 0 && y == 0 ? 2.0 : 1.0);
        }
    }
    t /= ws;
    dens /= ws;
    fine /= 6.0;
    // the trail of a cell that an agent visits every step settles at deposit / decay: that is a full vein
    float full = max(deposit, 0.05) / max(decay, 0.005);
    float sum = t.x / full;
    float v = (0.35 * dens + 0.65 * sum) * vein_thickness;
    float h = 1.0 - exp(-max(v - 0.06, 0.0) * 2.5);
    h = sqrt(clamp(h, 0.0, 1.0));            // a round profile: a vein is a tube
    // the capillaries: a thin trail, low and narrow, where the thick layer is low
    float f = fine / full * vein_thickness;
    float hc = 0.3 * smoothstep(0.03, 0.28, f) * capillaries;
    // and veinlets: fingers that run out of the veins along the lines where a warped noise crosses one half. The
    // trail blurred wide (two rings of taps) times a ridge on those lines: on a line it reaches further out than
    // beside it, so every finger starts at a vein and gets thinner towards its tip, like the fans of real slime
    if (capillaries > 0.0) {
        float wide = 0.0;
        vec2 towards = vec2(0.0);   // where the trail rises: the way to the vein
        for (int i = 0; i < 12; i++) {
            float an = float(i) * (MP_TAU / 6.0) + (i < 6 ? 0.3 : 0.8);
            float rr = ph_cells(i < 6 ? 15.0 : 32.0);
            vec2 dir = vec2(cos(an), sin(an));
            ivec2 q = clamp(c + ivec2(dir * rr), ivec2(0), hi);
            float tv = max(texelFetch(Y2, q, 0).r, 0.0) * (i < 6 ? 1.3 : 0.7);
            wide += tv;
            towards += dir * tv;
        }
        float hw = max(sum, wide / (12.0 * full) * 1.3) * vein_thickness;
        float sc = ph_cells(34.0);
        vec2 q = vec2(c) / sc;
        vec2 wq = q + 1.4 * vec2(mp_vnoise(q * 0.31 + 11.0), mp_vnoise(q * 0.31 + 47.0));
        float n0 = mp_vnoise(wq);
        vec2 gn = vec2(mp_vnoise(wq + vec2(0.04, 0.0)) - n0, mp_vnoise(wq + vec2(0.0, 0.04)) - n0) / 0.04;
        float dc = abs(n0 - 0.5) / max(length(gn), 0.05) * sc;   // cells to the line
        float ridge = 1.0 - smoothstep(0.0, 1.4, dc);
        // only where the line runs away from the vein (across the way to it): fingers, no arcs beside a vein
        float across = abs(dot(gn / max(length(gn), 1e-4), towards / max(length(towards), 1e-4)));
        ridge *= 1.0 - smoothstep(0.45, 0.85, across);
        float fan = hw * mix(0.25, 1.7, ridge * ridge);
        hc = max(hc, 0.24 * smoothstep(0.08, 0.2, fan) * capillaries);
    }
    h = max(h, hc) + 0.25 * hc * h;
    vec2 cv = t.yz / max(t.x, 1e-4);
    vec4 mm = texelFetch(M, c, 0);
    fragColor = vec4(clamp(h, 0.0, 1.0), cv, mm.g);
}
