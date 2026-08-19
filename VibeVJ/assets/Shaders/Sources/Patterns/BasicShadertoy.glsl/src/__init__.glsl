// ============================================================
// BasicShadertoy - Shadertoy format example
// ============================================================
// This shader uses the Shadertoy-compatible format. The engine
// automatically detects the mainImage function and wraps the
// shader with the appropriate boilerplate code.
//
// All i* uniforms are automatically provided:
//   - iResolution: vec3 (width, height, aspect_ratio)
//   - iTime: float (current time)
//   - iFrame: int (auto-incrementing frame count)
//   - iMouse: vec4 (mouse position and click state)
//   - iChannel0-3: sampler2D (input textures)
// ============================================================

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Normalize coordinates
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.y = 1.0 - uv.y; // Flip Y for Shadertoy convention
    
    // Create animated kaleidoscope pattern
    vec2 centered = uv - 0.5;
    float dist = length(centered);
    float angle = atan(centered.y, centered.x);
    
    // Kaleidoscope folding
    float segments = 8.0;
    angle = mod(angle + 3.14159, 6.28318 / segments) - 3.14159 / segments;
    angle = abs(angle);
    
    // Create ring pattern
    float ring = sin(dist * 20.0 - iTime * 2.0) * 0.5 + 0.5;
    ring = pow(ring, 2.0);
    
    // Color based on angle and distance
    vec3 col = vec3(
        0.5 + 0.5 * sin(angle * 3.0 + iTime),
        0.5 + 0.5 * cos(angle * 5.0 + iTime * 0.7),
        0.5 + 0.5 * sin(dist * 10.0 - iTime * 1.5)
    );
    
    // Combine with rings
    col *= ring;
    
    // Dark background
    col = mix(vec3(0.02, 0.02, 0.05), col, 0.8);
    
    fragColor = vec4(col, 1.0);
}
