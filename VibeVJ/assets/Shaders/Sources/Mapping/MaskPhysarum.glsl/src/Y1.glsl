//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskPhysarum, pass Y1: step 1, the agents step (ph_move in lib/common.glsl) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D X1;
uniform sampler2D M;
uniform sampler2D C;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = ph_move(X1, M, C, ivec2(fragCoord), 0);
}
