//@settings dtype=float32 format=rgba renderscale=0.25
// --- MaskSand, pass B: the second step of the automaton in a frame (blocks from cell 1) ---
#define PASS_SCALE 0.25
#include lib/common.glsl

uniform sampler2D A;
uniform sampler2D M;
uniform sampler2D T;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 size = ivec2(iResolution.xy);
    if (iFrame < 2 || textureSize(A, 0) != size || clear_now) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 pl = mp_pulse(T);
    float shake = pulse_action == 2 ? pulse_amount * pl.x : 0.0;
    bool floor_open = ground == 1 || (pulse_action == 3 && pl.x > 0.3 * (1.0 - pulse_amount) + 0.05);
    fragColor = sd_step(A, M, ivec2(fragCoord), 1, uint(iFrame) * 2u + 1u, shake, floor_open, 0.0);
}
