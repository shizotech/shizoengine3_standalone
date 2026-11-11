//@settings dtype=float32 format=rgba renderscale=0.25
// --- RegionChase, pass L4: labels of the regions, step 4 of 4 a frame, one more step. Each texel takes the
// smallest label of its neighbours with the same key, then the label its label points to (pointer jumping), so
// every texel of a region ends up with the place of the same texel of it. (x, y: the label, z: the key) ---
#define PASS_SCALE 0.25
#include lib/common.glsl

uniform sampler2D L3;
uniform sampler2D M;


vec4 lab(ivec2 q) {
    ivec2 s = textureSize(L3, 0);
    if (q.x < 0 || q.y < 0 || q.x >= s.x || q.y >= s.y) return vec4(0.0);
    return texelFetch(L3, q, 0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 p = ivec2(fragCoord);
    float key = texelFetch(M, p, 0).r;
    if (key < 0.5) {
        fragColor = vec4(-1.0, -1.0, 0.0, 0.0);
        return;
    }
    vec4 me = lab(p);
    if (me.w < 0.5 || abs(me.z - key) > 0.5) {
        fragColor = vec4(vec2(p), key, 1.0);
        return;
    }
    vec2 best = me.xy;
    for (int i = 0; i < 4; i++) {
        ivec2 d = i == 0 ? ivec2(1, 0) : (i == 1 ? ivec2(-1, 0) : (i == 2 ? ivec2(0, 1) : ivec2(0, -1)));
        vec4 o = lab(p + d);
        if (o.w > 0.5 && abs(o.z - key) < 0.5 && rc_index(o.xy) < rc_index(best)) best = o.xy;
    }
    vec4 r = lab(ivec2(best));
    if (r.w > 0.5 && abs(r.z - key) < 0.5 && rc_index(r.xy) < rc_index(best)) best = r.xy;
    fragColor = vec4(best, key, 1.0);
}
