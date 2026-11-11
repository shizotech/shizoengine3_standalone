//@settings dtype=float32 format=rgba
// --- MaskReaction, pass R: the pattern lit at full size, in linear light (rl_render in lib/relief.glsl) ---
#include lib/common.glsl
#include lib/relief.glsl

uniform sampler2D H;
uniform sampler2D L;
uniform sampler2D T;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = rl_render(H, L, mp_pulse(T), fragCoord);
}
