//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskPhysarum, pass M: what the mask means for the slime (Mask role). r: the mask, g: food 0..1, b: 1 where no
// agent may be (a wall), a: the mode of lib/mask.glsl. Food around objects: a strip of Food band pixels around
// every shape (a ring of taps on K finds it) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D K;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 p = ivec2(fragCoord);
    vec4 k = texelFetch(K, p, 0);
    float m = k.r;
    float food = 0.0;
    float wall = 0.0;
    if (mask_role == 0) {
        wall = step(0.5, m);
        // the strip around the shapes: how much of a ring of taps at the band's width lies on a shape
        float r = ph_cells(food_band);
        float near = 0.0;
        for (int i = 0; i < 16; i++) {
            float a = float(i) * (MP_TAU / 16.0);
            vec2 o = vec2(cos(a), sin(a));
            near = max(near, mp_bilinear(K, fragCoord + o * r).r);
            near = max(near, mp_bilinear(K, fragCoord + o * r * 0.5).r);
        }
        food = near * (1.0 - wall);
    } else if (mask_role == 1) {
        food = m;
    } else if (mask_role == 2) {
        wall = step(0.5, m);
    } else if (mask_role == 3) {
        wall = 1.0 - step(0.5, m);
        if (k.a > 3.5) wall = 0.0;   // no mask: no container
    }
    fragColor = vec4(m, food, wall, k.a);
}
