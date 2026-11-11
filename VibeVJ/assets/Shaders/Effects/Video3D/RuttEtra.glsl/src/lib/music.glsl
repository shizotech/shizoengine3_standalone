// ---- Video3D: the music (the same file in every asset of Effects/Video3D) ----
// A sampler named AUDIO gets the texture of a running audio analysis (AudioInputAnalysis) by itself, or the one linked
// into the port Audio: 512 x 2, row 0 the spectrum (512 bands, log spaced from 20 Hz, 0 .. 1), row 1 the waveform
// (-1 .. 1). Without a sound the asset follows the beat of the timeline (Music Auto): a made-up kick, snare and hats.
// Pass S keeps the state in 4 pixels (below) and remembers the iTime of the last frame, so a stopped timeline does
// not fire a beat in every frame.
uniform sampler2D AUDIO;
uniform int AUDIO_ON;               // set by the engine: 1 while AUDIO has a picture (no control)

//@enum options=(Auto, Sound, Beat, Off) value=0
uniform int music;                  // Auto: the sound while it plays, else the beat. Sound: only the sound. Beat: only the beat
//@slider min=0.0 max=4.0 value=1.0
uniform float music_gain;           // multiplies the levels of the sound
//@int min=1 max=16 value=1
uniform int beat_every;             // the beat effects (flash, explode, ripple) fire on every n-th beat

const float MUSIC_TAU = 6.28318530718;

// ---- The state pass S, one pixel each ----
// 0: levels (bass, mid, high, loudness), 0 .. ~1 (made up from the beat when there is no sound)
// 1: (hit envelope: 1 at a beat or a kick, then falls; seconds since that hit; beat number of that hit; iTime of the
//    last frame)
// 2: (slow bass, kick envelope of the sound, seconds since the sound was last heard, 1 while the sound counts)
// 3: (spring position, spring velocity, -, -): a damped spring that each hit kicks outwards; it overshoots a little
//    and settles back to 0
const int ST_LEVELS = 0;
const int ST_HIT = 1;
const int ST_SOUND = 2;
const int ST_SPRING = 3;

// A random number 0 .. 1 for two integers (PCG hash)
uint musicHash(uint v) {
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}
float musicHash01(int a, int b) {
    return float(musicHash(uint(a) * 1597u + musicHash(uint(b))) >> 8u) * (1.0 / 16777216.0);
}

// A value of the last frame, or `fallback` when it is no number (a fresh texture can hold anything)
vec4 stateOr(vec4 v, vec4 fallback) {
    return (any(isnan(v)) || any(isinf(v))) ? fallback : v;
}

// Where a frequency (Hz) lies on the spectrum row, 0 .. 1 (log spaced from 20 Hz to 24 kHz)
float freqToX(float hz) {
    return clamp(log(max(hz, 20.0) / 20.0) / log(1200.0), 0.0, 1.0);
}
float audioBand(int i) {
    return clamp(texelFetch(AUDIO, ivec2(clamp(i, 0, 511), 0), 0).r, 0.0, 1.0);
}
float bandMean(float hzA, float hzB) {
    int a = int(freqToX(hzA) * 511.0), b = int(freqToX(hzB) * 511.0);
    int stp = max(1, (b - a) / 32);
    float v = 0.0, n = 0.0;
    for (int k = a; k <= b; k += stp) {
        v += audioBand(k);
        n += 1.0;
    }
    return v / max(n, 1.0);
}
// The levels the beat makes up when there is no sound: a kick on every beat, a snare on 2 and 4, hats between
vec4 beatLevels(float t) {
    float kick = exp(-fract(t) * 6.0);
    float snare = exp(-fract(t * 0.5 + 0.5) * 7.0);
    float hat = exp(-fract(t + 0.5) * 12.0);
    return vec4(0.85 * kick, 0.6 * snare + 0.15, 0.5 * hat + 0.1, 0.5 * kick + 0.3);
}
// The waveform at s (0 .. 1), -1 .. 1: the sound, or a made-up wave on the beat (music Beat, or no sound in Auto)
float musicWave(float s, bool soundOn) {
    if (music == 3)
        return 0.0;
    if (soundOn && AUDIO_ON == 1) {
        float f = clamp(s, 0.0, 1.0) * 511.0;
        int i = int(floor(f));
        float a = texelFetch(AUDIO, ivec2(i, 1), 0).r, b = texelFetch(AUDIO, ivec2(min(i + 1, 511), 1), 0).r;
        return clamp(mix(a, b, f - float(i)) * music_gain, -1.0, 1.0);
    }
    float kick = exp(-fract(iTime) * 5.0);
    return clamp(0.55 * (0.3 + kick) * sin(MUSIC_TAU * (s * 3.0 + iTime * 0.37))
         + 0.22 * sin(MUSIC_TAU * (s * 17.0 + iTime * 1.3))
         + 0.1 * sin(MUSIC_TAU * (s * 43.0 - iTime * 0.9)) * exp(-fract(iTime + 0.5) * 6.0), -1.0, 1.0);
}

