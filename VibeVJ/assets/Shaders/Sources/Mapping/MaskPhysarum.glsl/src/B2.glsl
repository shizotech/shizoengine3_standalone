//@settings dtype=float32 format=rgba renderscale=0.25
// --- MaskPhysarum, pass B2: the bloom blurred across ---
#define PASS_SCALE 0.25
#include lib/common.glsl
#include lib/relief.glsl

uniform sampler2D B1;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = rl_blur(B1, ivec2(fragCoord), ivec2(1, 0));
}
