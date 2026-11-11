//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskBeams, pass J1: step 1 of the jump flood (the nearest outline for every pixel) ---
#define PASS_SCALE 0.5
#include lib/mapping.glsl
#include lib/jfa.glsl

uniform sampler2D E;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = jfa_step(E, ivec2(fragCoord), 1);
}
