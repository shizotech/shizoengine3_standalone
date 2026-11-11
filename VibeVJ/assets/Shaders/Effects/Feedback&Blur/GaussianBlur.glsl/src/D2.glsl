//@settings dtype=float16 format=rgba renderscale=0.0625
// --- GaussianBlur, pass D2: D1 boxed down once more, a sixteenth of the size ---
#include lib/common.glsl

uniform sampler2D D1;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = box4(D1, fragCoord / iResolution.xy);
}
