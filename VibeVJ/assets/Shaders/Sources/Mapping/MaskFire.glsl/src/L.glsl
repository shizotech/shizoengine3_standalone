//@settings dtype=float32 format=rgba renderscale=0.0625
// --- MaskFire, pass L: the heat at a sixteenth of the size, averaged: the light of the flames on the objects
// (Obstacle view Lit by the fire) ---
#define PASS_SCALE 0.0625
#include lib/common.glsl

uniform sampler2D H;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 hres = textureSize(H, 0);
    vec2 f = vec2(hres) / iResolution.xy;            // texels of H in one texel of this pass
    vec2 base = fragCoord * f;
    float sum = 0.0;
    for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
            vec2 q = base + (vec2(float(x), float(y)) - 1.5) * f * 0.5;
            sum += texelFetch(H, clamp(ivec2(q), ivec2(0), hres - 1), 0).r;
        }
    }
    fragColor = vec4(sum / 16.0, 0.0, 0.0, 1.0);
}
