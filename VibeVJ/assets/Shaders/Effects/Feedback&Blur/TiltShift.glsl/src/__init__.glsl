// --- TiltShift: a miniature look - a sharp band, blur growing away from it, stronger colours ---
// lib/common.glsl says how the blur pyramid works.
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D P1;
uniform sampler2D P2;
uniform sampler2D P3;
uniform sampler2D P4;
uniform sampler2D P5;
uniform sampler2D P6;

//@slider min=0.0 max=48.0 value=16.0
uniform float blur_amount;          // the strongest blur, in pixels of a 1080p picture
//@enum options=(Band, Ellipse) value=0
uniform int focus_shape;
//@slidervec2 min=(0.0,0.0) max=(1.0,1.0) value=(0.5,0.45)
uniform vec2 focus_position;
//@slider min=-90.0 max=90.0 value=0.0
uniform float focus_angle;          // degrees: turns the band
//@slider min=0.0 max=1.0 value=0.2
uniform float focus_width;          // the sharp part, in parts of the picture height
//@slider min=0.01 max=1.0 value=0.3
uniform float focus_falloff;        // how far it takes to get fully blurred
//@slider min=0.2 max=5.0 value=1.6
uniform float ellipse_aspect;       // Ellipse: wider (> 1) or taller (< 1)
//@slider min=0.0 max=0.5 value=0.0
uniform float focus_sweep;          // the sharp part travels up and down by this much
//@slider min=1.0 max=32.0 value=8.0
uniform float sweep_beats;          // beats for one sweep there and back
//@slider min=0.0 max=2.0 value=1.3
uniform float saturation_amount;           // the toy look: stronger colours
//@slider min=0.5 max=2.0 value=1.15
uniform float contrast;
//@slider min=0.0 max=1.0 value=0.25
uniform float vignette_amount;
//@enum options=(Picture, Blur map) value=0
uniform int view;                   // Blur map: red shows where it blurs and how much
//@slider min=0.0 max=1.0 value=1.0
uniform float amount;               // mixes back to the input

// Cubic B-spline over 4 x 4 texels: a smooth upscale of a pyramid level
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

vec4 level(int k, vec2 uv) {
    if (k == 1) return sampleBSpline(P1, uv);
    if (k == 2) return sampleBSpline(P2, uv);
    if (k == 3) return sampleBSpline(P3, uv);
    if (k == 4) return sampleBSpline(P4, uv);
    if (k == 5) return sampleBSpline(P5, uv);
    return sampleBSpline(P6, uv);
}

// 0 in the sharp part, 1 where the blur is full
float blurMap(vec2 uv) {
    vec2 aspect = vec2(iResolution.x / iResolution.y, 1.0);
    vec2 c = focus_position;
    c.y += focus_sweep * sin(iTime * TAU / max(sweep_beats, 0.01));
    vec2 p = rot2(-radians(focus_angle)) * ((uv - c) * aspect);
    float d;
    if (focus_shape == 1)
        d = length(p * vec2(1.0 / max(ellipse_aspect, 0.01), 1.0));
    else
        d = abs(p.y);
    return smoothstep(0.5 * focus_width, 0.5 * focus_width + focus_falloff, d);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 src = texture(input, uv);
    float m = blurMap(uv);
    if (view == 1) {
        fragColor = vec4(mix(src.rgb * 0.5, vec3(1.0, 0.1, 0.1), m * 0.8), 1.0);
        return;
    }

    // blur in pixels of this picture, then the pyramid level: P(k) blurs by about 0.76 * 2^k
    float sigma = m * blur_amount / 1080.0 * iResolution.y;
    vec4 col = src;
    if (sigma > 0.05) {
        float lv = clamp(log2(sigma / 0.764), 0.0, 6.0);
        if (sigma < 1.528) {
            col = mix(src, level(1, uv), sigma / 1.528);
        } else {
            int k = int(floor(lv));
            float f = lv - float(k);
            col = level(max(k, 1), uv);
            if (k < 6 && f > 0.0)
                col = mix(col, level(k + 1, uv), f);
        }
    }

    // the miniature colours, everywhere
    vec3 c = col.rgb;
    c = mix(vec3(luminance(c)), c, saturation_amount);
    c = (c - 0.5) * contrast + 0.5;
    vec2 q = uv - 0.5;
    c *= 1.0 - vignette_amount * smoothstep(0.2, 0.9, dot(q, q) * 2.0);
    c += (interleavedGradientNoise(floor(fragCoord)) - 0.5) / 255.0;
    fragColor = vec4(mix(src.rgb, clamp(c, 0.0, 1.0), amount), src.a);
}
