//@settings dtype=float16 format=rgba renderscale=0.25
// --- Datamosh, pass G: the brightness of now (red) and before (green) at a quarter of the size ---
#include lib/common.glsl

uniform sampler2D P;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 base = ivec2(floor(fragCoord)) * 4;
    ivec2 mx = textureSize(P, 0) - 1;
    vec2 sum = vec2(0.0);
    for (int y = 0; y < 4; y++)
        for (int x = 0; x < 4; x++)
            sum += texelFetch(P, min(base + ivec2(x, y), mx), 0).zw;
    fragColor = vec4(sum / 16.0, 0.0, 1.0);
}
