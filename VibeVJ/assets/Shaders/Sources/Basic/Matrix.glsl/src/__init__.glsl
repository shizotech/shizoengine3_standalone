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

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;

    float time = iTime * matrix_speed;

    // Grid based on font size
    float cell_size = font_size / iResolution.y;
    vec2 cell = floor(uv / cell_size);
    vec2 cell_uv = fract(uv / cell_size);

    // Random speed and position for each column
    float col_hash = hash(cell.x + cell.y * 100.0);
    float speed = 0.5 + col_hash;
    float offset = hash(cell.x * 7.7 + cell.y * 3.3) * 20.0;

    // Animated drop position
    float drop = fract(time * speed * 0.1 + offset);

    // Trail effect
    float trail = 1.0 - smoothstep(0.0, trail_length * cell_size / iResolution.y, abs(uv.y - drop) / cell_size);
    trail = max(trail, 0.0);

    // Head of the drop (brighter)
    float head = 1.0 - smoothstep(0.0, 0.02, abs(uv.y - drop) / cell_size);

    // Random character pattern (geometric representation)
    float char_hash = hash(cell.x + cell.y * 200.0 + floor(time * speed * 0.1 + offset));
    float char_pattern = step(0.3, char_hash) * step(cell_uv.x, 0.8) * step(cell_uv.y, 0.8);

    // Combine
    float brightness = head + trail * 0.5 * matrix_density + char_pattern * trail * 0.3;

    // Fade old trails
    brightness *= smoothstep(trail_length * cell_size / iResolution.y, 0.0, abs(uv.y - drop) / cell_size + 0.001);

    vec3 color = matrix_color * brightness;

    fragColor = vec4(color, 1.0);
}