// SolidColor - Simple solid color fill with smooth animation
// Cycles smoothly between base_color and a secondary color over time
//
// ==== Custom Uniform Controls ====

//@rgb value=(0.2, 0.6, 1.0)
uniform vec3 base_color;

//@rgb value=(0.0,0.0,0.0)
uniform vec3 bg_color;

//@float min=0.01 max=3.0 value=0.5
uniform float speed;

// Standard hash function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth cycle animation
// Returns a value that oscillates smoothly between 0.0 and 1.0
float smooth_cycle(float t) {
    return smoothstep(0.0, 1.0, sin(t * 3.14159265) * 0.5 + 0.5);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalize coordinates to 0..1 range
    vec2 uv = fragCoord / iResolution.xy;

    // Calculate animation parameter based on time and speed
    float anim_time = iTime * speed;

    // Start with bg_color as background
    vec3 current_color = bg_color;
    
    // Create smooth cycling between base_color and a secondary color
    float cycle = smooth_cycle(anim_time);

    // Secondary color: a complementary hue derived from base_color
    vec3 secondary_color = vec3(
        1.0 - base_color.r,
        1.0 - base_color.g,
        1.0 - base_color.b
    );

    // Mix between base_color and secondary_color based on cycle
    vec3 animated_color = mix(base_color, secondary_color, cycle);

    // Blend animated color on top of bg_color
    current_color = mix(bg_color, animated_color, 0.7 + 0.3 * cycle);

    // Fill the entire screen with the blended color
    fragColor = vec4(current_color, 1.0);
}
