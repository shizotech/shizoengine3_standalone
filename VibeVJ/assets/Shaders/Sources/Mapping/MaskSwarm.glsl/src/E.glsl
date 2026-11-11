//@settings dtype=float32 format=rgba renderscale=0.25
// --- MaskSwarm, pass E: the seeds of the jump flood, on the outline of the mask (between the pixels where it crosses
// 0.5, so the outline is smooth although this pass is smaller than the picture) ---
#define PASS_SCALE 0.25
#include lib/common.glsl

uniform sampler2D M;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = mp_mask_mode() == 4 ? vec4(-1e4, -1e4, 0.0, 0.0) : jfa_seed_mask(M, ivec2(fragCoord));
}
