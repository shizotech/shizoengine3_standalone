// Mandala_Formen
// A mandala built from configurable shapes: 8-fold radially-symmetric
// concentric rings, an optional hexagon honeycomb lattice (honeycomb_area),
// overall rotation about the screen center, single scaling uniform,
// radial noise morphing (morph_strength), colour-depth bands, ring
// line thickness and smoothness. Shadertoy-style mainImage.
// iResolution/iTime/iFrame/iMouse are engine-injected - do NOT redeclare them.

//@settings dtype=float32 format=rgba

// ---- Colours ----
//@rgb value=(1.0,0.9,0.5)
uniform vec3 fg_colour;

//@rgb value=(0.05,0.05,0.15)
uniform vec3 bg_colour;

// ---- Geometry / Behaviour ----
//@float min=0.0 max=1.0 value=0.10
uniform float morph_strength;

//@float min=0.0 max=1.0 value=0.5
uniform float colour_depth;

//@float min=0.1 max=3.0 value=1.0
uniform float scaling;

//@float min=0.0 max=0.2 value=0.01
uniform float line_thickness;

//@float min=0.0 max=1.0 value=0.6
uniform float honeycomb_area;

//@float min=0.0 max=1.0 value=0.10
uniform float smoothness;

//@float min=-360 max=360 value=0.0
uniform float rotation;

// =====================================================================
// Helpers
// =====================================================================
// Per-ID pseudo-random hash
float hash1(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// 2D value noise
float noise(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Smooth 2D value noise
float noise_smooth(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(noise(i), noise(i + vec2(1.0, 0.0)), f.x),
                mix(noise(i + vec2(0.0, 1.0)), noise(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Hexagon SDF (used for honeycomb cells)
float sd_hex(vec2 p, float r) {
    p = abs(p);
    return min(max(p.x * 0.866025 + p.y * 0.5, p.y), r) - 0.5 * r;
}

// Distance to the nearest hexagon center of a two-row offset lattice
// with cell radius r.
float dist_hex_lattice(vec2 p, float r) {
    const float SQRT3 = 1.732050807568877;
    vec2 g = p / (r * SQRT3);
    vec2 i = floor(g);
    vec2 f = fract(g);
    vec2 c1 = i;
    vec2 c2 = i + vec2(0.5, 0.5);
    float d1 = sd_hex(p - c1 * (r * SQRT3), r);
    float d2 = sd_hex(p - c2 * (r * SQRT3), r);
    // Second-row cells are vertically offset
    float d3 = sd_hex(p - (i + vec2(0.5, 0.5)) * (r * SQRT3) + vec2(0.0, 0.5 * r * SQRT3), r);
    return min(d1, min(d2, d3));
}

// =====================================================================
// Main
// =====================================================================
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Centered, aspect-corrected uv space
    vec2 uv = fragCoord.xy / iResolution.xy - 0.5;
    uv.x *= iResolution.x / iResolution.y;

    // Apply rotation (degrees -> radians) and the single scaling uniform
    float rot_rad = rotation * 3.141592653589793 / 180.0;
    float c = cos(rot_rad);
    float s = sin(rot_rad);
    uv = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);
    uv *= scaling;

    // Per-pixel seed for radial noise morphing
    float seed = hash1(dot(fragCoord.xy, vec2(0.1, 0.7)) * 0.001);

    // 8-fold radial symmetry: compute polar coords and mirror the angle
    // into the first sector so every asymmetric feature (the radial noise
    // morph) repeats 8 times around the mandala center.
    const float TWO_PI = 6.28318530718;
    const int FOLD = 8;
    float r0 = length(uv);
    float theta0 = atan(uv.y, uv.x);
    float sector = TWO_PI / float(FOLD);
    float a = mod(theta0, sector);
    a = min(a, sector - a);                 // mirror within the sector
    uv = vec2(cos(a), sin(a)) * r0;         // folded, symmetric uv

    // Polar coordinates
    float r = length(uv);

    // Radial noise morphing (morph_strength): gently deforms ring radii
    // and the hexagon lattice positions.
    float morph = (noise_smooth(uv * 3.0 + vec2(iTime * 0.2, seed)) - 0.5) * 2.0 * morph_strength;
    float rr = r + morph;

    // ---- Concentric rings ----
    // Ring spacing ~0.12 (in scaled space); colour_depth (0..1) selects
    // how many of the outer bands actually get coloured, so higher
    // colour_depth reveals more rings/bands.
    float ring_period = 0.12;
    float rp = mod(rr, ring_period);
    float dist = min(rp, ring_period - rp);
    float sm = max(smoothness, 0.005);
    float ring = 1.0 - smoothstep(line_thickness - sm, line_thickness + sm, dist);

    // Colour-band index: 0 = innermost band, increasing outward.
    float band_idx = rr / ring_period;
    float depth_f = 1.0 + colour_depth * 10.0; // max number of bands coloured
    float band_visible = 1.0 - smoothstep(depth_f - sm, depth_f + sm, band_idx);

    // Band tint: cycle between two fg tones per band for visible depth
    float band_alt = step(1.0, mod(band_idx, 2.0));
    vec3 band_col = mix(fg_colour, fg_colour * vec3(0.7, 0.85, 1.0), band_alt);
    float rings_alpha = ring * band_visible;
    vec3 col = mix(bg_colour, band_col, rings_alpha);

    // ---- Hexagon honeycomb lattice (honeycomb_area) ----
    // Tile the (rotated/scaled) uv space with a honeycomb of hexagons;
    // honeycomb_area (0..1) controls both the intensity and the cell size.
    float hex_r = mix(0.05, 0.18, honeycomb_area);
    float hex_dist = dist_hex_lattice(uv, hex_r);
    float hex_ring = 1.0 - smoothstep(line_thickness - sm, line_thickness + sm, hex_dist);
    float hex_alpha = hex_ring * honeycomb_area;
    col = mix(col, fg_colour * vec3(0.6, 0.8, 0.95), hex_alpha);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
