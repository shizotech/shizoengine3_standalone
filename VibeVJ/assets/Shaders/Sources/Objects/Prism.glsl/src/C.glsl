//@settings dtype=float16 format=rgba renderscale=0.0625
// --- pass C: B at a quarter of its size again (a sixteenth of the picture), for the wide glow ---
#include lib/common.glsl

uniform sampler2D B;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 px = 1.0 / vec2(textureSize(B, 0));
    vec3 c = passBilinear(B, uv + vec2(-1.0, -1.0) * px).rgb + passBilinear(B, uv + vec2(1.0, -1.0) * px).rgb
           + passBilinear(B, uv + vec2(-1.0, 1.0) * px).rgb + passBilinear(B, uv + vec2(1.0, 1.0) * px).rgb;
    fragColor = vec4(c * 0.25, 1.0);
}
