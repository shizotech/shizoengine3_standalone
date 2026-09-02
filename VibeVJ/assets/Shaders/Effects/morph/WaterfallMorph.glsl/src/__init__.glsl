// MFX1 WaterfallMorph - Distort input video like a flowing waterfall
// Shadertoy format (effect: needs input)
// Stretches / flows the input image (iChannel0) vertically like a
// waterfall, with thickness, layer count, layer blur, rotation and scale.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Thickness of the waterfall region (fraction of the frame)
//@slider min=0.1 max=1.0 value=0.6
uniform float thickness;

// Number of flow layers
//@int min=1 max=6 value=3
uniform int layer_count;

// Per-layer blur amount
//@slider min=0.0 max=1.0 value=0.4
uniform float layer_blur;

// Number of blur taps
//@int min=2 max=8 value=4
uniform int blur_taps;

// Rotation of the flow direction (0..1 = 0..360deg)
//@slider min=0.0 max=1.0 value=0.0
uniform float rotation;

// Overall scale
//@slider min=0.2 max=3.0 value=1.0
uniform float scale;

// Flow strength (how strongly the image is stretched downward)
//@slider min=0.0 max=1.0 value=0.6
uniform float strength;

// Flow speed
//@slider min=0.0 max=4.0 value=1.0
uniform float speed;

// Background fill for out-of-bounds input
//@rgb value=(0.02,0.02,0.05)
uniform vec3 background;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = uv - 0.5;
    p.x *= iResolution.x / iResolution.y;

    // rotate the sampling frame
    float ang = rotation * 6.2831853;
    float ca = cos(ang);
    float sa = sin(ang);
    vec2 rp = vec2(p.x * ca - p.y * sa, p.x * sa + p.y * ca) / max(scale, 0.001);

    float t = iTime * speed;

    // Waterfall region: |x| <= thickness/2
    float halfW = thickness * 0.5;
    // inband mask (1 inside the fall, 0 outside)
    float inband = 1.0 - smoothstep(halfW - 0.05, halfW + 0.05, abs(rp.x));

    // Waterfall distortion: within the band, stretch the y coordinate
    // downward (flow). We displace the sampled input y by a scrolling offset.
    // The displacement scales with distance from the top of the fall.
    // displacement: within-band, pull the input's vertical coord along the flow
    float dispY = -t * strength; // continuous downward scroll
    // streak jitter to give a "stretched" look
    float jitter = 0.05 * strength * sin(rp.x * 40.0 + t * 2.0);

    // Build the distorted UV in the rotated frame
    vec2 warped = rp;
    // Only displace inside the band
    warped.y = rp.y + (dispY * 0.2 + jitter) * inband;
    warped.x = rp.x + jitter * 0.5 * inband;

    // Convert back to input uv
    vec2 cp = vec2(warped.x * ca + warped.y * sa, -warped.x * sa + warped.y * ca) + 0.5;
    vec2 in_uv = cp;
    in_uv = clamp(in_uv, vec2(0.0), vec2(1.0));

    // Base sample of the input
    vec3 col = texture(iChannel0, in_uv).rgb;

    // Stack up to N blurred, slightly-offset copies for a soft waterfall motion-blur
    vec3 acc = col;
    for (int i = 1; i < 6; i++) {
        if (i >= layer_count) break;
        float radius = layer_blur * 3.0 * float(i);
        vec3 sum = vec3(0.0);
        float cnt = 0.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 off = vec2(x, y) * radius / iResolution.xy;
                if (abs(float(x)) <= blur_taps && abs(float(y)) <= blur_taps) {
                    // each layer samples the input at an extra downward offset
                    vec2 lu = clamp(in_uv + off + vec2(0.0, 0.015 * float(i) * strength), vec2(0.0), vec2(1.0));
                    sum += texture(iChannel0, lu).rgb;
                    cnt += 1.0;
                }
            }
        }
        vec3 blurred = (cnt > 0.0) ? sum / cnt : acc;
        acc = mix(acc, blurred, inband); // soften only inside the waterfall band
    }

    // Fallback background for out-of-bounds input
    vec3 bg = background;
    acc = mix(bg, acc, step(0.0, in_uv.x) * step(in_uv.x, 1.0) * step(0.0, in_uv.y) * step(in_uv.y, 1.0));

    fragColor = vec4(acc, 1.0);
}
