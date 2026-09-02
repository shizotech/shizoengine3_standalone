// BasicFeedback - A feedback loop effect creating trails and echoes
// Demonstrates how to use the 'feedback' uniform for recursive effects
//
// This shader combines the input texture with itself (feedback) to create
// a ghosting/trail effect. The feedback uniform automatically binds to the
// previous frame's output.

//@settings dtype=float32 format=rgba
//@slider min=0.0 max=0.99 value=0.95
uniform float feedbackAmount;
//@slider min=0.0 max=1.0 value=0.1
uniform float fade;
//@vec2 min=(-0.1,-0.1) max=(0.1,0.1) value=(0.0,0.0)
uniform vec2 offset;

uniform sampler2D input;
uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // uv coordinates from input
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    // Sample the input
    vec4 inputColor = texture(input, uv);
    
    // Sample the feedback (previous frame) with slight offset for motion
    vec2 feedbackUv = uv + offset;
    vec4 feedbackColor = texture(feedback, feedbackUv);
    
    // Combine input with feedback
    // feedbackAmount controls how much of the previous frame to keep
    // fade adds a global fade to prevent overflow
    vec3 result = mix(inputColor.rgb, feedbackColor.rgb, feedbackAmount);
    result *= (1.0 - fade);
    
    fragColor = vec4(result, 1.0);
}
