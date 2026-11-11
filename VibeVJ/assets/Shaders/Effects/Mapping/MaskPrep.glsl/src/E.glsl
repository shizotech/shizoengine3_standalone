//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskPrep, pass E: the seeds of the jump flood, on the outline of the mask (between the pixels where it crosses
// 0.5, so the outline is smooth although this pass is half the size) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D M;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = jfa_seed_mask(M, ivec2(fragCoord));
}
