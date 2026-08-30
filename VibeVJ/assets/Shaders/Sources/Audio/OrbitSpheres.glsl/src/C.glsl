//@settings dtype=float32 format=rgba

// C pass: vertical 9-tap Gaussian over the B (horizontal-blur) pass.
// This completes the separable blur; __init__ adds C.rgb * glow_intensity as bloom.
uniform sampler2D B;

//@slider min=1 max=20 value=6
uniform float blur_radius;
//@slider min=0.0 max=4.0 value=1.0
uniform float bloom_strength;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;

    // vertical separable 9-tap Gaussian (radius from blur_radius, capped at 4 taps)
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

    acc += texture(B, uv, 0.0) * w0; wtot += w0;
    if (rad >= 1) { acc += texture(B, uv + vec2(0.0, texel.y), 0.0) * w1; acc += texture(B, uv - vec2(0.0, texel.y), 0.0) * w1; wtot += w1 * 2.0; }
    if (rad >= 2) { acc += texture(B, uv + vec2(0.0, 2.0 * texel.y), 0.0) * w2; acc += texture(B, uv - vec2(0.0, 2.0 * texel.y), 0.0) * w2; wtot += w2 * 2.0; }
    if (rad >= 3) { acc += texture(B, uv + vec2(0.0, 3.0 * texel.y), 0.0) * w3; acc += texture(B, uv - vec2(0.0, 3.0 * texel.y), 0.0) * w3; wtot += w3 * 2.0; }
    if (rad >= 4) { acc += texture(B, uv + vec2(0.0, 4.0 * texel.y), 0.0) * w4; acc += texture(B, uv - vec2(0.0, 4.0 * texel.y), 0.0) * w4; wtot += w4 * 2.0; }

    vec4 vBlur = acc / wtot;

    fragColor = vec4(clamp(vBlur.rgb * bloom_strength, vec3(0.0), vec3(1.0)), 1.0);
}
