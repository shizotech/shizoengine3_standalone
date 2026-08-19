// BasicTime - A time-based animation demo
// Demonstrates the iTime uniform for creating animations
//
// This shader creates a pulsing circle effect that changes color and size
// based on the time uniform. The animation loops smoothly.

//@settings dtype=float32 format=rgba
//@slider min=0.0 max=5.0 value=1.0
uniform float speed;
//@float min=-10.0 max=10.0 value=0.0
uniform float offset;
//@slider min=1.0 max=20.0 value=5.0
uniform int rings;
//@rgb
uniform vec3 colorA;
//@rgb
uniform vec3 colorB;

uniform sampler2D in;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // uv coordinates centered at (0.5, 0.5)
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 centered = (uv - 0.5) * 2.0; // (-1,-1) to (1,1)
    
    // Create animated pulsing rings
    float dist = length(centered);
    float t = iTime * speed + offset;
    
    // Animated ring pattern
    float ring = 0.0;
    for (int i = 0; i < 20; i++) {
        if (i >= rings) break;
        float ringDist = float(i) / float(rings);
        float ringWidth = 0.05 + 0.02 * sin(t + float(i) * 0.5);
        float ringPos = 0.5 + 0.5 * sin(t * 0.7 + float(i) * 0.3);
        ring += smoothstep(ringWidth, 0.0, abs(dist - ringPos * ringPos));
    }
    
    // Pulsing circle
    float pulse = 0.5 + 0.5 * sin(t * 2.0);
    float circle = smoothstep(0.3 + 0.1 * pulse, 0.25 + 0.08 * pulse, dist);
    
    // Gradient color based on time
    vec3 col = mix(colorA, colorB, 0.5 + 0.5 * sin(t));
    
    // Combine effects
    vec3 result = col * (0.3 + 0.7 * ring) + col * circle * 0.5;
    
    // Mix with input
    vec4 inputColor = texture(in, uv);
    fragColor = vec4(mix(inputColor.rgb, result, 0.8), 1.0);
}
