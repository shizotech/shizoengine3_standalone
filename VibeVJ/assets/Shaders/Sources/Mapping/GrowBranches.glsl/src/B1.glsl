//@settings dtype=float32 format=rgba renderscale=0.5
// --- GrowBranches, pass B1: step 1 of 2 of the growing tips (half size); starts from the last frame (B2) and plants the seeds ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D B2;
uniform sampler2D M;
uniform sampler2D S;
uniform sampler2D T;
uniform sampler2D I;          // is a seed picture linked (pass I): see gr_seed_picture_from in lib/growth.glsl

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    gr_seed_picture_from(I);   // not textureSize(seed_picture) here: this pass has other inputs (#880)
    gr_load(S);
    fragColor = br_step(B2, M, T, ivec2(fragCoord), true);
}
