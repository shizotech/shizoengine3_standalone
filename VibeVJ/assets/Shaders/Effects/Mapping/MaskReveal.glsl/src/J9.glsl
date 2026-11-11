//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskReveal, pass J9: step 9 of the jump flood (the nearest outline for every pixel) ---
#define PASS_SCALE 0.5
#include lib/mapping.glsl
#include lib/jfa.glsl

uniform sampler2D J8;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = jfa_step(J8, ivec2(fragCoord), 9);
}
