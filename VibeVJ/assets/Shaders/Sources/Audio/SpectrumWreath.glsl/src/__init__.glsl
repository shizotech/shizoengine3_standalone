//@settings dtype=float32 format=rgba
// ---------------------------------------------------------------------------
// SpectrumWreath
// A radial spectrum flower: each petal's length is one frequency band, petals
// bloom outward from the rim, hue sweeps with the spectrum and pulses on the
// beat. Mid/bass bands modulate petal width and a central pulsing core.
// iTime is measured in BEATS (1.0 = one beat).
// ---------------------------------------------------------------------------

uniform sampler2D AUDIO;   // spectrum row (y=0.0)
uniform sampler2D WAVE;    // waveform row (y=1.0) for the core

//@int min=16 max=128 value=64
uniform int petal_count;        // number of spectral petals (bounded by max 128)

//@slider min=0.5 max=6.0 value=2.5
uniform float sensitivity;      // band amplitude gain

//@slider min=0.15 max=1.0 value=0.45
uniform float inner_radius;     // wreath inner radius

//@slider min=0.2 max=1.2 value=0.7
uniform float petal_length;     // max petal length

//@slider min=0.05 max=0.6 value=0.18
uniform float petal_width;      // petal angular width factor

//@slider min=0.0 max=1.0 value=0.5
uniform float bloom_pulse;      // whole wreath radius breathing on beat

//@slider min=0.0 max=2.0 value=0.4
uniform float sway;             // per-petal sway driven by waveform

//@slider min=0.0 max=1.0 value=0.6
uniform float hue_spread;       // hue rotation across the spectrum

//@slider min=0.0 max=2.0 value=0.5
uniform float spin;             // wreath rotation speed (per beat)

//@rgb value=(1.0,0.5,0.15)
uniform vec3 bass_color;        // tint pushed onto low bands

//@slider min=0.0 max=1.0 value=0.35
uniform float core_strength;

vec3 hsv2rgb(vec3 c){
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float clamp01(float v){ return clamp(v, 0.0, 1.0); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (uv - 0.5) * 2.0;
    p.x *= iResolution.x / iResolution.y;

    float r = length(p);
    float ang = atan(p.y, p.x);

    // ---- beat machinery ----
    float inBeat = fract(iTime);
    float beatHit = exp(-inBeat * 4.0);
    float barPhase = fract(iTime * 0.25);
    float energy = clamp01(texture(AUDIO, vec2(0.15, 0.0)).x * sensitivity);
    float wave = texture(WAVE, vec2(0.5, 1.0)).x - 0.5;
    if (abs(wave) < 0.01) wave = 0.2 * sin(iTime * 6.283185307);

    float spinA = iTime * spin * 0.5;
    float a = ang + spinA;
    float normA = fract(a / 6.283185307);

    // ---- find which petal this angle belongs to ----
    int n = clamp(petal_count, 16, 128);
    float nf = float(n);
    float slot = normA * nf;
    int idx = int(floor(slot));
    float inSlot = fract(slot);

    // spectrum sample for this petal
    float bin = (float(idx) + 0.5) / nf;
    float amp = clamp01(texture(AUDIO, vec2(bin, 0.0)).x * sensitivity);
    // beat-only fallback so petals still bloom without audio
    float fb = 0.35 + 0.3 * sin(bin * 12.0 + iTime * 2.0);
    if (texture(AUDIO, vec2(bin, 0.0)).x < 0.02) amp = fb * (0.6 + 0.4 * beatHit);

    // ---- petal geometry ----
    float breath = 1.0 + bloom_pulse * (0.3 * sin(iTime * 6.283185307 * 0.25) + 0.5 * beatHit);
    float swayA = sway * wave * sin(bin * 8.0 + iTime * 3.0);
    float swayAng = a + swayA;

    float innerR = inner_radius * breath;
    float len = petal_length * (0.12 + amp);
    float outerR = innerR + len;

    // angular half width (narrower for high frequencies)
    float halfW = (3.1415926535 / nf) * (petal_width + 0.5 * amp);
    float dAng = abs(fract((swayAng / 6.283185307) * nf) - 0.5) * (6.283185307 / nf);

    // petal mask: radial band with soft edges + angular falloff
    float radMask = smoothstep(innerR - 0.02, innerR + 0.03, r) * (1.0 - smoothstep(outerR - 0.05, outerR, r));
    float angMask = smoothstep(halfW, halfW * 0.25, dAng);
    float petal = radMask * angMask;

    // hue sweeps across spectrum + slow time drift
    float hue = fract(bin * hue_spread + iTime * 0.03);
    vec3 hueCol = hsv2rgb(vec3(hue, 0.85, 1.0));
    // bass tint mixes onto low bins
    float bassMix = 1.0 - smoothstep(0.0, 0.35, bin);
    vec3 col3 = mix(hueCol, bass_color, bassMix * 0.7);

    // tip glow brighter with amplitude
    float bright = petal * (0.4 + amp) * (1.0 + 0.6 * beatHit);

    vec3 col = vec3(0.01, 0.012, 0.02);
    col += col3 * bright;
    // soft outer halo
    col += col3 * amp * 0.25 * exp(-abs(r - outerR) * 12.0) * angMask;

    // ---- central pulsing core ----
    float coreR = inner_radius * 0.8 * (1.0 + 0.4 * energy + 0.3 * beatHit);
    float core = 1.0 - smoothstep(coreR * 0.15, coreR, r);
    vec3 coreCol = hsv2rgb(vec3(fract(iTime * 0.05 + 0.5), 0.7, 1.0));
    col += coreCol * core * core_strength * (0.6 + 0.6 * abs(wave) + 0.5 * beatHit);

    // bar accent ring
    float ring = exp(-abs(r - innerR) * 40.0) * barPhase * 0.25;
    col += vec3(1.0) * ring;

    fragColor = vec4(col, 1.0);
}
