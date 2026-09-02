// SFX4 CheckerPhases - Checkerboard with phased tile fades
// Shadertoy format
// A checkerboard where the (light) tiles fade in and out from their center
// point. The phase pattern of the fade sequence is selectable.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Checker tile size
//@vec2 min=(0.01,0.01) max=(0.5,0.5) value=(0.08,0.08)
uniform vec2 checker_size;

// Light (foreground) tile colour
//@rgb value=(0.95,0.95,0.98)
uniform vec3 light_color;

// Dark (background) tile colour
//@rgb value=(0.10,0.08,0.15)
uniform vec3 dark_color;

// Phase pattern in which the light tiles fade in/out
//@enum options=(None, Row, Column, Diagonal, Radial, Random) value=4
uniform int phase_pattern;

// Fade-in duration in beats
//@slider min=0.05 max=2.0 value=0.5
uniform float fade_time;

// Fade-out duration in beats
//@slider min=0.05 max=2.0 value=0.5
uniform float fade_out_time;

// Loop period (in beats)
//@slider min=0.5 max=8.0 value=2.0
uniform float loop_period;

// Edge smoothness
//@slider min=0.0 max=1.0 value=0.2
uniform float smoothness;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    vec2 cell = floor(uv / checker_size);
    float checker = mod(cell.x + cell.y, 2.0);
    // Only light tiles (checker == 0 in this layout) animate; dark tiles stay solid.
    // Compute a phase offset per light tile depending on the selected pattern
    float phase;
    float t = fract(iTime / max(loop_period, 0.05));
    vec2 cell_center = (cell + 0.5) * checker_size;
    if (phase_pattern == 0) {
        phase = 0.0; // none: all light tiles fade simultaneously
    } else if (phase_pattern == 1) {
        // Row-wise phasing: phase advances with the row index, normalized by total rows
        int total_rows = int(1.0 / checker_size.y);
        phase = mod(float(cell.y) / float(max(total_rows, 1)), 1.0);
    } else if (phase_pattern == 2) {
        // Column-wise phasing
        int total_cols = int(1.0 / checker_size.x);
        phase = mod(float(cell.x) / float(max(total_cols, 1)), 1.0);
    } else if (phase_pattern == 3) {
        phase = mod(float(cell.x + cell.y) * 0.06, 1.0); // diagonal
    } else if (phase_pattern == 4) {
        float dist = length(cell_center - 0.5);
        phase = mod(dist * 2.0, 1.0); // radial from center
    } else {
        // deterministic per-tile random phase
        phase = fract(sin(float(cell.x * 12.9898 + cell.y * 78.233) * 43758.5453));
    }

    // Fade envelope: each tile has a local phase offset; the envelope goes 0 -> 1 (fade in) then 1 -> 0 (fade out)
    float local_t = mod(t + phase, 1.0);
    float in_end = clamp(fade_time / max(loop_period, 0.05), 0.0, 1.0);
    float out_start = 1.0 - clamp(fade_out_time / max(loop_period, 0.05), 0.0, 1.0);
    float env;
    if (local_t < in_end)
        env = local_t / max(in_end, 0.001);
    else if (local_t > out_start)
        env = (1.0 - local_t) / max(1.0 - out_start, 0.001);
    else
        env = 1.0;

    // Apply smoothstep to the envelope edges for softness
    env = smoothstep(0.0, max(smoothness, 0.001), env);

    // Fade in/out from the tile's center: scale the visible radius of the light tile by env
    vec2 tile_uv = (uv - cell * checker_size) / checker_size; // 0..1 inside the tile
    vec2 tc = tile_uv - 0.5;
    float r = length(tc * vec2(1.0, 1.0));
    float tile_edge = 0.5;
    // Visible fraction of the tile grows from 0 to full as env goes 0 -> 1
    float visible = 1.0 - smoothstep(env * tile_edge - 0.01, env * tile_edge + 0.01, r);

    vec3 light = light_color * visible * env;
    vec3 dark = dark_color;
    vec3 col = mix(dark, light, checker);

    fragColor = vec4(col, 1.0);
}
