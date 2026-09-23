//@settings dtype=float32 format=rgba
// ---------------------------------------------------------------------------
// OscilloscopeLissajous
// A phosphor CRT oscilloscope that draws live Lissajous figures from the
// audio waveform. X is the waveform at the current scroll position, Y is the
// waveform phase-shifted by `phase_shift` and multiplied by `y_ratio`.
// The figure snaps/rotates on the beat and flashes on the bar downbeat.
// iTime is measured in BEATS (1.0 = one beat).
// ---------------------------------------------------------------------------

uniform sampler2D AUDIO;   // spectrum row (y=0.0), used for energy glow
uniform sampler2D WAVE;    // waveform row (y=1.0)

//@slider min=0.5 max=8.0 value=3.0
uniform float sensitivity;      // waveform amplitude gain

//@slider min=0.0 max=1.0 value=0.25
uniform float phase_shift;      // waveform read offset between X and Y (creates the Lissajous pattern)

//@slider min=1.0 max=5.0 value=3.0
uniform float y_ratio;          // Y frequency multiplier (integer-ish ratios = classic figures)

//@slider min=0.0 max=2.0 value=0.55
uniform float scroll_speed;     // waveform read head speed (beats per screen)

//@slider min=0.0 max=0.99 value=0.75
uniform float persistence;      // phosphor trail length (0 = off, 1 = infinite smear)

//@int min=2 max=32 value=14
uniform int trail_steps;        // trail samples per pixel (bounded by max 32)

//@slider min=0.0 max=1.0 value=0.25
uniform float line_width;       // trace thickness in uv units

//@slider min=0.0 max=3.0 value=1.2
uniform float glow;             // bloom around the trace

//@slider min=0.0 max=1.0 value=0.35
uniform float figure_scale;     // size of the Lissajous figure

//@slider min=0.0 max=4.0 value=1.0
uniform float beat_spin;        // figure rotation per bar (snaps on downbeat)

//@slider min=0.0 max=1.0 value=0.4
uniform float bar_flash;        // brightness flash on every 4th beat (bar downbeat)

//@rgb value=(0.15,1.0,0.45)
uniform vec3 trace_color;

//@rgb value=(0.9,0.2,0.05)
uniform vec3 flash_color;

//@button
uniform bool show_grid;         // scope grid overlay

// ---- helpers -------------------------------------------------------------
float clamp01(float v){ return clamp(v, 0.0, 1.0); }

// Read waveform centered around 0.0, guarded against unwired (black) audio
// with a small beat-only fallback so the scope still moves with iTime.
float readWave(float t) {
    float w = texture(WAVE, vec2(fract(t), 1.0)).x - 0.5;
    float fallback = 0.18 * sin(t * 6.283185307 * 2.0) + 0.12 * sin(t * 6.283185307 * 5.0);
    if (abs(w) < 0.01) w = fallback;
    return w;
}

// Signed distance from point p to segment ab
float segDist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (uv - 0.5) * 2.0;
    p.x *= iResolution.x / iResolution.y;

    // ---- beat / bar machinery (iTime in beats) ----
    float beatIdx = floor(iTime);
    float inBeat  = fract(iTime);
    float barHit  = exp(-inBeat * 3.5) * step(mod(beatIdx, 4.0), 0.5); // decay over one bar-downbeat
    float beatHit = exp(-inBeat * 3.5);
    float energy  = clamp01((texture(AUDIO, vec2(0.25, 0.0)).x + texture(AUDIO, vec2(0.75, 0.0)).x) * 0.5 * sensitivity);

    // Figure rotation: continuous slow drift + snap increment locked to bars
    float rot = iTime * 0.05 * beat_spin * 6.283185307 / 4.0
              + floor(iTime * 0.25) * beat_spin * 0.35;
    float cr = cos(rot), sr = sin(rot);
    mat2 R = mat2(cr, sr, -sr, cr);

    // ---- build the Lissajous trace points for this column of the read-head ----
    // The read head advances across the waveform; each trail step looks back.
    float head = iTime * scroll_speed * 0.5;
    float scale = 0.35 + figure_scale * (0.45 + 0.25 * energy);
    float rotGain = 1.0 + 0.25 * beatHit;

    vec2 prev = R * (vec2(readWave(head) , readWave(head + phase_shift) * y_ratio) * scale * rotGain);

    float dmin = 1e9;
    int steps = clamp(trail_steps, 2, 32);
    float fadeSum = 0.0;
    for (int i = 1; i <= 32; i++) {
        if (i > steps) break;
        float tt = head - float(i) * 0.02;
        vec2 q = vec2(readWave(tt), readWave(tt + phase_shift) * y_ratio) * scale * rotGain;
        q = R * q;
        dmin = min(dmin, segDist(p, prev, q));
        prev = q;
        fadeSum += pow(persistence, float(i));
    }

    // ---- trace + glow ----
    float width = max(line_width * 0.1, 1.5 / iResolution.y);
    float line = 1.0 - clamp01(dmin / width);
    float halo = exp(-dmin * (6.0 / max(glow, 0.01))) * glow;
    float traceBright = clamp01((line * 1.4 + halo) * (1.0 / max(fadeSum, 1.0)) + line * 0.5
                                + barHit * bar_flash * 0.5);

    vec3 col = vec3(0.012, 0.018, 0.022);                 // dark scope background
    col += trace_color * traceBright * (1.0 + 0.6 * energy);

    // phosphor smear: cheap vertical bleed for CRT feel
    col += trace_color * halo * 0.35 * persistence;

    // ---- bar downbeat flash tint (beat-locked decay) ----
    col += flash_color * barHit * bar_flash * 0.8;

    // ---- scope grid ----
    if (show_grid) {
        vec2 g = abs(fract(p * 2.5) - 0.5);
        float grid = smoothstep(0.02, 0.0, min(g.x, g.y)) * 0.16;
        col += vec3(0.1, 0.25, 0.18) * grid;
        // center cross
        float cross = (smoothstep(0.012, 0.0, abs(p.x)) + smoothstep(0.012, 0.0, abs(p.y))) * 0.25;
        col += vec3(0.15, 0.35, 0.25) * cross;
    }

    // ---- vignette + subtle scanlines ----
    float vig = 1.0 - 0.35 * dot(p * 0.55, p * 0.55);
    col *= clamp01(vig);
    float scan = 0.94 + 0.06 * sin(uv.y * iResolution.y * 3.14159);
    col *= scan;

    fragColor = vec4(col, 1.0);
}
