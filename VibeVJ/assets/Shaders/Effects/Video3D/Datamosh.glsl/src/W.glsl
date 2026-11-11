//@settings dtype=float32 format=rgba renderscale=0.125
// --- Datamosh, pass W: the vectors of V, each the median of the 3 x 3 blocks around it (one odd vector does not
// tear the picture), or the last ones again while Hold vectors is on ---
#include lib/common.glsl

uniform sampler2D V;
uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 last = stateOr(texelFetch(feedback, ivec2(fragCoord), 0), vec4(0.0));
    if (hold_vectors && iFrame > 2) {
        fragColor = last;
        return;
    }
    ivec2 sz = textureSize(V, 0);
    // a neighbour block is this many texels of V away
    int stp = max(1, int(blockPx(float(sz.y) * 8.0) / 8.0 + 0.5));
    ivec2 p = ivec2(fragCoord);
    vec2 v[9];
    for (int k = 0; k < 9; k++)
        v[k] = texelFetch(V, clamp(p + (ivec2(k % 3, k / 3) - 1) * stp, ivec2(0), sz - 1), 0).xy;
    // the vector median: the one closest to all others
    int best = 4;
    float bd = 1e9;
    for (int i = 0; i < 9; i++) {
        float d = 0.0;
        for (int j = 0; j < 9; j++)
            d += length(v[i] - v[j]);
        if (d < bd) {
            bd = d;
            best = i;
        }
    }
    fragColor = vec4(v[best], 0.0, 1.0);
}
