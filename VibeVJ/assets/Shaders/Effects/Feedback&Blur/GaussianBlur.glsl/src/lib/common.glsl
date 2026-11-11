// --- GaussianBlur: what every pass shares (the controls, the size of the blur, the 1D Gaussian) ---
// The blur is a true separable Gaussian: a horizontal pass, then a vertical one. Small radii run at full size (H and
// the vertical half in __init__). Large radii run on smaller copies of the picture, so the number of taps stays low:
// D1 is the input boxed down to a quarter (4 x 4 pixels per texel), H1 / V1 blur it; D2 is a sixteenth, H2 / V2 blur
// that. __init__ blends the three levels by the radius and scales the small ones back up with a smooth B-spline.
// What the box filters and the B-spline already blur is taken off the Gaussian of that level, so the levels match and
// the radius grows smoothly.

//@slider min=0.0 max=200.0 value=12.0
uniform float radius;               // sigma of the Gaussian, in pixels of a 1080p picture (it scales with the size)
//@slider min=-1.0 max=1.0 value=0.0
uniform float stretch;              // > 0 blurs more across, < 0 more up and down
//@slider min=0.0 max=2.0 value=0.0
uniform float beat_pump;            // the radius grows by this share at every beat and falls back
//@slider min=1.0 max=12.0 value=4.0
uniform float pump_decay;           // how fast the pump falls back within the beat

// Node pixels per texel of each level, and the variance (in node pixels^2) the box filters and the B-spline upsampling
// add at that level: box of w pixels (w^2 - 1) / 12, cubic B-spline 1/3 of a texel^2
const float LEVEL1_SCALE = 4.0;
const float LEVEL2_SCALE = 16.0;
const float LEVEL1_EXTRA = 1.25 + 16.0 / 3.0;
const float LEVEL2_EXTRA = 21.25 + 256.0 / 3.0;
const int MAX_TAPS = 96;

// Sigma along x and y, in units of the picture height (radius is in pixels of a 1080 high picture)
vec2 blurSigma() {
    float pump = beat_pump * pow(1.0 - fract(iTime), pump_decay);
    float s = radius / 1080.0 * (1.0 + pump);
    return s * clamp(vec2(1.0 + stretch, 1.0 - stretch), 0.0, 2.0);
}

// Sigma for one level, in node pixels, after taking off what that level adds by itself
float levelSigma(float sigmaPx, float extraVariance) {
    return sqrt(max(sigmaPx * sigmaPx - extraVariance, 0.0));
}

// 1D Gaussian of t around uv along dir (one texel of t), sigma in texels of t
vec4 gauss1D(sampler2D t, vec2 uv, vec2 dir, float sigma) {
    vec4 c = texture(t, uv);
    if (sigma < 0.05)
        return c;
    int n = min(int(ceil(3.0 * sigma)), MAX_TAPS);
    float k = -0.5 / (sigma * sigma);
    vec4 sum = c;
    float wsum = 1.0;
    for (int i = 1; i <= n; i++) {
        float w = exp(k * float(i * i));
        vec2 o = dir * float(i);
        sum += w * (texture(t, uv + o) + texture(t, uv - o));
        wsum += 2.0 * w;
    }
    return sum / wsum;
}

// Average of the 4 x 4 texels of t around uv (t is 4 times the size of this pass): a box downsample
vec4 box4(sampler2D t, vec2 uv) {
    vec2 px = 1.0 / vec2(textureSize(t, 0));
    vec4 sum = vec4(0.0);
    for (int y = 0; y < 4; y++)
        for (int x = 0; x < 4; x++)
            sum += texture(t, uv + (vec2(x, y) - 1.5) * px);
    return sum / 16.0;
}

// Share of each level for a sigma of s node pixels: full size up to 6 px, a quarter from 10 to 36, a sixteenth above 44
vec3 levelWeights(float s) {
    float w0 = 1.0 - smoothstep(6.0, 10.0, s);
    float w2 = smoothstep(36.0, 44.0, s);
    return vec3(w0, 1.0 - w0 - w2, w2);
}
