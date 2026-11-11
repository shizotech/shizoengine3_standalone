//@settings dtype=float16 format=rgba renderscale=0.25
// --- Optical flow, pass G: the brightness at a quarter of the size, now (red) and one frame before (green) ---
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float now = dot(box4(input, uv).rgb, vec3(0.2126, 0.7152, 0.0722));
    float before = iFrame < 2 ? now : texture(feedback, uv).r;
    fragColor = vec4(now, before, 0.0, 1.0);
}
