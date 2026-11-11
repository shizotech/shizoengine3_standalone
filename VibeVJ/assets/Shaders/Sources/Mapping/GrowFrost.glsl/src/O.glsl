//@settings dtype=uint8 format=rgba rendersize=(1,1)
//@readout names=(life,turning,turn_pulse,coverage)
// --- GrowFrost, pass O: the values to link from (pure outputs under Values): life (the share grown / Turn at),
// turning (0..1 through a turn), turn pulse (1 when a turn begins, then it falls), coverage ---
#include lib/common.glsl

uniform sampler2D S;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = clamp(texelFetch(S, ivec2(3, 0), 0), 0.0, 1.0);
}
