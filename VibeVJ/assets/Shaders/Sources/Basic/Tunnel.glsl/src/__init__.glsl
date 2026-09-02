// Tunnel
// An endless plasma tunnel: the viewer flies through a tunnel whose
// walls are made of animated plasma. The pattern style is selectable
// via `pattern_mode` (Classical, Waves, Vortex, Fire, Mosaic).
// Shadertoy-style mainImage. iResolution / iTime / iFrame / iMouse are
// engine-injected - do NOT redeclare them.

//@settings dtype=float32 format=rgba

// ---- Configurable uniforms ----
//@float min=0.05 max=1.0 value=0.3
uniform float tunnel_size;

//@float min=0.0 max=1.0 value=0.5
uniform float smoothness;

//@float min=0.0 max=5.0 value=1.0
uniform float rotation_speed;

//@rgb value=(1.0,0.6,0.2)
uniform vec3 fg_colour;

//@rgb value=(0.02,0.02,0.08)
uniform vec3 bg_colour;

//@enum options=(Classical, Waves, Vortex, Fire, Mosaic)
uniform int pattern_mode;

// =====================================================================
// Helpers
// =====================================================================
// 2D hash for pseudo-random values.
float hash(vec2 p) {
    float n = dot(p, vec2(127.1, 311.7));
    return fract(sin(n) * 43758.5453);
}

// Smooth 2D value noise (smoothstep-interpolated).
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    vec2 a = vec2(0.0, 0.0);
    vec2 b = vec2(1.0, 0.0);
    vec2 c = vec2(0.0, 1.0);
    vec2 d = vec2(1.0, 1.0);
    float v0 = hash(i);
    float v1 = hash(i + a);
    float v2 = hash(i + b);
    float v3 = hash(i + c);
    float v4 = hash(i + d);
    float x0 = mix(v0, v2, f.x);
    float x1 = mix(v1, v3, f.x);
    float y0 = mix(v0, v1, f.y);
    float y1 = mix(v2, v4, f.y);
    return mix(x0, x1, f.y);
}

// 5-octave fractal Brownian motion built on the value noise above.
float fbm(vec2 p) {
    float sum = 0.0;
    float amp = 0.5;
    vec2 p2 = p;
    for (int k = 0; k < 5; k++) {
        sum += amp * noise(p2);
        p2 = p2 * 2.0 + vec2(13.7, 7.3);
        amp *= 0.5;
    }
    return sum;
}

// Hue-cycled "trippy" colour from a phase value.
vec3 trippy_col(float phase) {
    return 0.5 + 0.5 * cos(vec3(0.0, 2.09, 4.19) + 6.2832 + phase);
}

// =====================================================================
// Plasma pattern generator
// q.x = angle around the tunnel (radians), q.y = depth along the axis.
// =====================================================================
float plasma(vec2 q, float t, int mode) {
    float pv = 0.0;
    if (mode == 0) {
        // Classical: standard superposition of sines.
        float s1 = sin(q.x * 3.0 + t);
        float s2 = sin(q.x * 5.0 - t * 1.3);
        float s3 = sin(q.y * 2.0 + t * 0.7);
        float s4 = sin((q.x + q.y) * 2.0 - t * 0.5);
        pv = s1 + s2 + s3 + s4;
        pv = 0.5 + 0.5 * (pv / 4.0);
    } else if (mode == 1) {
        // Waves: horizontal and diagonal sine bands running along the tunnel.
        float w1 = sin(q.y * 3.0 + t);
        float w2 = sin((q.x + q.y) * 2.0 - t * 0.8);
        pv = 0.5 + 0.5 * (0.5 * (w1 + w2));
    } else if (mode == 2) {
        // Vortex: spiral distortion - the angle advances with depth,
        // so the plasma swirls like a vortex down the tunnel.
        float va = q.x + q.y * 0.8;
        float s1 = sin(va * 4.0 - t * 1.2);
        float s2 = sin(q.y * 2.0 + t * 0.6);
        float s3 = sin(q.x * 6.0 + t);
        pv = s1 + s2 + s3;
        pv = 0.5 + 0.5 * (pv / 3.0);
    } else if (mode == 3) {
        // Fire: fbm noise flowing upward through the tunnel.
        vec2 fp = vec2(q.x * 0.5, q.y * 0.3 - t * 0.4);
        pv = fbm(fp);
        pv = smoothstep(0.3, 0.9, pv);
    } else {
        // Mosaic: tiled plasma cells with per-cell random phase.
        vec2 celluv = vec2(q.x * 4.0, q.y * 2.0);
        vec2 cell = floor(celluv);
        float h = hash(cell + vec2(floor(t * 2.0) * 7.13));
        float cellp = sin(q.x * 4.0 - h * 6.2832 + t) * sin(q.y * 2.0 + h * 6.2832);
        pv = 0.5 + 0.5 * cellp;
        // Slight darkening at the cell boundaries for a tiled look.
        vec2 cf = fract(celluv);
        float bx = min(cf.x, 1.0 - cf.x);
        float by = min(cf.y, 1.0 - cf.y);
        float boundary = smoothstep(0.0, 0.15, min(bx, by));
        pv *= 0.7 + 0.3 * boundary;
    }
    return pv;
}

// =====================================================================
// Main
// =====================================================================
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalised, aspect-corrected, centered coordinates.
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = uv - 0.5;
    p.x *= iResolution.x / iResolution.y;

    // ---- Polar coordinates of the ray on the tunnel surface ----
    float r = length(p);
    float a = atan(p.y, p.x) + iTime * rotation_speed;

    // ---- Depth along the tunnel axis (perspective projection) ----
    // The ray at radius r intersects the tunnel wall (fixed radius
    // tunnel_size) at depth = tunnel_size / r.
    float depth = tunnel_size / max(r, 0.0001);
    // Endless forward motion: the whole field scrolls with iTime,
    // so the plasma pattern flows toward the viewer forever.
    float w = depth - iTime * 0.5;

    // ---- Plasma on the tunnel wall ----
    vec2 q = vec2(a, w);
    float pv = plasma(q, iTime, pattern_mode);

    // Depth fog: distant plasma fades into the background.
    float fog = clamp(exp(-max(w, 0.0) * 0.08), 0.0, 1.0);
    pv *= fog;

    // ---- Wall / background mask ----
    // Smoothness controls the width of the edge transition.
    float width = mix(0.01, 0.3, smoothness);
    float edge = tunnel_size - width;
    float wall_mask = 1.0 - smoothstep(edge, tunnel_size, r);

    // ---- Colours ----
    // Plasma glow: fg_colour modulated by the plasma value, plus a
    // subtle hue-cycled trippy tint around the vanishing point.
    vec3 plasma_col = fg_colour * pv + 0.15 * trippy_col(a * 2.0 + iTime * 0.3);

    // Inside the tunnel show the plasma wall, outside show the background.
    vec3 col = mix(bg_colour, plasma_col, wall_mask);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
