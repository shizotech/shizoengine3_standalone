//@settings dtype=float32 format=rgba
// ---------------------------------------------------------------------------
// BeatVoronoi
// Animated Voronoi cells whose seed points jump to new grid positions on every
// beat (beat-quantized), then relax/lerp into place. Cell edge glow intensity
// and cell fill colour are driven by the spectrum; a bar downbeat re-seeds the
// whole field. iTime is measured in BEATS (1.0 = one beat).
// ---------------------------------------------------------------------------

uniform sampler2D AUDIO;   // spectrum row (y=0.0)

//@slider min=2.0 max=14.0 value=7.0
uniform float cell_density;      // Voronoi cells per screen (grid resolution)

//@slider min=0.5 max=6.0 value=2.0
uniform float sensitivity;       // spectral gain

//@slider min=0.0 max=1.0 value=1.0
uniform float jump_amount;       // how far seeds teleport on a beat

//@slider min=0.0 max=1.0 value=0.15
uniform float relax_speed;       // easing from jump to rest position

//@slider min=0.0 max=1.0 value=0.5
uniform float edge_width;        // cell boundary thickness

//@slider min=0.0 max=3.0 value=1.4
uniform float edge_glow;         // boundary glow intensity

//@slider min=0.0 max=1.0 value=0.75
uniform float fill_amount;       // solid cell fill level

//@slider min=0.0 max=1.0 value=0.6
uniform float hue_range;         // colour spread across cells

//@slider min=0.0 max=2.0 value=0.3
uniform float cell_spin;         // per-beat field rotation

//@rgb value=(0.1,0.4,0.9)
uniform vec3 base_color;

vec3 hsv2rgb(vec3 c){
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float clamp01(float v){ return clamp(v, 0.0, 1.0); }

vec2 hash2(vec2 id){
    // deterministic pseudo-random per cell id
    float a = fract(sin(dot(id, vec2(127.1, 311.7))) * 43758.5453);
    float b = fract(sin(dot(id, vec2(269.5, 183.3))) * 24634.1321);
    return vec2(a, b);
}

// Voronoi over a rotating, beat-quantized grid.
// Returns (F1 distance, cell id)
vec2 voronoi(vec2 p, float beatIdx, float inBeat) {
    vec2 gi = floor(p);
    vec2 gf = fract(p);
    float best = 8.0;
    vec2 bestId = gi;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 cell = gi + vec2(float(i), float(j));
            vec2 rnd = hash2(cell);
            // jump offset active only on the current beat, relaxes over the beat
            float relax = clamp01(inBeat * (1.0 + relax_speed * 10.0));
            relax = 1.0 - pow(1.0 - relax, 2.0); // ease out
            vec2 jump = (rnd - 0.5) * jump_amount * (1.0 - relax);
            vec2 seed = vec2(float(i), float(j)) + rnd * 0.7 + 0.15 + jump;
            vec2 diff = seed - gf;
            float d = dot(diff, diff);
            if (d < best) { best = d; bestId = cell; }
        }
    }
    return vec2(sqrt(best), dot(bestId, vec2(3.17, 7.93)));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (uv - 0.5) * 2.0;
    p.x *= iResolution.x / iResolution.y;

    // ---- beat machinery ----
    float beatIdx = floor(iTime);
    float inBeat  = fract(iTime);
    float beatHit = exp(-inBeat * 5.0);

    float bass  = clamp01(texture(AUDIO, vec2(0.08, 0.0)).x * sensitivity);
    float mid   = clamp01(texture(AUDIO, vec2(0.5, 0.0)).x  * sensitivity);
    float high  = clamp01(texture(AUDIO, vec2(0.85, 0.0)).x * sensitivity);
    float fb = 0.4 + 0.4 * beatHit;
    if (mid < 0.03) mid = fb;

    // field rotation snapped per beat + slow drift
    float rot = cell_spin * beatIdx * 0.3 + iTime * 0.02;
    float cr = cos(rot), sr = sin(rot);
    p = mat2(cr, sr, -sr, cr) * p;

    float dens = clamp(cell_density, 2.0, 14.0);
    vec2 res = voronoi(p * dens, beatIdx, inBeat);
    float f1 = res.x;
    float cellSeed = fract(res.y);

    // ---- colour per cell from spectrum ----
    float hue = fract(cellSeed * hue_range + bass * 0.3 + iTime * 0.02);
    vec3 cellCol = hsv2rgb(vec3(hue, 0.7 + 0.3 * mid, 1.0));
    cellCol = mix(cellCol, cellCol * vec3(1.3, 0.8, 0.6), bass);

    // ---- cell fill ----
    float fill = clamp01(f1 * 1.4) ;
    vec3 fillCol = cellCol * (fill_amount * (0.35 + 0.65 * (1.0 - fill)) * (1.0 + bass));

    // ---- edges (boundary where f1 grows) ----
    float edge = smoothstep(edge_width * 0.35, 0.0, f1 * 0.5) ;
    float glow = exp(-f1 * (4.0 / max(edge_glow, 0.05))) * edge_glow;
    vec3 edgeCol = (base_color * 0.4 + cellCol * 0.8) * (edge * 1.2 + glow) * (1.0 + high);

    vec3 col = fillCol + edgeCol;

    // ---- bar downbeat: brief whole-field flash + reseed pulse ----
    float barHit = exp(-inBeat * 3.0) * (1.0 - step(0.5, mod(beatIdx, 4.0)));
    col += vec3(1.0, 0.95, 0.85) * barHit * 0.25;
    col *= 1.0 + 0.15 * beatHit;

    // ---- subtle high-freq scanline texture inside cells ----
    float scan = 0.9 + 0.1 * high * sin(uv.y * 300.0 + iTime * 8.0);
    col *= scan;

    fragColor = vec4(clamp(col, 0.0, 1.5), 1.0);
}
