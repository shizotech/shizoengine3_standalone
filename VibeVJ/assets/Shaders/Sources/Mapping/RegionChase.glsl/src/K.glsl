//@settings dtype=float32 format=rgba rendersize=(1,1)
// --- RegionChase, pass K: did the mask change? A checksum of the keys on a grid of 32 x 18 texels; when it changes,
// the labels and boxes start again (r: checksum, g: 1 in a frame of a change) ---
#include lib/common.glsl

uniform sampler2D M;
uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 s = textureSize(M, 0);
    float sum = 0.0;
    for (int j = 0; j < 18; j++) {
        for (int i = 0; i < 32; i++) {
            ivec2 q = ivec2((vec2(float(i), float(j)) + 0.5) / vec2(32.0, 18.0) * vec2(s));
            sum += texelFetch(M, q, 0).r * float(1 + (i * 7 + j * 13) % 29);
        }
    }
    float last = texelFetch(feedback, ivec2(0), 0).r;
    bool changed = iFrame < 3 || abs(sum - last) > 0.5;
    fragColor = vec4(sum, changed ? 1.0 : 0.0, 0.0, 1.0);
}
