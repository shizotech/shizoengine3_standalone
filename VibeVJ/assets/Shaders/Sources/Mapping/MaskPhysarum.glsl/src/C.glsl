//@settings dtype=float32 format=rgba rendersize=(1,1)
// --- MaskPhysarum, pass C: how many agents there are, as the share of the free cells with one, counted at 32 x 18
// places of the last frame's Y2 (new places every frame) and smoothed. Y1 and Y2 read it to decide whether new agents
// appear; it reads Y2 back, so it gets the last frame (the cycle closes here and in X1) ---
#include lib/common.glsl

uniform sampler2D feedback;
uniform sampler2D Y2;
uniform sampler2D M;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 grid = textureSize(Y2, 0);
    ivec2 mg = textureSize(M, 0);
    float alive = 0.0;
    float free_cells = 0.0;
    uint f = uint(iFrame);
    for (int y = 0; y < 18; y++) {
        for (int x = 0; x < 32; x++) {
            uint h = mp_hash(uint(x + y * 32) * 2654435761u ^ f * 40503u);
            vec2 jit = vec2(mp_rand(h), mp_rand(h + 1u));
            vec2 u = (vec2(float(x), float(y)) + jit) / vec2(32.0, 18.0);
            ivec2 p = clamp(ivec2(u * vec2(grid)), ivec2(0), grid - 1);
            ivec2 q = clamp(ivec2(u * vec2(mg)), ivec2(0), mg - 1);
            if (texelFetch(M, q, 0).b > 0.5) continue;
            free_cells += 1.0;
            if (texelFetch(Y2, p, 0).a > 0.5) alive += 1.0;
        }
    }
    float share = alive / max(free_cells, 1.0);
    float last = texelFetch(feedback, ivec2(0, 0), 0).r;
    fragColor = vec4(iFrame < 2 ? share : mix(last, share, 0.15), share, free_cells, 1.0);
}
