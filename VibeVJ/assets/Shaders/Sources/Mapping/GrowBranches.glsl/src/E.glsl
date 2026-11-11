//@settings dtype=float32 format=rgba renderscale=0.5
// --- GrowBranches, pass E: the seeds of the jump flood: every texel of wood or tip, with the radius of the branch
// there (z, texels) and 2 for a tip (w). Dead parts of a turn are left out ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D B2;
uniform sampler2D C;
uniform sampler2D S;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    gr_load(S);
    ivec2 p = ivec2(fragCoord);
    vec4 b = texelFetch(B2, p, 0);
    vec4 lk = texelFetch(C, p, 0);
    if (b.x < 0.5 || b.y < 0.0 || lk.y > 0.98) {
        fragColor = vec4(-1e4, -1e4, 0.0, 0.0);
        return;
    }
    fragColor = vec4(vec2(p) + 0.5, br_radius(b, gr_age(b.y)), b.x > 1.5 ? 2.0 : 1.0);
}
