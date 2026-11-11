// --- GaussianBlur: a separable Gaussian blur with a radius from 0 to 200 pixels (the Blur TOP of TouchDesigner) ---
// This pass does the vertical half of the small blur and blends in the large ones (passes H, D1, H1, V1, D2, H2, V2;
// lib/common.glsl says how). Output mode turns the blur into a glow, a sharpener or a high pass; the mask limits it to
// the bright or dark parts of the input, or to where a second picture (port Blur mask) is bright.
#include lib/common.glsl

// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: noise ----
// Interleaved gradient noise: cheap per-pixel noise whose 3x3 neighborhoods are nearly stratified. Not a hash. pixel must be integer pixel coordinates (floor(fragCoord)). The frame overload animates it for accumulation and TAA.
float interleavedGradientNoise(vec2 pixel) {
    return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}
float interleavedGradientNoise(vec2 pixel, int frame) {
    return interleavedGradientNoise(pixel + 5.588238 * float(frame % 64));
}

// ---- shader-skills library: color ----
// Relative luminance of linear Rec.709 / sRGB color.
float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// ---- shader ----
uniform sampler2D input;
uniform sampler2D H;
uniform sampler2D V1;
uniform sampler2D V2;
// A picture that says where to blur (bright = blur), for Mask mode Mask input
uniform sampler2D blur_mask;

//@enum options=(Blur, Glow, Sharpen, High pass) value=0
uniform int output_mode;            // Glow adds the blur on top, Sharpen pushes away from it, High pass keeps the detail
//@slider min=0.0 max=4.0 value=1.0
uniform float strength;             // how much Glow, Sharpen and High pass do
//@enum options=(Off, Bright parts, Dark parts, Mask input) value=0
uniform int mask_mode;              // where the effect applies
//@slider min=0.0 max=1.0 value=0.5
uniform float mask_level;
//@slider min=0.0 max=1.0 value=0.2
uniform float mask_softness;
//@slider min=0.0 max=1.0 value=1.0
uniform float amount;               // mixes back to the input

// Smooth upsampling of a small level: a cubic B-spline over 4 x 4 texels (the textures of passes are not filtered)
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
    vec2 sig = blurSigma() * iResolution.y;
    float s = max(sig.x, sig.y);
    if (s < 0.05 || amount <= 0.0) {
        fragColor = src;
        return;
    }

    vec3 lw = levelWeights(s);
    vec4 blurred = vec4(0.0);
    if (lw.x > 0.0)
        blurred += lw.x * gauss1D(H, uv, vec2(0.0, 1.0 / iResolution.y), sig.y);
    if (lw.y > 0.0)
        blurred += lw.y * sampleBSpline(V1, uv);
    if (lw.z > 0.0)
        blurred += lw.z * sampleBSpline(V2, uv);

    vec4 col = blurred;
    if (output_mode == 1)
        col = vec4(src.rgb + blurred.rgb * strength, max(src.a, blurred.a));
    else if (output_mode == 2)
        col = vec4(src.rgb + (src.rgb - blurred.rgb) * strength, src.a);
    else if (output_mode == 3)
        col = vec4(0.5 + (src.rgb - blurred.rgb) * strength, src.a);

    float m = 1.0;
    if (mask_mode > 0) {
        float soft = max(mask_softness, 0.001) * 0.5;
        float l = mask_mode == 3 ? luminance(texture(blur_mask, uv).rgb) : luminance(src.rgb);
        m = smoothstep(mask_level - soft, mask_level + soft, l);
        if (mask_mode == 2)
            m = 1.0 - m;
    }
    col = mix(src, col, m * amount);
    // a smooth blur in 8 bits shows steps: half a step of noise hides them
    col.rgb += (interleavedGradientNoise(floor(fragCoord)) - 0.5) / 255.0;
    fragColor = clamp(col, 0.0, 1.0);
}
