// ============================================================
// HelloShadertoy - Shadertoy-compatible format
// ============================================================
// This shader uses the Shadertoy format which is automatically
// detected by the engine when it contains a mainImage function.
// The engine wraps this with boilerplate code to convert between
// native and Shadertoy coordinate systems.
// ============================================================
//
// Key Shadertoy uniforms (auto-provided by engine):
//   - iResolution: vec3 (width, height, aspect_ratio)
//   - iTime: float (current time)
//   - iFrame: int (auto-incrementing frame count)
//   - iMouse: vec4 (mouse position and click state)
//   - iChannel0-3: sampler2D (input textures)
// ============================================================

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Normalize coordinates to 0..1 range
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    // Flip Y axis to match Shadertoy convention (optional)
    uv.y = 1.0 - uv.y;
    
    // Calculate distance from center
    float dist = length(uv - 0.5);
    
    // Create an animated circle pattern
    float circle = smoothstep(0.4, 0.39, dist) * 
                   smoothstep(0.15, 0.14, dist);
    
    // Animate the circle with time
    float pulse = sin(iTime * 2.0) * 0.1 + 0.5;
    float animatedCircle = smoothstep(pulse + 0.01, pulse, dist) *
                           smoothstep(pulse - 0.1, pulse - 0.11, dist);
    
    // Color based on position and time
    vec3 col = vec3(
        0.5 + 0.5 * sin(uv.x * 3.14 + iTime),
        0.5 + 0.5 * sin(uv.y * 3.14 + iTime * 0.7),
        0.5 + 0.5 * cos(uv.x * 3.14 + uv.y * 3.14 + iTime * 0.5)
    );
    
    // Combine background gradient with circle
    vec3 bg = vec3(0.05, 0.05, 0.1);
    fragColor = vec4(mix(bg, col, circle + animatedCircle * 0.5), 1.0);
}
