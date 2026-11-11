//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskReaction, pass S2: step 2 of 8 a frame (a copy when Sim speed asks for fewer) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D S1;
uniform sampler2D M;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = rd_more(S1, M, ivec2(fragCoord), 2);
}
