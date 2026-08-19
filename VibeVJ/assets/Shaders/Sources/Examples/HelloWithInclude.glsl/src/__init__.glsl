//@settings dtype=float32 format=rgba
//@slider min=0.0 max=10.0 value=3.0
uniform float octaves;
//@slider min=-2.0 max=2.0 value=0.5
uniform float lacunarity;
//@slider min=0.0 max=1.0 value=0.5
uniform float persistence;

// ============================================================
// HelloWithInclude - Demonstrates #include system
// ============================================================
// This shader includes helper functions from a subdirectory.
// The path is relative to the src/ directory.
// 
// To use: #include helpers/math.glsl
// ============================================================

#include helpers/math.glsl

uniform sampler2D in;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    // Use included FBM function for organic noise pattern
    vec2 p = uv * 5.0;
    float n = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    
    // Manual FBM using included hash/noise functions
    for (float i = 0.0; i < octaves; i++) {
        n += amp * noise(p * freq);
        freq *= lacunarity;
        amp *= persistence;
    }
    
    // Create flowing pattern
    float t = iTime * 0.3;
    vec2 q = uv + vec2(n + t, noise(uv * 2.0 + t));
    
    // Second pass of noise
    float n2 = 0.0;
    amp = 0.5;
    freq = 1.0;
    for (float i = 0.0; i < octaves; i++) {
        n2 += amp * noise(q * freq);
        freq *= lacunarity;
        amp *= persistence;
    }
    
    // Color based on noise values
    vec3 col = vec3(
        0.5 + 0.5 * sin(n * 3.14 + iTime),
        0.5 + 0.5 * cos(n2 * 3.14 + iTime * 0.7),
        0.2 + 0.3 * n2
    );
    
    // Blend with input
    vec4 inputColor = texture(in, uv);
    col = mix(inputColor.rgb, col, 0.6);
    
    fragColor = vec4(col, 1.0);
}
