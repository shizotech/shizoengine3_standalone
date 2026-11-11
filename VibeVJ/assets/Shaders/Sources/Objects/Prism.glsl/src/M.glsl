//@settings dtype=uint8 format=rgba rendersize=(1,1)
// --- pass M: is a picture linked into Background? r = 1 when it is. The only pass that asks, and it reads no other
// texture: an input nothing is linked to reads the texture unit of another input in a pass with other inputs, so
// pass A cannot ask itself (SHADER_GUIDE.MD section 5, #880). No #include: lib/common.glsl declares AUDIO ---
uniform sampler2D background;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = vec4(textureSize(background, 0).x > 1 ? 1.0 : 0.0, 0.0, 0.0, 1.0);
}
