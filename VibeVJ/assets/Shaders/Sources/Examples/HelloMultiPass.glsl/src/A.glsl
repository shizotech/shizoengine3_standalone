//@settings dtype=float32 format=rgba
//@slider min=0.0 max=6.28318 value=0.0
uniform float angle;
//@slider min=0.1 max=5.0 value=1.0
uniform float radius;

// ============================================================
// HelloMultiPass - Pass A (additional render pass)
// ============================================================
// This is the first render pass in a multi-pass setup.
// It creates an animated spiral pattern that is then
// blended with the main pass (__init__.glsl).
// ============================================================

uniform sampler2D in;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 centered = uv - 0.5;
    
    // Rotate coordinates
    float c = cos(angle);
    float s = sin(angle);
    vec2 rotated = vec2(
        centered.x * c - centered.y * s,
        centered.x * s + centered.y * c
    );
    
    // Create spiral pattern
    float dist = length(rotated);
    float spiral = sin(dist * 20.0 - iTime + rotated.x * 5.0);
    spiral = smoothstep(0.0, 1.0, spiral) * radius;
    
    // Color the spiral
    vec3 col = vec3(
        0.5 + 0.5 * sin(spiral + iTime),
        0.5 + 0.5 * cos(spiral * 1.3 + iTime * 0.7),
        0.5 + 0.5 * sin(spiral * 0.7 + iTime * 1.3)
    );
    
    // Blend with input
    vec4 inputColor = texture(in, uv);
    col = mix(inputColor.rgb, col, 0.8);
    
    fragColor = vec4(col, 1.0);
}
