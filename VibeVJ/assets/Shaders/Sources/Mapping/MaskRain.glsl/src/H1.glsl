//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskRain, pass H1: how far a drop falls from each texel before it hits a surface, step 1 of 10 of a
// doubling (min of the distance here and 1 + the distance 1 texels further along the fall): exact up to
// 1 texels after this step ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D M;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 d = rn_dir();
    vec2 p = fragCoord;
    float here = texelFetch(M, ivec2(p), 0).r > 0.5 ? 0.0 : 1e5;
    vec2 q = p + d;
    float next = 1e5;
    ivec2 sz = textureSize(M, 0);
    ivec2 iq = ivec2(floor(q));
    if (iq.y < 0) next = ground ? 0.0 : 1e5;
    else if (iq.x >= 0 && iq.x < sz.x && iq.y < sz.y) next = texelFetch(M, iq, 0).r > 0.5 ? 0.0 : 1e5;
    fragColor = vec4(min(here, 1.0 + next), 0.0, 0.0, 1.0);
}
