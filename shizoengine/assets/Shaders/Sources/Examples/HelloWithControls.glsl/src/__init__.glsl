//@settings dtype=float32 format=rgba
//@slider min=0.0 max=1.0 value=0.3
uniform float intensity;
//@float min=-10.0 max=10.0 value=1.0
uniform float speed;
//@int min=0 max=10 value=3
uniform int segments;
//@vec2 min=(0.0,0.0) max=(2.0,2.0) value=(1.0,1.0)
uniform vec2 resolution_scale;
//@rgb
uniform vec3 base_color;
//@rgb
uniform vec3 accent_color;
//@slidervec2 min=(0.0,0.0) max=(1.0,1.0) value=(0.5,0.5)
uniform vec2 center;

// ============================================================
// HelloWithControls - Demonstrates all annotation types
// ============================================================
// This shader demonstrates every annotation type available:
//   - @slider: float slider control
//   - @float: float number input
//   - @int: integer number input
//   - @vec2: two-value vector input
//   - @rgb: color picker (RGB sliders)
//   - @slidervec2: two sliders for precise control
// ============================================================

uniform sampler2D in;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy * resolution_scale;
    
    // Create segmented pattern based on controls
    float angle = atan(uv.y - center.y, uv.x - center.x);
    float dist = length(uv - center);
    
    // Wrap angle into segments
    float segAngle = mod(angle + 3.14159, 6.28318 / float(segments)) - 3.14159 / float(segments);
    float segFactor = 1.0 - smoothstep(0.0, 3.14159 / float(segments), abs(segAngle));
    
    // Animated rings
    float ring = abs(sin(dist * 20.0 - iTime * speed));
    ring = pow(ring, 3.0) * segFactor;
    
    // Combine colors
    vec3 col = mix(base_color, accent_color, segFactor * 0.5 * (sin(iTime + dist * 5.0) * 0.5 + 0.5));
    col *= ring * intensity;
    
    // Add subtle input blend
    vec4 inputColor = texture(in, fragCoord.xy / iResolution.xy);
    col = mix(col, inputColor.rgb, 0.2);
    
    fragColor = vec4(col, 1.0);
}
