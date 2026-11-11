//@settings dtype=float32 format=rgba renderscale=0.25
// --- RegionChase, pass B1: the box around each region (min x, min y, max x, max y in texels), step 1 of 4
// a frame: the union of the boxes of the texels 8 away that have the same label (L4), and of the box of the
// texel the label points to. Starts from the boxes of the last frame (B4), or from scratch when the mask changed ---
#define PASS_SCALE 0.25
#include lib/common.glsl

uniform sampler2D B4;
uniform sampler2D L4;
uniform sampler2D K;

vec4 box_union(vec4 a, vec4 b) {
    if (b.z < b.x) return a;
    return vec4(min(a.xy, b.xy), max(a.zw, b.zw));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 p = ivec2(fragCoord);
    ivec2 s = textureSize(L4, 0);
    vec4 lp = texelFetch(L4, p, 0);
    if (lp.w < 0.5) {
        fragColor = vec4(0.0, 0.0, -1.0, -1.0);
        return;
    }
    vec4 bb = vec4(vec2(p), vec2(p));
    if (texelFetch(K, ivec2(0), 0).g < 0.5 && iFrame >= 3) bb = box_union(bb, texelFetch(B4, p, 0));
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            ivec2 q = p + ivec2(x, y) * 8;
            if ((x == 0 && y == 0) || q.x < 0 || q.y < 0 || q.x >= s.x || q.y >= s.y) continue;
            vec4 lq = texelFetch(L4, q, 0);
            if (lq.w > 0.5 && all(equal(lq.xy, lp.xy)) && texelFetch(K, ivec2(0), 0).g < 0.5) bb = box_union(bb, texelFetch(B4, q, 0));
        }
    }
    if (texelFetch(K, ivec2(0), 0).g < 0.5) bb = box_union(bb, texelFetch(B4, ivec2(lp.xy), 0));
    fragColor = bb;
}
