//@settings dtype=float32 format=rgba

// ============================================================
// HelloBasic - Simplest possible shader using native format
// ============================================================
// This is the most basic shader demonstrating the native engine
// format. It uses v_uv (predefined UV coordinate) and outputs
// a solid color with a subtle gradient based on position.
// ============================================================

// The 'in' uniform is auto-bound to the default input texture
uniform sampler2D in;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    // Sample the input texture
    vec4 color = texture(in, uv);
    
    // Create a subtle gradient overlay based on position
    float gradient = uv.y * 0.5 + 0.5;
    
    // Mix between a blue-ish tone and the input color
    vec3 col = mix(vec3(0.1, 0.2, 0.4), color.rgb, gradient * 0.3);
    
    // Output the result
    fragColor = vec4(col, 1.0);
}
