//@settings dtype=float16 format=rgba renderscale=0.5
// --- TiltShift, pass P1: level 1 of the blur pyramid, half the size of input ---
#include lib/common.glsl

uniform sampler2D input;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = downsample(input, fragCoord / iResolution.xy);
}
