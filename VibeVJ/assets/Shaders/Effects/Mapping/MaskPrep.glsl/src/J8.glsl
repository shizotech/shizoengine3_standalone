//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskPrep, pass J8: step 8 of the jump flood (the nearest outline for every pixel) ---
#define PASS_SCALE 0.5
#include lib/mapping.glsl
#include lib/jfa.glsl

uniform sampler2D J7;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = jfa_step(J7, ivec2(fragCoord), 8);
}
