//@settings dtype=float32 format=rgba renderscale=0.25
// --- MaskReaction, pass L: the height blurred at a quarter of the size, wide (about 25 pixels at 1080p: occlusion,
// thickness) and narrow (about 6 pixels: crevices), and how long each place has been covered (new growth glows, what
// stays gets darker; rl_age_pass in lib/relief.glsl, #892) ---
#define PASS_SCALE 0.25
#include lib/common.glsl
#include lib/relief.glsl

uniform sampler2D feedback;
uniform sampler2D H;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = rl_age_pass(H, feedback, fragCoord);
}
