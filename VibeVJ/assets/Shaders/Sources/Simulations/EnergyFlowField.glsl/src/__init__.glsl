//@settings dtype=float32 format=rgba
// ---------------------------------------------------------------------------
// EnergyFlowField
// A vector field visualised as flowing arrows / streaklines. The flow angle at
// every point comes from layered curl-noise whose turbulence and speed are
// driven by audio energy across the spectrum; arrows scale with local band
// amplitude and pulse outward on every beat. Streaklines integrate the field
// for a few bounded steps to draw glowing flow ribbons.
// iTime is measured in BEATS (1.0 = one beat).
// ---------------------------------------------------------------------------

uniform sampler2D AUDIO;   // spectrum row (y=0.0)
uniform sampler2D WAVE;    // waveform row (y=1.0)

//@slider min=2.0 max=16.0 value=7.0
uniform float noise_scale;       // spatial scale of the flow field

//@slider min=0.5 max=6.0 value=2.5
uniform float sensitivity;       // energy gain

//@slider min=0.0 max=3.0 value=1.0
uniform float turbulence;        // high-frequency energy -> chaotic swirl amount

//@slider min=0.0 max=2.0 value=0.6
uniform float flow_speed;        // field scroll speed per beat

//@slider min=0.0 max=1.0 value=0.5
uniform float arrow_density;     // spacing of the arrow grid (0 = dense)

//@int min=3 max=12 value=6
uniform int ribbon_steps;        // streakline integration steps (bounded)

//@slider min=0.05 max=1.0 value=0.35
uniform float ribbon_length;     // length of each flow streak

//@slider min=0.0 max=1.0 value=0.5
uniform float beat_push;         // radial outward push on the beat

//@rgb value=(0.1,0.6,1.0)
uniform vec3 cool_color;         // low-energy flow colour

//@rgb value=(1.0,0.4,0.1)
uniform vec3 hot_color;          // high-energy flow colour

const int MAX_STEPS = 12;

float clamp01(float v){ return clamp(v, 0.0, 1.0); }

// cheap 2D value noise
float hash21(vec2 p){
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p){
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1,0)), u.x),
               mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), u.x), u.y);
}
float fbm(vec2 p){
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * vnoise(p);
        p = p * 2.03 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

// flow direction from curl of fbm potential
vec2 flowDir(vec2 p, float t, float turb) {
    float e = 0.12;
    float n1 = fbm(p + vec2(0, e));
    float n2 = fbm(p - vec2(0, e));
    float n3 = fbm(p + vec2(e, 0));
    float n4 = fbm(p - vec2(e, 0));
    vec2 curl = vec2(n1 - n2, -(n3 - n4));
    // add a large-scale drift so energy visibly moves
    curl += vec2(0.6, 0.25) * sin(p.y * 1.5 + t) * 0.5;
    curl += turb * vec2(sin(p.y * 6.0 + t * 2.0), cos(p.x * 6.0 - t * 2.0)) * 0.4;
    return normalize(curl + vec2(1e-4, 0.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (uv - 0.5) * 2.0;
    p.x *= iResolution.x / iResolution.y;

    // ---- beat machinery ----
    float inBeat = fract(iTime);
    float beatHit = exp(-inBeat * 4.0);

    float bass  = clamp01(texture(AUDIO, vec2(0.08, 0.0)).x * sensitivity);
    float mid   = clamp01(texture(AUDIO, vec2(0.45, 0.0)).x * sensitivity);
    float high  = clamp01(texture(AUDIO, vec2(0.85, 0.0)).x * sensitivity);
    float energy= clamp01((bass + mid + high) / 3.0);
    float fb = 0.35 + 0.4 * beatHit;
    if (energy < 0.03) energy = fb;
    float wave = texture(WAVE, vec2(0.5, 1.0)).x - 0.5;
    if (abs(wave) < 0.01) wave = 0.2 * sin(iTime * 6.283185307);

    float t = iTime * flow_speed;
    vec2 fp = p * noise_scale + vec2(t * 0.4, -t * 0.2);
    float turb = turbulence * high;

    // ---- arrow grid: pick nearest cell center ----
    float dens = 4.0 + arrow_density * 12.0;
    vec2 gp = p * dens;
    vec2 gcell = floor(gp) + 0.5;
    vec2 gpos = gcell / dens;
    // local band amplitude sampled by horizontal position -> spectrum sweep
    float bin = clamp01(uv.x);
    float localAmp = clamp01(texture(AUDIO, vec2(bin, 0.0)).x * sensitivity);
    if (localAmp < 0.03) localAmp = fb;

    vec2 dir = flowDir(gpos * noise_scale + vec2(t*0.4, -t*0.2), t, turb);

    // integrate a short streakline from the grid point
    vec2 cur = gpos;
    float segLen = ribbon_length / dens;
    float maxAlong = 0.0, minAlong = 1e9, across = 1e9;
    int steps = clamp(ribbon_steps, 3, MAX_STEPS);
    vec2 start = cur;
    for (int i = 0; i < MAX_STEPS; i++) {
        if (i > steps) break;
        vec2 d2 = flowDir(cur * noise_scale + vec2(t*0.4, -t*0.2), t, turb);
        vec2 nxt = cur + d2 * segLen;
        // distance from pixel to segment start->nxt
        vec2 pa = p - start, ba = nxt - start;
        float h = clamp01(dot(pa, ba) / max(dot(ba, ba), 1e-6));
        float dist = length(pa - ba * h);
        across = min(across, dist);
        start = nxt;
        cur = nxt;
    }

    // beat push: radial outward offset of the whole field
    vec2 radial = normalize(p + vec2(1e-4));
    float push = beat_push * beatHit;
    across -= push * 0.02;

    // ---- render ribbon glow ----
    float thick = 0.012 + 0.02 * localAmp;
    float ribbon = exp(-pow(across / thick, 2.0)) * (0.4 + localAmp);
    vec3 ribbonCol = mix(cool_color, hot_color, clamp01(energy + high));
    ribbonCol = mix(ribbonCol, vec3(1.0), push * 0.5);

    // arrow head: bright dot at grid center scaled by amplitude
    float head = exp(-length(p - (gpos + dir * segLen * float(steps))) * 120.0) * localAmp;

    vec3 col = vec3(0.015, 0.02, 0.03);
    col += ribbonCol * ribbon * (1.0 + wave * 0.5);
    col += hot_color * head * 0.8;

    // faint field hue underlay modulated by energy
    float field = 0.5 + 0.5 * fbm(fp);
    col += mix(cool_color, hot_color, field) * energy * 0.05;

    fragColor = vec4(clamp(col, 0.0, 1.6), 1.0);
}
