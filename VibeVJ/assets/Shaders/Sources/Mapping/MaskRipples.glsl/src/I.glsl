//@settings dtype=float32 format=rgba rendersize=(1,1)
// --- MaskRipples, pass I: is a picture linked into Picture (r: 1). Asked here, where nothing else is read, and not in
// the passes that use the picture: they have other inputs, and an unlinked sampler there reads one of them (#880) ---
#include lib/common.glsl

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = vec4(textureSize(picture, 0).x > 1 ? 1.0 : 0.0, 0.0, 0.0, 1.0);
}
