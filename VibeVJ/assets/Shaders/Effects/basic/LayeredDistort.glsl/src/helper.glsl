// Shared helper functions for the LayeredDistort effect (FX2)

// ---- Per-form "within-cell" distance (0 at cell center, 1 at cell edge) ----

// Pixel / square cells
vec2 pixel_form(vec2 uv, out int cell_id) {
    float px = 1.0 / 40.0;
    vec2 g = floor(uv / px);
    cell_id = int(g.x * 64.0 + g.y * 3.0);
    return (g + 0.5) * px;
}

// Hexagon cells
vec2 hex_form(vec2 uv, out int cell_id) {
    float hs = 0.14;
    vec2 p = (uv / hs) * 1.5;
    vec2 id = vec2(mod(p.x, 1.0), mod(p.y, 1.0));
    cell_id = int(id.x * 1000.0 + id.y * 100.0);
    vec2 center = (id + 0.5) / 1.5 * hs;
    return center;
}

// Triangle cells (equilateral tiling with alternating up/down rows)
vec2 tri_form(vec2 uv, out int cell_id) {
    float s = 0.13;
    float h = s * 0.8660254;
    float row = floor(uv.y / h + 0.5);
    float col = floor((uv.x + mod(row, 2.0) * 0.5 * s) / s);
    vec2 tc;
    if (mod(row, 2.0) < 1.0)
        tc = vec2((col + 0.5) * s + mod(row, 2.0) * 0.5 * s, row * h);
    else
        tc = vec2(col * s + mod(row, 2.0) * 0.5 * s, row * h);
    cell_id = int(col * 64.0 + row * 3.0);
    return tc;
}
