//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskPhysarum, pass X1: step 1, the trail and the senses (ph_sense in lib/common.glsl). It reads the state of the
// last frame (Y2: the cycle closes here); the first frames and Restart lay out the agents ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D Y2;
uniform sampler2D M;
uniform sampler2D T;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = ph_sense(Y2, M, T, ivec2(fragCoord), 0);
}
