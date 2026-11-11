//@settings dtype=float32 format=rgba rendersize=(128,1)
// --- Spectrum, pass S: one pixel per bar ---
// r: the level of the bar (0 .. 1, after Gain, Curve, Rise and Fall), g: the height of its peak cap, b: seconds the
// cap still hangs. Worked out once a frame, so the drawing pass reads only 1 to 4 pixels of it per pixel.
#include lib/common.glsl

uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    int i = int(fragCoord.x);
    int n = clamp(bar_count, 2, 128);
    if (i >= n) {
        fragColor = vec4(0.0);
        return;
    }
    float lo = freqToX(low_freq);
    float hi = max(freqToX(high_freq), lo + 0.01);
    float a = mix(lo, hi, float(i) / float(n));
    float b = mix(lo, hi, float(i + 1) / float(n));
    float v = pow(clamp(spectrumMax(a, b) * gain, 0.0, 1.0), curve);

    vec4 last = stateOr(texelFetch(feedback, ivec2(i, 0), 0), vec4(0.0));
    if (iFrame < 2)
        last = vec4(0.0);
    float dt = clamp(iTimeDelta, 0.0, 0.1);
    float t = v > last.r ? rise : fall;
    float level = t <= 0.0005 ? v : mix(last.r, v, 1.0 - exp(-dt / t));

    float peak = last.g;
    float hold = last.b - dt;
    if (level >= peak) {
        peak = level;
        hold = peak_hold;
    } else if (hold <= 0.0) {
        peak = max(level, peak - peak_fall * dt);
        hold = 0.0;
    }
    fragColor = vec4(level, peak, hold, 1.0);
}
