// ==== Custom Uniform Controls ====

//@float min=0.1 max=5.0 value=2.0
uniform float matrix_speed;

//@rgb value=(0.0,1.0,0.0)
uniform vec3 matrix_color;

//@float min=0.1 max=2.0 value=1.0
uniform float matrix_density;

//@float min=4.0 max=32.0 value=12.0
uniform float font_size;

//@float min=0.1 max=3.0 value=1.0
uniform float trail_length;

float hash(float n) { return fract(sin(n) * 43758.5453); }

// Digital rain: columns of glyph cells, font_size pixels each. In every column a head falls down with its own speed
// and leaves a fading trail; the glyphs are 3 x 5 random blocks that change while the head passes. The old version
// gave every cell its own drop and a trail ~0.00001 wide, so it was black (#436).
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float size = max(font_size, 2.0);
    vec2 cell = floor(fragCoord / size);
    vec2 cell_uv = fract(fragCoord / size);
    float rows = ceil(iResolution.y / size);
    float trail_rows = 4.0 + 16.0 * trail_length;

    // Per column: speed, start and whether it rains at all (Matrix density)
    float col_r = hash(cell.x * 13.17 + 1.3);
    float raining = step(hash(cell.x * 7.31 + 4.1), clamp(matrix_density * 0.6, 0.0, 1.0));
    float speed = (0.6 + col_r) * matrix_speed * 6.0;   // rows per second
    float head = mod(iTime * speed + col_r * 97.0, rows + trail_rows);

    // Rows counted from the top; dist > 0 is above the head, in its trail
    float row = rows - 1.0 - cell.y;
    float dist = head - row;
    float trail = (dist >= 0.0 && dist < trail_rows) ? 1.0 - dist / trail_rows : 0.0;
    float is_head = (dist >= 0.0 && dist < 1.0) ? 1.0 : 0.0;

    // The glyph: 3 x 5 blocks with a margin, changing a few times per second
    vec2 g = floor(cell_uv * vec2(3.0, 5.0));
    float tick = floor(iTime * (2.0 + 4.0 * col_r) + hash(cell.y * 3.1 + cell.x));
    float bit = step(0.45, hash(cell.x * 1.37 + cell.y * 7.11 + g.x * 3.7 + g.y * 11.3 + tick * 0.618));
    float inside = step(0.12, cell_uv.x) * step(cell_uv.x, 0.88) * step(0.08, cell_uv.y) * step(cell_uv.y, 0.92);
    float glyph = bit * inside;

    float brightness = glyph * trail * raining;
    vec3 color = matrix_color * brightness + vec3(0.8) * glyph * is_head * raining;
    fragColor = vec4(color, 1.0);
}
