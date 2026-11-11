//@settings dtype=float32 format=rgba renderscale=0.125
// --- Datamosh, pass V: the motion of each block, in pixels of G a frame (from where it was to where it is) ---
// Block matching: 16 points around the block now against the frame before, moved by a candidate; the three-step
// search starts at the vector the block had in the last frame (W, smoothed) and tries no motion, then halves the
// step. A candidate far from the last vector costs a little more (the motion of a thing goes on), and a flat block
// (white wall, black sky) that cannot tell one move from another keeps no motion. All texels of a big block compute
// the same block. W reads this pass and this pass reads W of the last frame (a cycle entered only through W).
#include lib/common.glsl

uniform sampler2D G;
uniform sampler2D W;

float gNow[16];

// The sum of absolute differences of the block (origin o, spacing sp in G pixels) against before, moved by v
float sad(vec2 o, float sp, vec2 v, vec2 gsz) {
    float s = 0.0;
    for (int k = 0; k < 16; k++) {
        vec2 q = o + (vec2(k % 4, k / 4) + 0.5) * sp - v;
        s += abs(gNow[k] - passBilinear(G, q / gsz).g);
    }
    return s;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 last = stateOr(texelFetch(W, ivec2(fragCoord), 0), vec4(0.0));
    if (iFrame < 3)
        last = vec4(0.0);
    vec2 gsz = vec2(textureSize(G, 0));
    vec2 full = gsz * 4.0;
    float bpx = blockPx(full.y);
    // the block of this texel, in pixels of the picture and of G
    vec2 px = (floor(fragCoord) + 0.5) * 8.0;
    vec2 block = floor(px / bpx);
    vec2 o = block * bpx / 4.0;
    float bg = bpx / 4.0;
    // the points span twice the block (centred on it): steadier than the block alone
    float sp = bg / 2.0;
    o -= vec2(bg * 0.5);
    float mean = 0.0;
    for (int k = 0; k < 16; k++) {
        gNow[k] = passBilinear(G, (o + (vec2(k % 4, k / 4) + 0.5) * sp) / gsz).r;
        mean += gNow[k] / 16.0;
    }
    float contrast = 0.0;
    for (int k = 0; k < 16; k++)
        contrast += abs(gNow[k] - mean);
    // the cost of a move away from the last vector, per pixel of G
    float lambda = 0.012;

    vec2 v;
    {
        // the three-step search around the best of: the vector of the last frame, no motion
        vec2 best = vec2(0.0);
        float bs = sad(o, sp, best, gsz) * 0.9 + lambda * length(last.xy);
        float s1 = sad(o, sp, last.xy, gsz);
        if (s1 < bs) {
            best = last.xy;
            bs = s1;
        }
        float stp = quality <= 1 ? 2.0 : (quality == 2 ? 4.0 : 8.0);
        stp *= max(1.0, full.y / 1080.0);
        for (int level = 0; level < 5; level++) {
            if (stp < 0.75)
                break;
            vec2 c = best;
            for (int j = 0; j < 9; j++) {
                if (j == 4)
                    continue;
                vec2 cand = c + (vec2(j % 3, j / 3) - 1.0) * stp;
                float s = sad(o, sp, cand, gsz) + lambda * length(cand - last.xy);
                if (s < bs) {
                    bs = s;
                    best = cand;
                }
            }
            stp *= 0.5;
        }
        // a flat block tells nothing: no motion
        v = best * smoothstep(0.15, 0.5, contrast);
    }
    fragColor = vec4(v, contrast, 1.0);
}
