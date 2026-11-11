//@settings dtype=float16 format=rgba renderscale=0.25
// --- TiltShift, pass P2: level 2 of the blur pyramid, half the size of P1 ---
#include lib/common.glsl

uniform sampler2D P1;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = downsample(P1, fragCoord / iResolution.xy);
}
