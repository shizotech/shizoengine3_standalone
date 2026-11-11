//@settings dtype=float16 format=rgba renderscale=0.0625
// --- PointCloud, pass B2: B at a quarter of its size again, for the wide glow ---
#include lib/common.glsl

uniform sampler2D B;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = box4(B, fragCoord);
}
