//@settings dtype=float32 format=rgba

//@int min=4 max=128 value=32
uniform int bar_count;

//@slider min=0.0 max=3.0 value=1.5
uniform float sensitivity;

//@slider min=0.0 max=2.0 value=1.0
uniform float glow;

//@rgb value=(0.2,0.6,1.0)
uniform vec3 bar_color;

// Cabbibo's HSV -> RGB (inlined helper, matching existing audio shaders)
vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    float N = float(bar_count);

    // Which bar column this pixel belongs to
    float barIndex = floor(uv.x * N);
    // Normalized position within the bar (0 = left edge, 1 = right edge)
    float withinBar = uv.x * N - barIndex;

    // Per-bar audio amplitude (the spectrum bin)
    float amp = texture(iChannel2, vec2(barIndex / N, 0.0)).x;
    amp = clamp(amp * sensitivity, 0.0, 1.0);

    // Bars are anchored to the bottom of the screen and grow upward
    float yFromBottom = 1.0 - uv.y;
    float barHeight = 0.62 * amp;

    // Mask: inside this bar column and within the bar's height
    float inBar = step(0.0, withinBar) * step(withinBar, 1.0)
                 * step(yFromBottom, barHeight)
                 * step(barIndex, N - 0.5)
                 * step(0.0, barIndex);

    // Subtle beat-aligned animation (iTime is in beats)
    float beat = 0.5 + 0.5 * cos(iTime * 6.283185307);
    float shimmer = 0.85 + 0.15 * beat;

    // Vertical colored gradient within each bar (dark base -> hue-shifted top)
    float grad = 0.35 + 0.65 * (yFromBottom / max(barHeight, 0.001));
    vec3 cBottom = bar_color;
    vec3 cTop = hsv2rgb(vec3(fract(0.55 + barIndex / N), 0.9, 1.0));
    vec3 barCol = mix(cBottom, cTop, grad);

    vec3 col = barCol * inBar * shimmer * (1.0 + glow * amp);

    // Faint background pulse so the visual stays alive between hits
    col += bar_color * (0.02 + 0.05 * beat);

    fragColor = vec4(col, 1.0);
}
