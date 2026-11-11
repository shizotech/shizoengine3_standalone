//@settings dtype=float16 format=rgba renderscale=0.0625
// --- Optical flow, pass G2: G at a quarter of its size again (a sixteenth of the picture) ---
#include lib/common.glsl

uniform sampler2D G;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = box4(G, fragCoord / iResolution.xy);
}
