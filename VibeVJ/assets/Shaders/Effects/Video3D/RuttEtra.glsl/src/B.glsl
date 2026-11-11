//@settings dtype=float16 format=rgba renderscale=0.25
// --- RuttEtra, pass B: the lines at a quarter of the size, for the glow ---
#include lib/common.glsl

uniform sampler2D L;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = box4(L, fragCoord);
}
