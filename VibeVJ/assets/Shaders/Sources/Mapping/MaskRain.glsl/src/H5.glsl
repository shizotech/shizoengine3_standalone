//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskRain, pass H5: how far a drop falls from each texel before it hits a surface, step 5 of 10 of a
// doubling (min of the distance here and 16 + the distance 16 texels further along the fall): exact up to
// 31 texels after this step ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D H4;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 d = rn_dir();
    float here = texelFetch(H4, ivec2(fragCoord), 0).r;
    float there = rn_fetch(H4, fragCoord + d * 16.0);
    fragColor = vec4(min(here, 16.0 + there), 0.0, 0.0, 1.0);
}
