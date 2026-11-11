//@settings dtype=float16 format=rgba renderscale=0.03125
// --- TiltShift, pass P5: level 5 of the blur pyramid, half the size of P4 ---
#include lib/common.glsl

uniform sampler2D P4;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = downsample(P4, fragCoord / iResolution.xy);
}
