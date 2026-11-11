//@settings dtype=float32 format=rgba renderscale=0.5
// --- EdgeSweep, pass E: the seeds of the outlines. The outline of the mask, and the edges of the picture (Sobel,
// thinned to one pixel along the gradient, placed between pixels by a parabola through the edge strength) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D M;
uniform sampler2D N;          // which mask (pass N): see mp_mask_mode_from in lib/mask.glsl

vec2 sobel(ivec2 p) {
    ivec2 hi = textureSize(M, 0) - 1;
    float v[9];
    int k = 0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            v[k] = texelFetch(M, clamp(p + ivec2(x, y), ivec2(0), hi), 0).g;
            k++;
        }
    }
    float gx = (v[2] + 2.0 * v[5] + v[8]) - (v[0] + 2.0 * v[3] + v[6]);
    float gy = (v[6] + 2.0 * v[7] + v[8]) - (v[0] + 2.0 * v[1] + v[2]);
    return vec2(gx, gy) * 0.25;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    mp_mask_mode_from(N);   // not textureSize(mask) here: this pass has other inputs (#880)
    ivec2 p = ivec2(fragCoord);
    vec4 s = vec4(-1e4, -1e4, 0.0, 0.0);
    if (edge_source != 0 && mp_mask_mode() != 4) s = jfa_seed_mask(M, p);
    if (s.w < 0.5 && edge_source != 1) {
        vec2 g = sobel(p);
        float m = length(g);
        float th = max(edge_threshold, 0.005);
        if (m > th) {
            vec2 n = g / m;
            ivec2 o = ivec2(round(n));
            float m1 = length(sobel(p + o));
            float m2 = length(sobel(p - o));
            if (m >= m1 && m > m2) {
                float den = m1 - 2.0 * m + m2;
                float off = abs(den) > 1e-6 ? clamp(0.5 * (m2 - m1) / den, -0.5, 0.5) : 0.0;
                float strength = clamp((m - th) / max(th, 0.05), 0.0, 1.0);
                s = vec4(vec2(p) + 0.5 + off * vec2(o), atan(n.y, n.x), 1.0 + strength);
            }
        }
    }
    fragColor = s;
}
