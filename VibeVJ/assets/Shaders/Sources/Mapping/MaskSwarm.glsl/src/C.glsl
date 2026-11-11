//@settings dtype=float32 format=rgba rendersize=(1,1)
// --- MaskSwarm, pass C: how big the flock is, as the share of the cells with a boid, counted at 32 x 18 places of
// the last frame's B (new places every frame) and smoothed. B reads it to decide whether new boids appear; this pass
// reads B back, so it gets the last frame (the cycle closes here) ---
#include lib/common.glsl

uniform sampler2D feedback;
uniform sampler2D B;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 grid = textureSize(B, 0);
    float alive = 0.0;
    uint f = uint(iFrame);
    for (int y = 0; y < 18; y++) {
        for (int x = 0; x < 32; x++) {
            uint h = mp_hash(uint(x + y * 32) * 2654435761u ^ f * 40503u);
            vec2 jit = vec2(mp_rand(h), mp_rand(h + 1u));
            ivec2 p = ivec2((vec2(float(x), float(y)) + jit) / vec2(32.0, 18.0) * vec2(grid));
            if (texelFetch(B, clamp(p, ivec2(0), grid - 1), 0).r > 0.0) alive += 1.0;    // an empty texture (0) is no boid
        }
    }
    float share = alive / 576.0;
    float last = texelFetch(feedback, ivec2(0, 0), 0).r;
    fragColor = vec4(iFrame < 2 ? share : mix(last, share, 0.2), share, 0.0, 1.0);
}
