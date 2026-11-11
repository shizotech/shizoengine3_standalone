//@settings dtype=uint8 format=rgba rendersize=(1,1)
// --- SlitScan, pass N: 1 while something is linked into Time map. An input nothing is linked to is tested in a pass
// where it is the only input (SHADER_GUIDE.MD section 5: in a pass with other inputs it can read one of them) ---

// Its brightness is how far back each pixel looks (Time mode Time map): black = now, white = the oldest frame
uniform sampler2D time_map;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = vec4(textureSize(time_map, 0).x > 1 ? 1.0 : 0.0, 0.0, 0.0, 1.0);
}
