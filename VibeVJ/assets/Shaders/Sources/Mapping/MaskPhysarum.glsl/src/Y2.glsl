//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskPhysarum, pass Y2: step 2, the agents step. The state of the frame: only this pass of the cycle is read
// from outside it (H, C and the main pass), so the cycle always closes at X1 and C (#586) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D X2;
uniform sampler2D M;
uniform sampler2D C;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = ph_move(X2, M, C, ivec2(fragCoord), 1);
}
