//@settings dtype=float16 format=rgba renderscale=0.0625
// --- GaussianBlur, pass H2: the horizontal Gaussian on D2 ---
#include lib/common.glsl

uniform sampler2D D2;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float nodeHeight = iResolution.y * LEVEL2_SCALE;
    vec2 sig = blurSigma() * nodeHeight;
    if (levelWeights(max(sig.x, sig.y))[2] <= 0.0) {
        fragColor = vec4(0.0);          // not used at this radius
        return;
    }
    float s = levelSigma(sig.x, LEVEL2_EXTRA) / LEVEL2_SCALE;
    fragColor = gauss1D(D2, uv, vec2(1.0 / iResolution.x, 0.0), s);
}
