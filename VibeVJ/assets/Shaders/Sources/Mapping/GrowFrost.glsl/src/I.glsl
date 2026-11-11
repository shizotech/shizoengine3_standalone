//@settings dtype=float32 format=rgba rendersize=(1,1)
// --- GrowFrost, pass I: is a picture linked into Seed picture (r: 1). Asked here, where nothing else is read, and not in
// the pass that plants the seeds (lib/growth.glsl, #880) ---
#include lib/common.glsl

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = gr_seed_picture_pass();
}
