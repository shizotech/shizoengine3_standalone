// --- LensBlur: a lens blur with bokeh, focus and blades (the Depth of Field / Bokeh of TouchDesigner) ---
// lib/common.glsl says how the passes work together.
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D B;

//@slider min=0.0 max=1.0 value=1.0
uniform float amount;               // mixes back to the input
//@enum options=(Picture, Focus map) value=0
uniform int view;                   // Focus map shows the size of the discs: black is sharp, white the biggest

// Cubic B-spline over 4 x 4 texels: a smooth upscale of B
vec4 sampleBSpline(sampler2D t, vec2 uv) {
    ivec2 sz = textureSize(t, 0);
    vec2 p = uv * vec2(sz) - 0.5;
    vec2 i = floor(p);
    vec2 f = p - i;
    vec2 f2 = f * f;
    vec2 f3 = f2 * f;
    vec2 w[4];
    w[0] = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
    w[1] = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
    w[2] = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
    w[3] = f3 / 6.0;
    ivec2 base = ivec2(i) - 1;
    ivec2 hi = sz - 1;
    vec4 sum = vec4(0.0);
    for (int y = 0; y < 4; y++) {
        vec4 row = vec4(0.0);
        for (int x = 0; x < 4; x++)
            row += w[x].x * texelFetch(t, clamp(base + ivec2(x, y), ivec2(0), hi), 0);
        sum += w[y].y * row;
    }
    return sum;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 src = texture(input, uv);
    float coc = circleOfConfusion(uv, luminance(src.rgb));
    if (view == 1) {
        fragColor = vec4(vec3(coc), 1.0);
        return;
    }
    float cocPx = coc * maxRadiusPx();
    if (cocPx < 0.5 || amount <= 0.0) {
        fragColor = src;
        return;
    }
    vec3 bokeh = linearToSrgb(sampleBSpline(B, uv).rgb);
    // small discs: the full-size input keeps the edges that the quarter size would soften
    vec3 col = mix(src.rgb, bokeh, smoothstep(0.5, 4.0, cocPx));
    col += (interleavedGradientNoise(floor(fragCoord)) - 0.5) / 255.0;
    fragColor = vec4(mix(src.rgb, clamp(col, 0.0, 1.0), amount), src.a);
}
