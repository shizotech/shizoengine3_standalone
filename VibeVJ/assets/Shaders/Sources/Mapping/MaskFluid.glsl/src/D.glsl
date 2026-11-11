//@settings dtype=float32 format=rgba renderscale=0.25
// --- MaskFluid, pass D: the divergence of the velocity (how much flows out of a texel); a wall does not move ---
#define PASS_SCALE 0.25
#include lib/common.glsl

uniform sampler2D U;
uniform sampler2D M;

vec2 vel(ivec2 q) {
    if (fl_wall(M, q)) return vec2(0.0);
    return fl_fetch(U, q).xy;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 p = ivec2(fragCoord);
    float div = 0.5 * (vel(p + ivec2(1, 0)).x - vel(p - ivec2(1, 0)).x + vel(p + ivec2(0, 1)).y - vel(p - ivec2(0, 1)).y);
    fragColor = vec4(div, 0.0, 0.0, 1.0);
}