// The pixel px of pass S, from the state of the last frame (st: the pass's feedback)
vec4 musicStatePixel(int px, sampler2D st) {
    vec4 lv0 = stateOr(texelFetch(st, ivec2(ST_LEVELS, 0), 0), vec4(0.0));
    vec4 ht0 = stateOr(texelFetch(st, ivec2(ST_HIT, 0), 0), vec4(0.0, 100.0, 0.0, iTime));
    vec4 sd0 = stateOr(texelFetch(st, ivec2(ST_SOUND, 0), 0), vec4(0.0, 0.0, 100.0, 0.0));
    vec4 sp0 = stateOr(texelFetch(st, ivec2(ST_SPRING, 0), 0), vec4(0.0));
    if (iFrame < 2) {
        lv0 = vec4(0.0);
        ht0 = vec4(0.0, 100.0, 0.0, iTime);
        sd0 = vec4(0.0, 0.0, 100.0, 0.0);
        sp0 = vec4(0.0);
    }
    float dt = clamp(iTimeDelta, 0.0, 0.1);

    // the sound: three bands and the loudness
    vec4 snd = vec4(bandMean(30.0, 150.0), bandMean(250.0, 2000.0), bandMean(4000.0, 14000.0), bandMean(30.0, 14000.0));
    snd = clamp(snd * music_gain * vec4(1.3, 1.8, 2.6, 1.6), 0.0, 1.5);
    bool heard = AUDIO_ON == 1 && snd.w > 0.002;
    float since = heard ? 0.0 : sd0.z + dt;
    bool soundOn = (music == 1) || (music == 0 && since < 2.0);
    vec4 target = music == 3 ? vec4(0.0) : (soundOn ? snd : beatLevels(iTime));
    // fast up, slower down: a level follows a kick at once and falls in about 0.15 s
    vec4 k = mix(vec4(1.0 - exp(-dt / 0.15)), vec4(1.0 - exp(-dt / 0.03)), step(lv0, target));
    vec4 lv = mix(lv0, target, k);

    // a kick of the sound: the bass jumps over its slow mean
    float slow = mix(sd0.x, lv.x, 1.0 - exp(-dt / 0.8));
    float kickEnv = sd0.y * exp(-dt / 0.12);
    bool kick = soundOn && lv.x - slow > 0.12 && lv.x > sd0.x + 0.02 && sd0.y < 0.5;
    if (kick)
        kickEnv = 1.0;

    // a beat: a new whole beat of iTime (only forwards: a stopped timeline fires nothing), every beat_every-th
    bool newBeat = floor(iTime) != floor(ht0.w) && iTime > ht0.w && iTime - ht0.w < 2.0;
    int beatNo = int(floor(iTime));
    bool hit = music != 3 && ((!soundOn && newBeat && beatNo % max(beat_every, 1) == 0) || kick);
    float hitEnv = hit ? 1.0 : ht0.x * exp(-dt / 0.25);
    float age = hit ? 0.0 : min(ht0.y + dt, 100.0);
    float hitNo = hit ? ht0.z + 1.0 : ht0.z;

    // the spring: each hit kicks it outwards, it swings back and settles at 0
    float vel = sp0.y + (hit ? 9.0 : 0.0);
    float acc = -70.0 * sp0.x - 7.0 * vel;
    vel += acc * dt;
    float pos = sp0.x + vel * dt;

    if (px == ST_LEVELS)
        return lv;
    if (px == ST_HIT)
        return vec4(hitEnv, age, mod(hitNo, 4096.0), iTime);
    if (px == ST_SOUND)
        return vec4(slow, kickEnv, min(since, 100.0), soundOn ? 1.0 : 0.0);
    return vec4(pos, vel, 0.0, 0.0);
}

vec4 musicLevels(sampler2D st) { return stateOr(texelFetch(st, ivec2(ST_LEVELS, 0), 0), vec4(0.0)); }
vec4 musicHit(sampler2D st) { return stateOr(texelFetch(st, ivec2(ST_HIT, 0), 0), vec4(0.0, 100.0, 0.0, 0.0)); }
float musicSpring(sampler2D st) { return stateOr(texelFetch(st, ivec2(ST_SPRING, 0), 0), vec4(0.0)).x; }
bool musicSoundOn(sampler2D st) { return stateOr(texelFetch(st, ivec2(ST_SOUND, 0), 0), vec4(0.0)).w > 0.5; }
