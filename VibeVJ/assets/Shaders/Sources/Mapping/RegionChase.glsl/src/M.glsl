//@settings dtype=float32 format=rgba renderscale=0.25
// --- RegionChase, pass M: the region key of every texel (a quarter of the size): 0 none, else the key ---
#define PASS_SCALE 0.25
#include lib/common.glsl

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = vec4(rc_key(fragCoord / iResolution.xy), 0.0, 0.0, 1.0);
}
