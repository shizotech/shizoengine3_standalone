//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskRain, pass H3: how far a drop falls from each texel before it hits a surface, step 3 of 10 of a
// doubling (min of the distance here and 4 + the distance 4 texels further along the fall): exact up to
// 7 texels after this step ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D H2;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 d = rn_dir();
    float here = texelFetch(H2, ivec2(fragCoord), 0).r;
    float there = rn_fetch(H2, fragCoord + d * 4.0);
    fragColor = vec4(min(here, 4.0 + there), 0.0, 0.0, 1.0);
}
