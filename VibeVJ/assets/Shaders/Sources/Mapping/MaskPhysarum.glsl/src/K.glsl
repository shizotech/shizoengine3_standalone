//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskPhysarum, pass K: the mask at the size of the simulation (r: 0..1, 1 = surface; a: the mode of
// lib/mask.glsl). It reads nothing but Mask, so it may ask whether a picture is linked (#880) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    int mode = mp_mask_mode();
    float m = mode >= 4 ? 0.0 : mp_mask(uv);
    fragColor = vec4(m, 0.0, 0.0, float(mode));
}
