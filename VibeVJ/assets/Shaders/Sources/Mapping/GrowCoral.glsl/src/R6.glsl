//@settings dtype=float32 format=rgba renderscale=0.5
// --- GrowCoral, pass R6: step 6 of 6 of the reaction and diffusion (half size) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D R5;
uniform sampler2D M;
uniform sampler2D S;
uniform sampler2D T;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    gr_load(S);
    fragColor = rd_step(R5, M, T, ivec2(fragCoord), false);
}
