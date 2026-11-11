//@settings dtype=float32 format=rgba renderscale=0.25
// --- MaskReaction, pass B1: the bright parts of R at a quarter of the size (bloom, lib/relief.glsl) ---
#define PASS_SCALE 0.25
#include lib/common.glsl
#include lib/relief.glsl

uniform sampler2D R;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = rl_bloom_down(R, ivec2(fragCoord));
}
