// --- OpticalFlow: how the input moves, as a picture (the Optical Flow TOP of TouchDesigner) ---
// lib/common.glsl says how the flow is estimated. Output mode Vectors gives red / green = 0.5 + the motion, the
// format the port Displace map of Displace reads (Map mode Red/green offset) - link this into it and the picture
// is pushed the way things move. Color wheel shows the direction as the hue and the speed as the brightness.
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D F;

//@enum options=(Vectors, Color wheel, Motion mask, Over input) value=1
uniform int output_mode;
//@slider min=0.0 max=20.0 value=4.0
uniform float flow_gain;                 // how strongly a move shows: 1 = a move of 1/20 of the picture per frame is full
//@slider min=0.0 max=0.5 value=0.05
uniform float threshold;            // smaller moves count as still (camera noise)

vec3 hueColor(float h) {
    return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 f = sampleLinear(F, uv).xyz;
    // the flow in units where 1 = 1/20 of the picture per frame, times the gain
    vec2 v = f.xy * 20.0 * flow_gain;
    float m = length(v);
    float moving = smoothstep(threshold, threshold * 1.5 + 0.01, m);
    v *= moving;
    m *= moving;
    if (output_mode == 0) {
        fragColor = vec4(0.5 + 0.5 * clamp(v, -1.0, 1.0), clamp(m, 0.0, 1.0), 1.0);
        return;
    }
    vec3 wheel = hueColor(atan(v.y, v.x + 1e-6) / TAU + 0.5) * clamp(m, 0.0, 1.0);
    if (output_mode == 1)
        fragColor = vec4(wheel, 1.0);
    else if (output_mode == 2)
        fragColor = vec4(vec3(clamp(m, 0.0, 1.0)), 1.0);
    else {
        vec4 src = texture(input, uv);
        fragColor = vec4(mix(src.rgb * 0.6, wheel / max(max(wheel.r, max(wheel.g, wheel.b)), 1e-3),
                             clamp(m, 0.0, 1.0) * 0.8), src.a);
    }
}
