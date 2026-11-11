// --- Spectrum, shared part of both passes: the sound, and the controls pass S needs ---
// ---- The sound: the texture of the audio analysis (AudioInputAnalysis) ----
// A shader with a sampler named AUDIO gets it by itself while an audio analysis runs (or a link into the port Audio).
// Row 0: the spectrum, 512 bands from 20 Hz to half the sample rate, log spaced, 0 .. 1. Row 1: the waveform, 512
// samples, -1 .. 1. Without it the Test signal plays a made-up beat, so the preview moves.
uniform sampler2D AUDIO;
uniform int AUDIO_ON;               // set by the engine: 1 while AUDIO has a picture (no control)

//@enum options=(Auto, Off, Always) value=0
uniform int test_signal;            // Auto: a made-up beat while no audio analysis runs. Off: silence then

const float AUDIO_TAU = 6.28318530718;

uint audioHash(uint v) {
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}
float audioHash01(int a, int b) {
    return float(audioHash(uint(a) * 1597u + audioHash(uint(b))) >> 8u) * (1.0 / 16777216.0);
}

// A value of the last frame, or `fallback` when it is no number: a fresh texture can hold anything, and one NaN in a
// feedback stays there for good
vec4 stateOr(vec4 v, vec4 fallback) {
    return (any(isnan(v)) || any(isinf(v))) ? fallback : v;
}

bool audioDemo() {
    return test_signal == 2 || (test_signal == 0 && AUDIO_ON == 0);
}

// Where a frequency (Hz) lies on the spectrum row, 0 .. 1 (log spaced from 20 Hz to 24 kHz, a 48 kHz sound card)
float freqToX(float hz) {
    return clamp(log(max(hz, 20.0) / 20.0) / log(1200.0), 0.0, 1.0);
}

// The made-up beat: a kick on every beat, a snare on 2 and 4, hats between the beats, a moving melody
float demoBand(int i) {
    float x = float(i) / 511.0;
    float t = iTime;
    float kick = exp(-fract(t) * 7.0);
    float snare = exp(-fract(t * 0.5 + 0.5) * 8.0);
    float hat = exp(-fract(t + 0.5) * 16.0);
    float v = 0.28 * (1.0 - 0.6 * x);
    v += 1.05 * kick * exp(-pow((x - 0.13) / 0.07, 2.0));
    v += 0.65 * snare * exp(-pow((x - 0.5) / 0.16, 2.0));
    v += 0.55 * hat * smoothstep(0.68, 0.88, x) * (1.0 - smoothstep(0.95, 1.0, x));
    v += 0.4 * pow(0.5 + 0.5 * sin(x * 47.0 + t * 1.9), 3.0) * (0.5 + 0.5 * sin(x * 11.0 - t * 0.7))
         * exp(-pow((x - 0.42) / 0.17, 2.0));
    // a little noise that changes 12 times a beat, smooth across the bands
    float nx = x * 40.0;
    int tf = int(floor(t * 12.0));
    float fn = fract(nx);
    v += 0.14 * mix(audioHash01(int(floor(nx)), tf), audioHash01(int(floor(nx)) + 1, tf), fn * fn * (3.0 - 2.0 * fn));
    return clamp(v, 0.0, 1.0);
}
float demoSample(int i) {
    float p = float(i) / 512.0;
    float t = iTime;
    float kick = exp(-fract(t) * 5.0);
    return clamp(0.55 * (0.3 + kick) * sin(AUDIO_TAU * (p * 3.0 + t * 0.37))
         + 0.22 * sin(AUDIO_TAU * (p * 17.0 + t * 1.3))
         + 0.1 * sin(AUDIO_TAU * (p * 43.0 - t * 0.9)) * exp(-fract(t + 0.5) * 6.0), -1.0, 1.0);
}

// Band i of the spectrum (0 .. 511), 0 .. 1
float audioBand(int i) {
    i = clamp(i, 0, 511);
    if (audioDemo())
        return test_signal == 1 ? 0.0 : demoBand(i);
    return clamp(texelFetch(AUDIO, ivec2(i, 0), 0).r, 0.0, 1.0);
}
// The spectrum at x (0 .. 1 from low to high), between the bands
float spectrumAt(float x) {
    float f = clamp(x, 0.0, 1.0) * 511.0;
    int i = int(floor(f));
    return mix(audioBand(i), audioBand(i + 1), f - float(i));
}
// Sample i of the waveform (0 .. 511), -1 .. 1
float audioSample(int i) {
    i = clamp(i, 0, 511);
    if (audioDemo())
        return test_signal == 1 ? 0.0 : demoSample(i);
    return clamp(texelFetch(AUDIO, ivec2(i, 1), 0).r, -1.0, 1.0);
}
// The waveform at sample position s (0 .. 511), between the samples
float waveAt(float s) {
    float f = clamp(s, 0.0, 511.0);
    int i = int(floor(f));
    return mix(audioSample(i), audioSample(i + 1), f - float(i));
}
// The loudest band between two points of the spectrum (x 0 .. 1), at most 64 bands looked at
float spectrumMax(float a, float b) {
    float fa = clamp(min(a, b), 0.0, 1.0) * 511.0, fb = clamp(max(a, b), 0.0, 1.0) * 511.0;
    if (fb - fa < 1.0)
        return spectrumAt((a + b) * 0.5);
    int ia = int(floor(fa)), ib = int(ceil(fb));
    int stp = max(1, (ib - ia) / 64);
    float v = 0.0;
    for (int k = ia; k <= ib; k += stp)
        v = max(v, audioBand(k));
    return v;
}
// The mean of the bands between two points of the spectrum (x 0 .. 1), at most 48 bands looked at
float spectrumMean(float a, float b) {
    float fa = clamp(min(a, b), 0.0, 1.0) * 511.0, fb = clamp(max(a, b), 0.0, 1.0) * 511.0;
    if (fb - fa < 1.0)
        return spectrumAt((a + b) * 0.5);
    int ia = int(floor(fa)), ib = int(ceil(fb));
    int stp = max(1, (ib - ia) / 48);
    float v = 0.0, n = 0.0;
    for (int k = ia; k <= ib; k += stp) {
        v += audioBand(k);
        n += 1.0;
    }
    return v / max(n, 1.0);
}

//@int min=2 max=128 value=48
uniform int bar_count;              // how many bars (or points of the curve)
//@slider min=20.0 max=2000.0 value=35.0
uniform float low_freq;             // the frequency of the first bar, Hz
//@slider min=200.0 max=20000.0 value=14000.0
uniform float high_freq;            // the frequency of the last bar, Hz
//@slider min=0.0 max=4.0 value=1.0
uniform float gain;                 // louder bars
//@slider min=0.3 max=3.0 value=1.8
uniform float curve;                // above 1: only the loud parts reach up; below 1: quiet parts too
//@slider min=0.0 max=0.5 value=0.03
uniform float rise;                 // seconds a bar takes to go up
//@slider min=0.0 max=2.0 value=0.18
uniform float fall;                 // seconds a bar takes to fall
//@slider min=0.0 max=2.0 value=0.4
uniform float peak_hold;            // seconds the peak caps hang before they fall, 0 = no caps
//@slider min=0.1 max=4.0 value=0.8
uniform float peak_fall;            // how fast the caps fall, bar heights per second
