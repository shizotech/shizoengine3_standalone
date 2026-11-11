//@settings dtype=float32 format=rgba rendersize=(1,1)
// --- Oscilloscope, pass T: the trigger and the level, as one pixel ---
// r: the sample the drawn wave starts at (Rising edge: where the wave crosses zero upwards, like the trigger of a
// real scope, so a steady tone stands still), g: the loudest sample of the last moments (for Auto gain), b: the beat
// envelope (1 at a new beat, then falling; it rests while a stopped timeline rests on a beat).
#include lib/common.glsl

uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 last = stateOr(texelFetch(feedback, ivec2(0), 0), vec4(0.0, 0.3, 0.0, iTime));
    if (iFrame < 2)
        last = vec4(0.0, 0.3, 0.0, iTime);
    float dt = clamp(iTimeDelta, 0.0, 0.1);

    float loud = 0.0;
    for (int i = 0; i < 512; i += 2)
        loud = max(loud, abs(audioSample(i)));
    float peak = max(loud, last.g * exp(-dt / 1.5));

    int win = clamp(window, 32, 480);
    float start = 0.0;
    if (trigger == 1) {
        float level = 0.05 * max(peak, 0.05);
        int last_k = min(512 - win - 2, 256);
        for (int k = 1; k <= last_k; k++) {
            if (audioSample(k - 1) < 0.0 && audioSample(k) >= 0.0 && audioSample(min(k + 6, 511)) > level) {
                start = float(k);
                break;
            }
        }
    }

    bool beat = floor(iTime) != floor(last.a) && iTime > last.a;
    float env = beat ? 1.0 : last.b * exp(-dt * 6.0);
    fragColor = vec4(start, peak, env, iTime);
}
