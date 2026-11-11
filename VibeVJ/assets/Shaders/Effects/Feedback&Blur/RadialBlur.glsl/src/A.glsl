//@settings dtype=float16 format=rgba
// --- RadialBlur, pass A: the first short piece of each streak, in linear light ---
// rgb: the weighted sum of the colours, a: the sum of the weights (__init__ divides)
#include lib/common.glsl

uniform sampler2D input;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    int n = tapCount();
    float stepT = 1.0 / float(n * n);
    vec2 c = blurCenter();
    vec2 rate = blurRate();
    float k = falloffRate();
    vec4 sum = vec4(0.0);
    for (int j = 0; j < 32; j++) {
        if (j >= n)
            break;
        float t = float(j) * stepT;
        sum += exp(-k * t) * tapValue(srgbToLinear(texture(input, blurAt(uv, c, rate, t)).rgb));
    }
    fragColor = sum;
}
