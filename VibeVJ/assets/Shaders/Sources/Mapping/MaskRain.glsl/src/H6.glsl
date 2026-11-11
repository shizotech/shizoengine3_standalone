//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskRain, pass H6: how far a drop falls from each texel before it hits a surface, step 6 of 10 of a
// doubling (min of the distance here and 32 + the distance 32 texels further along the fall): exact up to
// 63 texels after this step ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D H5;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 d = rn_dir();
    float here = texelFetch(H5, ivec2(fragCoord), 0).r;
    float there = rn_fetch(H5, fragCoord + d * 32.0);
    fragColor = vec4(min(here, 32.0 + there), 0.0, 0.0, 1.0);
}
