//@settings dtype=float32 format=rgba rendersize=(2,1)
// --- MaskSand, pass T: the pulse of the beat and of the trigger, in two pixels (lib/beat.glsl) ---
#include lib/common.glsl

uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = mp_beat_pass(feedback, ivec2(fragCoord));
}
