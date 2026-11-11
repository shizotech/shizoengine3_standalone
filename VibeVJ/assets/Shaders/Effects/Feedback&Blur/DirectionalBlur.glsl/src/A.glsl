//@settings dtype=float16 format=rgba
// --- DirectionalBlur, pass A: the first short piece of the line, weighted, in linear light ---
// rgb: the weighted sum of the colours, a: the sum of the weights (__init__ divides)
#include lib/common.glsl

uniform sampler2D input;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    int n = tapCount();
    float stepT = 1.0 / float(n * n);
    vec2 v = blurVector(uv);
    float k = falloffRate();
    vec4 sum = vec4(0.0);
    for (int j = 0; j < 32; j++) {
        if (j >= n)
            break;
        float t = float(j) * stepT;
        vec3 c = srgbToLinear(texture(input, uv - v * t).rgb);
        float w = exp(-k * t) * highlightWeight(c);
        sum += vec4(c * w, w);
    }
    fragColor = sum;
}
