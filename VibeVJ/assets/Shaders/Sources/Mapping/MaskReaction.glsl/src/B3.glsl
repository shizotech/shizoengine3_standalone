//@settings dtype=float32 format=rgba renderscale=0.25
// --- MaskReaction, pass B3: the bloom blurred up and down ---
#define PASS_SCALE 0.25
#include lib/common.glsl
#include lib/relief.glsl

uniform sampler2D B2;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = rl_blur(B2, ivec2(fragCoord), ivec2(0, 1));
}
