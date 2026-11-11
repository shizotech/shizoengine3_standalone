//@settings dtype=float32 format=rgba rendersize=(1,1)
// --- AudioDisplace, pass E: the levels of the sound, as one pixel ---
// r: Low (below 250 Hz), g: Mid (250 Hz to 4 kHz), b: High (above 4 kHz), each the mean of its bands, a: the loudest
// sample of the waveform. They follow the sound in Smoothing seconds, so the picture does not flicker.
#include lib/common.glsl

uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float a = freqToX(250.0), b = freqToX(4000.0);
    float loud = 0.0;
    for (int i = 0; i < 512; i += 4)
        loud = max(loud, abs(audioSample(i)));
    vec4 now = vec4(spectrumMean(0.0, a), spectrumMean(a, b), spectrumMean(b, 1.0), loud);
    vec4 last = stateOr(texelFetch(feedback, ivec2(0), 0), now);
    if (iFrame < 2 || smoothing <= 0.0005) {
        fragColor = now;
        return;
    }
    float dt = clamp(iTimeDelta, 0.0, 0.1);
    fragColor = mix(last, now, 1.0 - exp(-dt / smoothing));
}
