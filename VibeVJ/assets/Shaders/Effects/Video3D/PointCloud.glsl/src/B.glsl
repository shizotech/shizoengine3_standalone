//@settings dtype=float16 format=rgba renderscale=0.25
// --- PointCloud, pass B: the points at a quarter of the size, for the glow ---
#include lib/common.glsl

uniform sampler2D P;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = box4(P, fragCoord);
}
