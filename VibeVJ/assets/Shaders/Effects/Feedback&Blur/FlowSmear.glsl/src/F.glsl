//@settings dtype=float32 format=rgba renderscale=0.25
// --- Optical flow, pass F: the flow refined on G from the coarse one, smoothed over time ---
#include lib/common.glsl

uniform sampler2D G;
uniform sampler2D F2;
uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 coarse = sampleLinear(F2, uv).xy;
    vec3 flow = lucasKanade(G, uv, coarse);
    vec3 last = iFrame < 2 ? flow : texture(feedback, uv).xyz;
    fragColor = vec4(mix(flow, last, smoothing), 1.0);
}
