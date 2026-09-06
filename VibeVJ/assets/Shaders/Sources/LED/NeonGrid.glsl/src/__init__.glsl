//@settings dtype=float32 format=rgba

//@rgb value=(0.2, 1.0, 0.4)
uniform vec3 grid_line_color;

//@rgb value=(0.05, 0.1, 0.2)
uniform vec3 cell_color;

//@int min=2 max=48 value=12
uniform int grid_density;

//@slider min=0.0 max=1.0 value=0.5
uniform float glow;

//@slider min=0.05 max=2.0 value=0.25
uniform float pulse_speed;

//@slider min=0.0 max=1.0 value=0.5
uniform float cell_variation;

// Glowing VJ light-panel grid for 2D LED panels, with a beat-traveling
// brightness wave. Per-cell brightness is driven by beat-locked LFOs so a
// wave of light travels across the panel. Cell fills use cell_color scaled
// by the brightness, grid lines are drawn in grid_line_color with a glow.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Normalized uv space that matches LED mapper sampling (note: mapper flips y).
    vec2 uv = fragCoord / iResolution.xy;

    float cells = float(grid_density);

    // Cell index and intra-cell local coordinate.
    vec2 c = uv * cells;
    vec2 idx = floor(c);
    vec2 f = fract(c);

    // Beat-traveling brightness wave across the panel. A diagonal wave plus
    // a horizontal wave, both locked to beats so the motion stays beat-synced.
    float phase = iTime * pulse_speed;
    float diag = 0.5 + 0.5 * sin(6.28318 * (idx.x + idx.y) * 0.25 - 6.28318 * phase);
    float horiz = 0.5 + 0.5 * sin(6.28318 * idx.x * 0.5 - 6.28318 * phase);

    // Combine the two beat-locked waves and add per-cell variation so cells
    // differ from one another without breaking the traveling-wave look.
    float variation = cell_variation * (0.5 - 0.5 * cos(1.7 * idx.x + 2.3 * idx.y));
    float brightness = clamp(diag * 0.6 + horiz * 0.4 + variation, 0.0, 1.0);

    // Cell fill color scaled by the traveling brightness wave.
    vec3 col = cell_color * (0.15 + 0.85 * brightness);

    // Grid lines: compute distance to the nearest cell edge in uv space.
    float cell = 1.0 / cells;
    float dx = min(f, 1.0 - f) * cell;
    float dy = min(f, 1.0 - f) * cell;
    float line_dist = min(dx, dy);

    // Line mask with a glow falloff.
    float line_width = 0.02 + glow * 0.03;
    float line = 1.0 - smoothstep(0.0, line_width, line_dist);

    col += grid_line_color * line;

    fragColor = vec4(col, 1.0);
}
