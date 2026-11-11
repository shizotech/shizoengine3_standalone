// --- Optical flow: what the passes share (the same files are in OpticalFlow and FlowSmear) ---
// A Lucas-Kanade estimate on two levels. G (a quarter of the size) keeps the brightness of this frame (red) and of
// the frame before (green, from its own last frame); G2 is a sixteenth. F2 solves the flow on G2, where a move of one
// texel is 16 pixels; F refines it on G: it moves the old frame by the coarse flow and solves for what is left.
// Each solve sums the brightness slopes over a 5 x 5 window (the 2 x 2 normal equations, a little regularised).
// The flow is in parts of the picture per frame (x to the right, y up), so it does not depend on the size.
// F keeps a share of its last result (Smoothing) against jitter; blue is the confidence of the estimate.

//@slider min=0.0 max=0.95 value=0.5
uniform float smoothing;            // keeps a share of the last flow: steadier, slower

// Brightness of a pass at uv, bilinear (passes are not filtered); ch picks the channel
float sampleChannel(sampler2D t, vec2 uv, int ch) {
    ivec2 sz = textureSize(t, 0);
    vec2 p = uv * vec2(sz) - 0.5;
    ivec2 i0 = ivec2(floor(p));
    vec2 f = p - floor(p);
    ivec2 hi = sz - 1;
    vec4 a = texelFetch(t, clamp(i0, ivec2(0), hi), 0);
    vec4 b = texelFetch(t, clamp(i0 + ivec2(1, 0), ivec2(0), hi), 0);
    vec4 c = texelFetch(t, clamp(i0 + ivec2(0, 1), ivec2(0), hi), 0);
    vec4 d = texelFetch(t, clamp(i0 + ivec2(1, 1), ivec2(0), hi), 0);
    vec4 v = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    return ch == 0 ? v.r : v.g;
}

vec4 sampleLinear(sampler2D t, vec2 uv) {
    ivec2 sz = textureSize(t, 0);
    vec2 p = uv * vec2(sz) - 0.5;
    ivec2 i0 = ivec2(floor(p));
    vec2 f = p - floor(p);
    ivec2 hi = sz - 1;
    vec4 a = texelFetch(t, clamp(i0, ivec2(0), hi), 0);
    vec4 b = texelFetch(t, clamp(i0 + ivec2(1, 0), ivec2(0), hi), 0);
    vec4 c = texelFetch(t, clamp(i0 + ivec2(0, 1), ivec2(0), hi), 0);
    vec4 d = texelFetch(t, clamp(i0 + ivec2(1, 1), ivec2(0), hi), 0);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Average of the 4 x 4 texels of t that this texel covers (t has 4 times the size)
vec4 box4(sampler2D t, vec2 uv) {
    ivec2 sz = textureSize(t, 0);
    ivec2 base = ivec2(floor(uv * vec2(sz) - 0.5)) - 1;
    ivec2 hi = sz - 1;
    vec4 sum = vec4(0.0);
    for (int y = 0; y < 4; y++)
        for (int x = 0; x < 4; x++)
            sum += texelFetch(t, clamp(base + ivec2(x, y), ivec2(0), hi), 0);
    return sum / 16.0;
}

// Lucas-Kanade on t (red: now, green: before) around uv, the old frame moved by v0 (uv per frame) first.
// Returns the flow (uv per frame) and the confidence (0 .. 1)
vec3 lucasKanade(sampler2D t, vec2 uv, vec2 v0) {
    vec2 sz = vec2(textureSize(t, 0));
    vec2 px = 1.0 / sz;
    float sxx = 0.0, sxy = 0.0, syy = 0.0, bx = 0.0, by = 0.0;
    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            vec2 q = uv + vec2(x, y) * px;
            float w = exp(-0.25 * float(x * x + y * y));
            float ix = 0.5 * (texture(t, q + vec2(px.x, 0.0)).r - texture(t, q - vec2(px.x, 0.0)).r);
            float iy = 0.5 * (texture(t, q + vec2(0.0, px.y)).r - texture(t, q - vec2(0.0, px.y)).r);
            float now = texture(t, q).r;
            float before = sampleChannel(t, q - v0, 1);
            float diff = before - now;
            sxx += w * ix * ix;
            sxy += w * ix * iy;
            syy += w * iy * iy;
            bx += w * ix * diff;
            by += w * iy * diff;
        }
    }
    float reg = 1e-4;
    sxx += reg;
    syy += reg;
    float det = sxx * syy - sxy * sxy;
    vec2 dv = vec2(syy * bx - sxy * by, sxx * by - sxy * bx) / det;     // in texels of t
    // the smaller eigenvalue: how well the window pins the motion down (flat or one-edge windows do not)
    float tr = sxx + syy;
    float lmin = 0.5 * (tr - sqrt(max(tr * tr - 4.0 * det, 0.0)));
    float conf = smoothstep(2e-4, 3e-3, lmin);
    dv = clamp(dv, -2.0, 2.0) * conf;
    return vec3(v0 + dv * px, conf);
}
