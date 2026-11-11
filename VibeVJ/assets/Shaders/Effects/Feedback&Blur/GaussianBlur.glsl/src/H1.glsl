//@settings dtype=float16 format=rgba renderscale=0.25
// --- GaussianBlur, pass H1: the horizontal Gaussian on D1 ---
#include lib/common.glsl

uniform sampler2D D1;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float nodeHeight = iResolution.y * LEVEL1_SCALE;
    vec2 sig = blurSigma() * nodeHeight;
    if (levelWeights(max(sig.x, sig.y))[1] <= 0.0) {
        fragColor = vec4(0.0);          // not used at this radius
        return;
    }
    float s = levelSigma(sig.x, LEVEL1_EXTRA) / LEVEL1_SCALE;
    fragColor = gauss1D(D1, uv, vec2(1.0 / iResolution.x, 0.0), s);
}
