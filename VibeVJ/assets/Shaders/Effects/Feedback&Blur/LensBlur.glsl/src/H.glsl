//@settings dtype=float16 format=rgba renderscale=0.25
// --- LensBlur, pass H: the brightest highlight among the 4 x 4 input pixels of each texel (linear light) ---
// A mean would dim a small light 16 times, so that it no longer counts as a highlight: the maximum keeps it.
#include lib/common.glsl

uniform sampler2D input;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 px = 1.0 / vec2(textureSize(input, 0));
    vec3 best = vec3(0.0);
    float bestL = 0.0;
    for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
            vec3 h = highlightPart(srgbToLinear(texture(input, uv + (vec2(x, y) - 1.5) * px).rgb));
            float l = luminance(h);
            if (l > bestL) {
                bestL = l;
                best = h;
            }
        }
    }
    fragColor = vec4(best, 1.0);
}
