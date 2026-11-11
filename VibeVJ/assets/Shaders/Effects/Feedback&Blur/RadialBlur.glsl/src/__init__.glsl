// --- RadialBlur: zoom blur, spin blur and light rays around a center (the Radial Blur of TouchDesigner) ---
// lib/common.glsl says how the two passes work together.
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D A;

//@slider min=0.0 max=1.0 value=1.0
uniform float amount;               // mixes back to the input

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 src = texture(input, uv);
    vec2 rate = blurRate();
    if ((abs(rate.x) < 1e-4 && abs(rate.y) < 1e-4) || amount <= 0.0) {
        fragColor = src;
        return;
    }
    int n = tapCount();
    float stepT = 1.0 / float(n);
    float t0 = startOffset();
    float k = falloffRate();
    vec2 c = blurCenter();
    vec4 sum = vec4(0.0);
    for (int i = 0; i < 32; i++) {
        if (i >= n)
            break;
        float t = t0 + float(i) * stepT;
        sum += exp(-k * (t - t0)) * texture(A, blurAt(uv, c, rate, t));
    }
    vec3 lin = sum.rgb / max(sum.a, 1e-5);
    vec3 col;
    if (output_mode == 1)
        col = linearToSrgb(srgbToLinear(src.rgb) + lin * ray_gain);
    else
        col = linearToSrgb(lin);
    col += (interleavedGradientNoise(floor(fragCoord)) - 0.5) / 255.0;
    fragColor = vec4(mix(src.rgb, clamp(col, 0.0, 1.0), amount), src.a);
}
