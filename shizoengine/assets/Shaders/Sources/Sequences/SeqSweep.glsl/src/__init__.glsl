// SeqSweep - Horizontal sequential block sweep
// A single block lights up and sweeps across the grid from left to right
// Supports multiple interpolation modes and directions
//
// ==== Custom Uniform Controls ====

//@slider min=0.1 max=5.0 value=1.0
uniform float beat_freq;

//@int min=1 max=64 value=8
uniform int grid_x;

//@rgb
uniform vec3 base_color;

//@enum options=(Instant, Linear, Smoothstep, Sine Pulse)
uniform int interp_mode;

//@enum options=(Left to Right, Right to Left, Ping Pong)
uniform int direction;

// Standard hash function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Interpolation modes for block transitions
float interpolate_block(float t, int mode) {
    if (mode == 0) {
        // Instant: binary on/off
        return step(0.5, t);
    } else if (mode == 1) {
        // Linear: smooth linear transition
        return clamp(t, 0.0, 1.0);
    } else if (mode == 2) {
        // Smoothstep: smooth easing transition
        return smoothstep(0.0, 1.0, t);
    } else {
        // Sine Pulse: sinusoidal pulse shape
        return pow(sin(t * 3.14159), 2.0);
    }
}

// Calculate the active block position based on time and direction
float get_sweep_position(float anim_time) {
    // Total cycle time is based on grid_x and beat_freq
    float cycle_time = float(grid_x) / beat_freq;
    float t = fract(anim_time / cycle_time);
    
    if (direction == 0) {
        // Left to Right
        return t;
    } else if (direction == 1) {
        // Right to Left
        return 1.0 - t;
    } else {
        // Ping Pong: alternate direction
        float cycle = floor(anim_time / cycle_time);
        if (mod(cycle, 2.0) == 0.0) {
            return t; // Left to Right
        } else {
            return 1.0 - t; // Right to Left
        }
    }
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalize coordinates
    vec2 uv = fragCoord / iResolution.xy;
    
    // Calculate animation parameter
    float anim_time = iTime * beat_freq;
    
    // Get the sweep position (0.0 to 1.0 across the screen)
    float sweep_pos = get_sweep_position(anim_time);
    
    // Determine which grid cell we're in
    float cell_width = 1.0 / float(grid_x);
    float current_cell = floor(uv.x / cell_width);
    float cell_center = (current_cell + 0.5) * cell_width;
    
    // Calculate distance from cell center to sweep position
    float dist = abs(uv.x - sweep_pos);
    
    // Check if this cell is the active block
    float cell_pos = (current_cell + 0.5) / float(grid_x);
    float cell_dist = abs(cell_pos - sweep_pos);
    
    // Activate the block with interpolation
    float block_activation = 1.0 - clamp(cell_dist * float(grid_x), 0.0, 1.0);
    float interpolated = interpolate_block(block_activation, interp_mode);
    
    // Calculate final color
    vec3 final_color = mix(vec3(0.0), base_color, interpolated);
    
    // Output
    fragColor = vec4(final_color, 1.0);
}
