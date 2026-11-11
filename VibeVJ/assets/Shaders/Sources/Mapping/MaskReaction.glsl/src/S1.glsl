//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskReaction, pass S1: step 1 of 8 a frame, plus the start, Restart and the seeds (rd_first in lib/common.glsl).
// It reads the last frame's S8: the cycle closes here. Only S8 of the cycle is read from outside it (H, main) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D S8;
uniform sampler2D M;
uniform sampler2D T;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = rd_first(S8, M, T, ivec2(fragCoord));
}
