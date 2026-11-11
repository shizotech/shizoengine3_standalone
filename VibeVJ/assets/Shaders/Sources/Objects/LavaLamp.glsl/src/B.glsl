//@settings dtype=float16 format=rgba renderscale=0.25
// --- pass B: the bright parts of the picture A at a quarter of the size (each pixel the mean of 4 x 4) ---
#include lib/common.glsl

uniform sampler2D A;

vec3 bright(vec3 c) {
    c = min(c, vec3(64.0));
    float l = max(max(c.r, c.g), c.b);
    float k = clamp((l - 0.6) / 0.8, 0.0, 1.0);
    return c * (k * k * (3.0 - 2.0 * k));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 px = 1.0 / vec2(textureSize(A, 0));
    vec3 c = bright(passBilinear(A, uv + vec2(-1.0, -1.0) * px).rgb) + bright(passBilinear(A, uv + vec2(1.0, -1.0) * px).rgb)
           + bright(passBilinear(A, uv + vec2(-1.0, 1.0) * px).rgb) + bright(passBilinear(A, uv + vec2(1.0, 1.0) * px).rgb);
    fragColor = vec4(c * 0.25, 1.0);
}
