// ChaseLights - Classic chase/ping-pong lighting effect
// Smooth chasing animation with fading trail
// Supports Linear Chase, Ping Pong, and Dual Chase modes
//
// ==== Custom Uniform Controls ====

//@slider min=0.1 max=5.0 value=1.0
uniform float speed;

//@rgb
uniform vec3 chase_color;

//@rgb
uniform vec3 bg_color;

//@int min=1 max=16 value=8
uniform int chase_length;

//@enum options=(Linear Chase, Ping Pong, Dual Chase)
uniform int chase_mode;

//@slider min=0.0 max=1.0 value=0.5
uniform float tail_fade;

// Standard hash function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Calculate the chase head position for Linear Chase mode
// Head moves from 0 to 1, then wraps around
float get_linear_chase_pos(float t) {
    return fract(t);
}

// Calculate the chase head position for Ping Pong mode
// Head moves 0→1, then 1→0, repeating
float get_ping_pong_pos(float t) {
    float cycle = floor(t);
    float phase = fract(t);
    if (mod(cycle, 2.0) < 1.0) {
        return phase; // Forward
    } else {
        return 1.0 - phase; // Backward
    }
}

// Calculate brightness for a block based on its distance from the chase head
// and the tail_fade parameter
float get_block_brightness(float dist, float fade) {
    // fade controls how quickly the tail fades (0 = no fade, 1 = rapid fade)
    float decay = 1.0 - fade; // Convert: higher fade = faster decay
    return pow(decay, dist);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalize coordinates
    vec2 uv = fragCoord / iResolution.xy;
    
    // Animation time scaled by speed
    float anim_time = iTime * speed;
    
    // Get head position based on chase mode
    float head_pos;
    float head2_pos; // For Dual Chase
    
    if (chase_mode == 0) {
        // Linear Chase
        head_pos = get_linear_chase_pos(anim_time);
        head2_pos = -1.0; // Not used
    } else if (chase_mode == 1) {
        // Ping Pong
        head_pos = get_ping_pong_pos(anim_time);
        head2_pos = -1.0; // Not used
    } else {
        // Dual Chase: two heads moving in opposite directions
        head_pos = get_linear_chase_pos(anim_time);
        head2_pos = 1.0 - get_linear_chase_pos(anim_time);
    }
    
    // Determine which block the fragment belongs to
    float block_size = 1.0 / float(chase_length);
    int current_block = int(floor(uv.x / block_size));
    
    // Calculate the center position of the current block
    float block_center = (float(current_block) + 0.5) * block_size;
    
    // Calculate distance from block center to chase head
    // For wrapping, we need to handle the case where head is near 0 or 1
    float dist_to_head = abs(uv.x - head_pos);
    
    // Handle wrapping: the shortest distance considering wrap-around
    float wrap_dist = min(dist_to_head, 1.0 - dist_to_head);
    
    // Get brightness from the primary head
    float brightness = get_block_brightness(wrap_dist / block_size, tail_fade);
    
    // If Dual Chase mode, also consider the second head
    if (chase_mode == 2) {
        float dist_to_head2 = abs(uv.x - head2_pos);
        float wrap_dist2 = min(dist_to_head2, 1.0 - dist_to_head2);
        float brightness2 = get_block_brightness(wrap_dist2 / block_size, tail_fade);
        brightness = max(brightness, brightness2);
    }
    
    // Apply brightness to the chase color
    vec3 final_color = mix(bg_color, chase_color, brightness);
    
    // Output
    fragColor = vec4(final_color, 1.0);
}
