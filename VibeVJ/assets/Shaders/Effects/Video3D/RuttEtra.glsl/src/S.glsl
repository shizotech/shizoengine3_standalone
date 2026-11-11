//@settings dtype=float32 format=rgba rendersize=(4,1)
// --- RuttEtra, pass S: the music (lib/music.glsl says what the 4 pixels hold) ---
#include lib/music.glsl

uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = musicStatePixel(int(fragCoord.x), feedback);
}
