//@settings dtype=float16 format=rgba renderscale=0.25
// --- GaussianBlur, pass V1: the vertical Gaussian on H1 ---
#include lib/common.glsl

uniform sampler2D H1;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float nodeHeight = iResolution.y * LEVEL1_SCALE;
    vec2 sig = blurSigma() * nodeHeight;
    if (levelWeights(max(sig.x, sig.y))[1] <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    float s = levelSigma(sig.y, LEVEL1_EXTRA) / LEVEL1_SCALE;
    fragColor = gauss1D(H1, uv, vec2(0.0, 1.0 / iResolution.y), s);
}
