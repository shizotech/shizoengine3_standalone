//@settings dtype=float16 format=rgba renderscale=0.25
// --- LensBlur, pass P: the input at a quarter of the size in linear light; alpha: the disc size there ---
#include lib/common.glsl

uniform sampler2D input;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 px = 1.0 / vec2(textureSize(input, 0));
    vec3 c = vec3(0.0);
    for (int y = 0; y < 4; y++)
        for (int x = 0; x < 4; x++)
            c += srgbToLinear(texture(input, uv + (vec2(x, y) - 1.5) * px).rgb);
    c /= 16.0;
    fragColor = vec4(c, circleOfConfusion(uv, luminance(linearToSrgb(c))));
}
