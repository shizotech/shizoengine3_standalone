//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskReaction, pass H: the chemicals as a height field for lib/relief.glsl. r: height 0..1 (Gray-Scott: V,
// FitzHugh-Nagumo: the wave, BZ: the first chemical), g: where between Colour A and B (Two patterns: inside or
// outside, else the second chemical), a: glow where the height rises (the growing front, the wave front) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D feedback;
uniform sampler2D S8;
uniform sampler2D M;

float rd_height(vec4 s) {
    if (model == 0) return smoothstep(0.08, 0.42, s.y);
    if (model == 1) return clamp(s.x * 0.9 + s.y * 0.25, 0.0, 1.0);
    return smoothstep(0.05, 0.9, s.x);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 c = ivec2(fragCoord);
    ivec2 hi = ivec2(iResolution.xy) - 1;
    // a light 3 x 3 smoothing: the patterns are smooth already, this takes the last steps' grid out
    float h = 0.0;
    vec4 st = vec4(0.0);
    float ws = 0.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float w = (x == 0 ? 2.0 : 1.0) * (y == 0 ? 2.0 : 1.0);
            vec4 s = texelFetch(S8, clamp(c + ivec2(x, y), ivec2(0), hi), 0);
            h += rd_height(s) * w;
            st += s * w;
            ws += w;
        }
    }
    h /= ws;
    st /= ws;
    h = h * (2.0 - h);
    vec4 mm = texelFetch(M, c, 0);
    float g = mask_role == 0 ? mm.r : (model == 0 ? smoothstep(0.2, 0.6, 1.0 - st.x) : (model == 1 ? st.y * 1.5 : st.y));
    float last = (iFrame < 2 || textureSize(feedback, 0) != ivec2(iResolution.xy)) ? h : texelFetch(feedback, c, 0).r;
    float rise = clamp((h - last) * 25.0, 0.0, 1.0);
    fragColor = vec4(h, clamp(g, 0.0, 1.0), 0.0, rise);
}
