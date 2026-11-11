//@settings dtype=float32 format=rgba rendersize=(1,1)
// --- Particles 2, pass T: the beat, as one pixel ---
// r: the time now, g: the time of the last frame, b: the beat envelope (1 at a new beat, then falls frame by frame),
// a: 1 in the frame a new beat starts. With fract(iTime) alone a stopped timeline that rests on a beat would fire
// the burst in every frame.
#include lib/common.glsl

uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 last = texture(feedback, vec2(0.5));
    float before = iFrame < 2 ? iTime : last.r;
    bool beat = floor(iTime) != floor(before) && iTime > before;
    float env = beat ? 1.0 : last.b * 0.85;
    fragColor = vec4(iTime, before, env, beat ? 1.0 : 0.0);
}
