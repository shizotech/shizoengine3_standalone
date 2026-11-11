//@settings dtype=float16 format=rgba renderscale=0.125
// --- TiltShift, pass P3: level 3 of the blur pyramid, half the size of P2 ---
#include lib/common.glsl

uniform sampler2D P2;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = downsample(P2, fragCoord / iResolution.xy);
}
