//@settings dtype=float16 format=rgba renderscale=0.0625
// --- GaussianBlur, pass V2: the vertical Gaussian on H2 ---
#include lib/common.glsl

uniform sampler2D H2;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float nodeHeight = iResolution.y * LEVEL2_SCALE;
    vec2 sig = blurSigma() * nodeHeight;
    if (levelWeights(max(sig.x, sig.y))[2] <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    float s = levelSigma(sig.y, LEVEL2_EXTRA) / LEVEL2_SCALE;
    fragColor = gauss1D(H2, uv, vec2(0.0, 1.0 / iResolution.y), s);
}
