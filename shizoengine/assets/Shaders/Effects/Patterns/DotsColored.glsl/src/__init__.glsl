
//@settings dtype=float32 format=rgba

// Shadertoy shader: Random moving colored dots with shadow dots
// Author: ChatGPT (GPT-5 Mini)
// License: Free to use / modify

// --------------------------------
// Shadertoy inputs:
// iTime: time in seconds
// iResolution: viewport resolution
// --------------------------------

#define NUM_DOTS 50
#define SHADOW_COLOR vec3(0.1, 0.1, 0.1)

vec3 palette[5] = vec3[](
    vec3(1.0, 0.2, 0.2),
    vec3(0.2, 1.0, 0.2),
    vec3(0.2, 0.2, 1.0),
    vec3(1.0, 1.0, 0.2),
    vec3(1.0, 0.2, 1.0)
);

// Simple hash function for pseudo-random numbers
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

// 2D hash
vec2 hash2(float n) {
    return vec2(hash(n), hash(n + 1.0));
}

// Smooth pseudo-random movement
vec2 getDotPosition(int id, float t) {
    float speed = 0.2 + 0.3 * hash(float(id) * 12.34);
    vec2 seed = hash2(float(id) * 45.67);
    
    // Use a combination of sin/cos for natural, non-repeating motion
    vec2 pos = seed + 0.5 * vec2(
        sin(t * speed + seed.x * 10.0),
        cos(t * speed + seed.y * 10.0)
    );
    
    // Wrap around
    return fract(pos);
}

// Get dot color from palette
vec3 getDotColor(int id) {
    int idx = int(mod(float(id), float(palette.length())));
    return palette[idx];
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec3 col = vec3(0.0);
    
    for (int i = 0; i < NUM_DOTS; i++) {
        vec2 dotPos = getDotPosition(i, iTime);
        float radius = 0.01 + 0.01 * hash(float(i) * 78.9);
        
        // Distance from current fragment
        float d = length(uv - dotPos);
        float intensity = smoothstep(radius, 0.0, d);
        
        // Mix shadow and colored dots
        vec3 dotColor = (i % 7 == 0) ? SHADOW_COLOR : getDotColor(i);
        col += dotColor * intensity;
    }
    
    // Output
    fragColor = vec4(col, 1.0);
}
