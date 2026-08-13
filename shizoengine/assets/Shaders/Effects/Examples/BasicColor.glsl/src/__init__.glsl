// BasicColor - A simple color gradient effect
// Demonstrates basic color manipulation with user-controllable parameters
//
// This shader creates a smooth gradient that blends between two colors
// based on the uv coordinates and time.

//@settings dtype=float32 format=rgba
//@slider min=0.0 max=1.0 value=0.5
uniform float speed;
//@rgb
uniform vec3 color1;
//@rgb
uniform vec3 color2;

uniform sampler2D in;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // uv coordinates: (0,0) at bottom-left, (1,1) at top-right
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    // Calculate gradient based on uv.y with time animation
    float t = uv.y + sin(iTime * speed) * 0.1;
    t = mod(t, 1.0);
    
    // Smooth gradient between color1 and color2
    vec3 gradient = mix(color1, color2, smoothstep(0.0, 1.0, t));
    
    // Mix with input texture for a blended effect
    vec4 inputColor = texture(in, uv);
    fragColor = vec4(mix(inputColor.rgb, gradient, 0.7), 1.0);
}
