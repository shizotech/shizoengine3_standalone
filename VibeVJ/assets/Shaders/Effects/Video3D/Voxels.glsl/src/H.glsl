//@settings dtype=float16 format=rgba renderscale=0.25
// --- Voxels, pass H: the picture at a quarter of the size (4 reads a texel against flicker), colour in rgb ---
#include lib/common.glsl

uniform sampler2D input;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 d = 0.5 / iResolution.xy;
    vec3 c = 0.25 * (texture(input, uv + vec2(-d.x, -d.y)).rgb + texture(input, uv + vec2(d.x, -d.y)).rgb
                   + texture(input, uv + vec2(-d.x, d.y)).rgb + texture(input, uv + vec2(d.x, d.y)).rgb);
    fragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
