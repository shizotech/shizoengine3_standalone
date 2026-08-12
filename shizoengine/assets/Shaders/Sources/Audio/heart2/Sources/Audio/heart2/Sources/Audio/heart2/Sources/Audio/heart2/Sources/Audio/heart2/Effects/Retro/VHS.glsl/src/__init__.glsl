// ==== Custom Uniform Controls ====

//@float min=0.0 max=2.0 value=0.5
uniform float vhs_tracking;

//@float min=0.0 max=1.0 value=0.3
uniform float vhs_color_bleed;

//@float min=0.0 max=1.0 value=0.5
uniform float vhs_scanlines;

//@float min=0.0 max=1.0 value=0.2
uniform float vhs_noise;

//@float min=0.0 max=1.0 value=0.3
uniform float vhs_warp;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    float time = iTime;

    // Tracking error - horizontal shift
    float tracking = sin(uv.y * 50.0 + time * 5.0) * vhs_tracking * 0.02;
    tracking += step(0.95, hash(floor(time * 10.0) + floor(uv.y * 100.0))) * vhs_tracking * 0.05;

    // Warp effect
    float warp = sin(uv.y * 20.0 + time * 3.0) * vhs_warp * 0.01;

    // Scanline offset
    float scanline_offset = sin(uv.y * iResolution.y * 0.5) * 0.5 + 0.5;

    // Sample with tracking and warp
    vec2 sampled_uv = uv + vec2(tracking + warp, 0.0);

    // Color channels with offset for color bleed
    float r = texture2D(iChannel0, sampled_uv + vec2(vhs_color_bleed * 0.01, 0.0)).r;
    float g = texture2D(iChannel0, sampled_uv).g;
    float b = texture2D(iChannel0, sampled_uv - vec2(vhs_color_bleed * 0.01, 0.0)).b;

    vec3 color = vec3(r, g, b);

    // Scanlines
    float scanlines = sin(uv.y * iResolution.y * 3.14) * 0.5 + 0.5;
    scanlines = pow(scanlines, 1.0 + vhs_scanlines * 2.0);
    color *= mix(vec3(1.0), vec3(scanlines), vhs_scanlines);

    // Noise
    float noise_val = hash(uv.x * iResolution.x + uv.y * iResolution.y + time * 100.0);
    noise_val = (noise_val - 0.5) * vhs_noise;
    color += noise_val;

    // Slight color shift for authenticity
    color.r *= 1.0 + sin(time * 2.0) * 0.05;
    color.b *= 1.0 + cos(time * 1.5) * 0.05;

    fragColor = vec4(color, 1.0);
}