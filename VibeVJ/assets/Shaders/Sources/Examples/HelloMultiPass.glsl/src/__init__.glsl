//@settings dtype=float32 format=rgba
//@slider min=0.0 max=1.0 value=0.5
uniform float blend;

// ============================================================
// HelloMultiPass - Entry point for multi-pass rendering
// ============================================================
// This shader demonstrates multi-pass rendering by accepting
// the output of another pass as input. The 'A' uniform is
// automatically bound to src/A.glsl due to auto-binding.
// ============================================================

uniform sampler2D in;      // Default input
uniform sampler2D A;       // Auto-bound to src/A.glsl

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    // Sample both passes
    vec4 passA = texture(A, uv);
    vec4 input = texture(in, uv);
    
    // Blend between them
    fragColor = mix(input, passA, blend);
}
