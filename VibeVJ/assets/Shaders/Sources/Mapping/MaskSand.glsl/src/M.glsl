//@settings dtype=float32 format=rgba renderscale=0.25
// --- MaskSand, pass M: the mask at a quarter of the size (r: 0..1, 1 = surface) ---
#define PASS_SCALE 0.25
#include lib/common.glsl

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = vec4(mp_mask(fragCoord / iResolution.xy), 0.0, 0.0, 1.0);
}
