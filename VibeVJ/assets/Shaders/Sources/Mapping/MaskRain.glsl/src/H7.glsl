//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskRain, pass H7: how far a drop falls from each texel before it hits a surface, step 7 of 10 of a
// doubling (min of the distance here and 64 + the distance 64 texels further along the fall): exact up to
// 127 texels after this step ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D H6;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 d = rn_dir();
    float here = texelFetch(H6, ivec2(fragCoord), 0).r;
    float there = rn_fetch(H6, fragCoord + d * 64.0);
    fragColor = vec4(min(here, 64.0 + there), 0.0, 0.0, 1.0);
}
