//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskReaction, pass M: what the mask means for the reaction (Mask role). r: inside 0..1 (which parameters; 1 everywhere without a mask), g: 1 on
// a wall (Inside only / Outside only), b: a thin strip along the outline (the seeds of Outline), a: the mode ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D K;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 k = texelFetch(K, ivec2(fragCoord), 0);
    float m = k.r;
    bool none = k.a > 3.5;
    float wall = 0.0;
    if (!none && mask_role == 1) wall = 1.0 - step(0.5, m);
    else if (!none && mask_role == 2) wall = step(0.5, m);
    // the outline: a tap a few pixels away on the other side
    float r = rd_cells(4.0) + 1.0;
    float lo = 1.0;
    float hi = 0.0;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * (MP_TAU / 8.0);
        float v = mp_bilinear(K, fragCoord + vec2(cos(a), sin(a)) * r).r;
        lo = min(lo, v);
        hi = max(hi, v);
    }
    float band = none ? 0.0 : step(0.5, hi) * (1.0 - step(0.5, lo));
    fragColor = vec4(none ? 1.0 : m, wall, band, k.a);   // no mask: all of it is "inside"
}
