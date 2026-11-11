// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: common ----
const float TAU = 6.28318530717959;
// 2D rotation matrix. `rot2(a) * v` rotates v counter-clockwise by a radians. (cos, sin) is renormalized because GLSL ES leaves trig precision undefined: on SwiftShader and some mobile GPUs a raw cos/sin pair is far enough from unit length that rotations stop preserving distances.
mat2 rot2(float a) {
    vec2 cs = normalize(vec2(cos(a), sin(a)));
    return mat2(cs.x, cs.y, -cs.y, cs.x);
}

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
// --- TiltShift: what the passes share ---
// The blur grows with the distance from a sharp band (or ellipse), as the tilted lens of a miniature photo does.
// P1 .. P6 are a pyramid: each halves the one before with a smooth [1 3 3 1] filter, so P(k) is the input blurred by
// about 0.76 x 2^k pixels. __init__ picks the two levels around the blur a pixel needs and scales them up with a
// B-spline: any blur from 0 to about 50 pixels, different at every pixel, for 33 texture reads.

// Half size of the pass before, filtered with [1 3 3 1] / 8 in x and y (16 reads)
vec4 downsample(sampler2D t, vec2 uv) {
    ivec2 sz = textureSize(t, 0);
    ivec2 base = ivec2(floor(uv * vec2(sz) - 0.5)) - 1;
    ivec2 hi = sz - 1;
    vec4 w = vec4(1.0, 3.0, 3.0, 1.0) / 8.0;
    vec4 sum = vec4(0.0);
    for (int y = 0; y < 4; y++)
        for (int x = 0; x < 4; x++)
            sum += w[x] * w[y] * texelFetch(t, clamp(base + ivec2(x, y), ivec2(0), hi), 0);
    return sum;
}
