//@settings dtype=float16 format=rgba renderscale=0.25
// --- GaussianBlur, pass D1: the input boxed down to a quarter of the size ---
#include lib/common.glsl

uniform sampler2D input;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = box4(input, fragCoord / iResolution.xy);
}
