//@settings dtype=float32 format=rgba

// B pass: soft-knee luminance threshold + horizontal 9-tap Gaussian.
// Reads the __init__ pass output via auto-binding by name.
uniform sampler2D main_image;

//@slider min=0.0 max=1.0 value=0.55
uniform float threshold;
//@slider min=1 max=20 value=6
uniform float blur_radius;
//@slider min=0.0 max=2.0 value=0.8
uniform float bloom_knee;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;

    // soft-knee luminance threshold
    vec3 base = texture(main_image, uv, 0.0).rgb;
    float lum = dot(base, vec3(0.2126, 0.7152, 0.0722));
    float soft = smoothstep(threshold, threshold + bloom_knee, lum);

    // horizontal separable 9-tap Gaussian (radius from blur_radius, capped at 4 taps)
    int rad = int(clamp(blur_radius, 1.0, 20.0));
    if (rad > 4) rad = 4;

    vec4 acc = vec4(0.0);
    float wtot = 0.0;
    // fixed 9-tap weights (sigma=2): offsets 0..4
    float w0 = 0.2270;
    float w1 = 0.1945;
    float w2 = 0.1216;
    float w3 = 0.0540;
    float w4 = 0.0162;

    acc += texture(main_image, uv, 0.0) * w0; wtot += w0;
    if (rad >= 1) { acc += texture(main_image, uv + vec2(texel.x, 0.0), 0.0) * w1; acc += texture(main_image, uv - vec2(texel.x, 0.0), 0.0) * w1; wtot += w1 * 2.0; }
    if (rad >= 2) { acc += texture(main_image, uv + vec2(2.0 * texel.x, 0.0), 0.0) * w2; acc += texture(main_image, uv - vec2(2.0 * texel.x, 0.0), 0.0) * w2; wtot += w2 * 2.0; }
    if (rad >= 3) { acc += texture(main_image, uv + vec2(3.0 * texel.x, 0.0), 0.0) * w3; acc += texture(main_image, uv - vec2(3.0 * texel.x, 0.0), 0.0) * w3; wtot += w3 * 2.0; }
    if (rad >= 4) { acc += texture(main_image, uv + vec2(4.0 * texel.x, 0.0), 0.0) * w4; acc += texture(main_image, uv - vec2(4.0 * texel.x, 0.0), 0.0) * w4; wtot += w4 * 2.0; }

    vec4 hBlur = acc / wtot;

    // apply the soft-knee gate to the blurred result
    vec3 result = hBlur.rgb * soft;

    fragColor = vec4(clamp(result, vec3(0.0), vec3(1.0)), 1.0);
}
