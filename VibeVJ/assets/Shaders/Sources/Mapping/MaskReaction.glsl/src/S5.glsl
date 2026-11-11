//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskReaction, pass S5: step 5 of 8 a frame (a copy when Sim speed asks for fewer) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D S4;
uniform sampler2D M;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = rd_more(S4, M, ivec2(fragCoord), 5);
}
