// SFX4 CheckerboardPhaser
// Square checkerboard (like the Checkerboard source shader) where the
// light/white tiles are animated with a "phaser" effect: phased fade-in/
// fade-out envelopes. Dark tiles stay solid.
// iTime in VibeVJ is in beats (1.0 = 1 beat), so the animation is beat-synced.

//@settings dtype=float32 format=rgba

// ---- Checkerboard base pattern ----

// Checker tile size in UV space
//@vec2 min=(0.01,0.01) max=(0.5,0.5) value=(0.1,0.1)
uniform vec2 checker_size;

// Light (foreground / "white") tile colour
//@rgb value=(1.0,1.0,1.0)
uniform vec3 light_color;

// Dark (background) tile colour
//@rgb value=(0.0,0.0,0.0)
uniform vec3 dark_color;

// ---- Phaser (phased fade) controls ----

// Phase pattern for the phaser on the white tiles
//@enum options=(None, Row, Column, Diagonal, Radial, Random) value=4
uniform int phase_pattern;

// Fade-in duration in beats
//@slider min=0.05 max=2.0 value=0.5
uniform float fade_time;

// Fade-out duration in beats
//@slider min=0.05 max=2.0 value=0.5
uniform float fade_out_time;

// Loop period in beats (one full phaser cycle)
//@slider min=0.5 max=8.0 value=2.0
uniform float loop_period;

// Edge smoothness of the fade envelope
//@slider min=0.0 max=1.0 value=0.2
uniform float smoothness;

// Whether the phaser grows/shrinks from the tile center (like a radial phaser)
// or applies a flat brightness fade over the whole tile.
//@enum options=(Radial, Flat) value=0
uniform int phaser_style;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y; // aspect-corrected like the Checkerboard shader

    // --- Base checkerboard pattern (square tiles) ---
    vec2 checker = floor(uv / checker_size);
    // In this layout: mod(sum, 2) == 1 -> light tile, 0 -> dark tile
    float checker_val = mod(checker.x + checker.y, 2.0);

    // --- Phaser phasing on the LIGHT (white) tiles ---
    float t = fract(iTime / max(loop_period, 0.05));

    float phase;
    vec2 cell_center = (checker + 0.5) * checker_size;
    if (phase_pattern == 0) {
        phase = 0.0; // none: all light tiles phase together
    } else if (phase_pattern == 1) {
        // Row-wise phasing
        float total_rows = 1.0 / checker_size.y; // number of rows in UV space
        phase = mod(float(checker.y) / max(total_rows, 1.0), 1.0);
    } else if (phase_pattern == 2) {
        // Column-wise phasing
        float total_cols = 1.0 / checker_size.x; // number of columns in UV space
        phase = mod(float(checker.x) / max(total_cols, 1.0), 1.0);
    } else if (phase_pattern == 3) {
        // Diagonal phasing
        phase = mod(float(checker.x + checker.y) * 0.06, 1.0);
    } else if (phase_pattern == 4) {
        // Radial phasing from screen center
        float dist = length(cell_center - 0.5);
        phase = mod(dist * 2.0, 1.0);
    } else {
        // Deterministic per-tile random phase
        float hash = sin(float(checker.x * 12.9898 + checker.y * 78.233)) * 43758.5453;
        phase = fract(hash);
    }

    // Fade envelope: 0 -> 1 (fade in) -> 0 (fade out) with per-tile phase offset
    float local_t = mod(t + phase, 1.0);
    float in_end    = clamp(fade_time    / max(loop_period, 0.05), 0.0, 1.0);
    float out_start = 1.0 - clamp(fade_out_time / max(loop_period, 0.05), 0.0, 1.0);

    float env;
    if (local_t < in_end)
        env = local_t / max(in_end, 0.001);
    else if (local_t > out_start)
        env = (1.0 - local_t) / max(1.0 - out_start, 0.001);
    else
        env = 1.0;

    // Soften the envelope edges
    env = smoothstep(0.0, max(smoothness, 0.001), env);

    // Apply the phaser to the light tiles only.
    float light_intensity;
    if (phaser_style == 1) {
        // Flat: uniform brightness fade of the whole light tile
        light_intensity = env;
    } else {
        // Radial: light tile grows/shrinks from its center as env goes 0 -> 1
        vec2 tile_uv = (uv - checker * checker_size) / checker_size; // 0..1 inside tile
        vec2 tc = tile_uv - 0.5;
        float r = length(tc);
        float tile_edge = 0.5;
        float visible = 1.0 - smoothstep(env * tile_edge - 0.01, env * tile_edge + 0.01, r);
        light_intensity = env * visible;
    }

    // Composite: dark tile stays solid, light tile gets the phaser envelope
    vec3 light = light_color * light_intensity;
    vec3 color = mix(dark_color, light, checker_val);

    fragColor = vec4(color, 1.0);
}
