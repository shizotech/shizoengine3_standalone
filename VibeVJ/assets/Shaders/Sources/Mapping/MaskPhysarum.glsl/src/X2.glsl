//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskPhysarum, pass X2: step 2, the trail and the senses ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D Y1;
uniform sampler2D M;
uniform sampler2D T;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = ph_sense(Y1, M, T, ivec2(fragCoord), 1);
}
