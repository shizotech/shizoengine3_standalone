//@settings dtype=float32 format=rgba renderscale=0.5
// --- GrowMoss, pass G2: step 2 of 2 of the spreading (half size) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D G1;
uniform sampler2D M;
uniform sampler2D S;
uniform sampler2D T;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    gr_load(S);
    fragColor = moss_step(G1, M, T, ivec2(fragCoord), false);
}
