//@settings dtype=float32 format=rgba renderscale=0.5
// --- EdgeSweep, pass M: the mask (r) and the blurred brightness of the input (g), at half size. It reads the input,
// so it takes the mode of the mask from pass N ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D N;          // which mask (pass N): see mp_mask_mode_from in lib/mask.glsl

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    mp_mask_mode_from(N);   // not textureSize(mask) here: this pass has other inputs (#880)
    vec2 uv = fragCoord / iResolution.xy;
    float m = edge_source == 0 ? 0.0 : mp_mask(uv);
    vec2 px = max(edge_detail, 0.5) / (iResolution.xy / PASS_SCALE);
    float l = 0.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float w = float((2 - abs(x)) * (2 - abs(y)));
            l += mp_luma(texture(input, uv + vec2(float(x), float(y)) * px).rgb) * w;
        }
    }
    fragColor = vec4(m, l / 16.0, 0.0, 1.0);
}
