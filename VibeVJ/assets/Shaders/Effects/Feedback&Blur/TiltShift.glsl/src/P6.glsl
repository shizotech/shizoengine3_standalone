//@settings dtype=float16 format=rgba renderscale=0.015625
// --- TiltShift, pass P6: level 6 of the blur pyramid, half the size of P5 ---
#include lib/common.glsl

uniform sampler2D P5;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = downsample(P5, fragCoord / iResolution.xy);
}
