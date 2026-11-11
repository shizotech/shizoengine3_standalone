//@settings dtype=float16 format=rgba
// --- GaussianBlur, pass H: the horizontal half of the full-size blur (small radii) ---
#include lib/common.glsl

uniform sampler2D input;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 sig = blurSigma() * iResolution.y;
    if (levelWeights(max(sig.x, sig.y)).x <= 0.0) {
        fragColor = vec4(0.0);          // not used at this radius
        return;
    }
    fragColor = gauss1D(input, uv, vec2(1.0 / iResolution.x, 0.0), sig.x);
}
