// DotCascade - Vertical dot cascade animation
// Dots fall/travel downward like a waterfall across a grid
// Supports multiple dot shapes and cascade directions
//
// ==== Custom Uniform Controls ====

//@vec2 min=(0.01,0.01) max=(1.0,1.0) value=(0.1, 0.1)
uniform vec2 dotgrid_spacing;

//@float min=0.01 max=0.5 value=0.05
uniform float dot_size;

//@rgb value=(0.2, 0.8, 1.0)
uniform vec3 dot_color;

//@rgb value=(0.0, 0.0, 0.05)
uniform vec3 bg_color;

//@float min=0.1 max=5.0 value=1.5
uniform float cascade_speed;

//@enum options=(Circle, Square, Diamond)
uniform int dot_shape;

//@enum options=(Top to Bottom, Bottom to Top, Random)
uniform int cascade_direction;

// Standard hash function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Dot shape functions
// Returns 1.0 if point is inside shape, 0.0 otherwise
float dot_shape_circle(vec2 fragCoord, vec2 center, float size) {
    float dist = length(fragCoord - center);
    return 1.0 - smoothstep(size - size*0.2, size, dist);
}

float dot_shape_square(vec2 fragCoord, vec2 center, float size) {
    vec2 diff = abs(fragCoord - center);
    float in_square = 1.0 - smoothstep(size - size*0.1, size, max(diff.x, diff.y));
    return in_square;
}

float dot_shape_diamond(vec2 fragCoord, vec2 center, float size) {
    vec2 diff = abs(fragCoord - center);
    float diamond_dist = diff.x + diff.y;
    return 1.0 - smoothstep(size - size*0.2, size, diamond_dist);
}

// Calculate dot center based on grid position and animation
vec2 calculate_dot_position(vec2 grid_pos, float time) {
    vec2 center = grid_pos * dotgrid_spacing + dotgrid_spacing * 0.5;
    
    if (cascade_direction == 0) {
        // Top to Bottom: dots fall from top
        float fall_offset = fract(time * cascade_speed + hash(grid_pos) * 10.0);
        center.y = 1.0 - fall_offset; // Start from top, fall down
    } else if (cascade_direction == 1) {
        // Bottom to Top: dots rise from bottom
        float rise_offset = fract(time * cascade_speed + hash(grid_pos) * 10.0);
        center.y = rise_offset; // Start from bottom, rise up
    } else {
        // Random: each dot moves in random direction
        float random_dir = hash(grid_pos) > 0.5 ? 1.0 : -1.0;
        float random_offset = fract(time * cascade_speed * 0.5 + hash(grid_pos * 123.0) * 10.0);
        center.y = 0.5 + random_dir * random_offset * 0.5;
        center.y = fract(center.y); // Wrap around
    }
    
    return center;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalize coordinates for grid calculation
    vec2 uv = fragCoord / iResolution.xy;

    // Determine grid position for this pixel
    vec2 grid_pos = floor(uv / dotgrid_spacing);

    // Calculate dot center based on grid position and time
    vec2 dot_center = calculate_dot_position(grid_pos, iTime);

    // Check if pixel is inside the dot based on shape
    float activation = 0.0;
    vec2 pixel = fragCoord;
    if (dot_shape == 0) {
        activation = dot_shape_circle(pixel, dot_center * iResolution.xy, dot_size * iResolution.x);
    } else if (dot_shape == 1) {
        activation = dot_shape_square(pixel, dot_center * iResolution.xy, dot_size * iResolution.x);
    } else {
        activation = dot_shape_diamond(pixel, dot_center * iResolution.xy, dot_size * iResolution.x);
    }

    // Calculate final color
    vec3 final_color = mix(bg_color, dot_color, activation);

    // Output
    fragColor = vec4(final_color, 1.0);
}
