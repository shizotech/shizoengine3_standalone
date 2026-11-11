//@settings dtype=float32 format=rgba renderscale=0.5
// --- GrowFrost, pass F4: step 4 of 6 of the phase field (ice and heat) (half size) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D F3;
uniform sampler2D M;
uniform sampler2D S;
uniform sampler2D T;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    gr_load(S);
    fragColor = frost_step(F3, M, T, ivec2(fragCoord), false);
}
