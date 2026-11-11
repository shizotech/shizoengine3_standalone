//@settings dtype=float32 format=rgba renderscale=0.0625
// --- Optical flow, pass F2: the coarse flow, solved on G2 ---
#include lib/common.glsl

uniform sampler2D G2;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = vec4(lucasKanade(G2, fragCoord / iResolution.xy, vec2(0.0)), 1.0);
}
