//@settings dtype=float32 format=rgba rendersize=(1,1)
// --- GrowCoral, pass N: which mask (r: the mode of lib/mask.glsl). The only pass besides M that asks whether a picture is
// linked into Mask: it reads no other texture, so the answer is right (#880) ---
#include lib/common.glsl

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = mp_mask_mode_pass();
}
