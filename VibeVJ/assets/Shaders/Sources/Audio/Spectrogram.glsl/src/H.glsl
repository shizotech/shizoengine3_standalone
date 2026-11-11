//@settings dtype=float32 format=rgba rendersize=(512,256)
// --- Spectrogram, pass H: the history of the sound ---
// One row per frame: row 0 is now, row 255 the oldest. Every band of the spectrum (or sample of the waveform) is a
// column, so the drawing pass can pick any frequency range. Every frame the rows move up by Scroll speed.
#include lib/common.glsl

uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 px = ivec2(fragCoord);
    if (iFrame < 2) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    if (freeze) {
        fragColor = stateOr(texelFetch(feedback, px, 0), vec4(0.0, 0.0, 0.0, 1.0));
        return;
    }
    int sp = clamp(scroll_speed, 1, 8);
    if (px.y >= sp) {
        fragColor = stateOr(texelFetch(feedback, px - ivec2(0, sp), 0), vec4(0.0, 0.0, 0.0, 1.0));
        return;
    }
    float v = signal == 1 ? 0.5 + 0.5 * audioSample(px.x) : audioBand(px.x);
    fragColor = vec4(v, 0.0, 0.0, 1.0);
}
