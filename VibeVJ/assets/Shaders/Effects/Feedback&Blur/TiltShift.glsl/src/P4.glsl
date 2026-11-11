//@settings dtype=float16 format=rgba renderscale=0.0625
// --- TiltShift, pass P4: level 4 of the blur pyramid, half the size of P3 ---
#include lib/common.glsl

uniform sampler2D P3;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = downsample(P3, fragCoord / iResolution.xy);
}
