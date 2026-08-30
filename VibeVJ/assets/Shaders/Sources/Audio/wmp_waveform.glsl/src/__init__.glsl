//@settings dtype=float32 format=rgba

//@slider min=0.0 max=5.0 value=2.0
uniform float sensitivity;

//@slider min=0.0 max=5.0 value=0.5
uniform float thickness;

//@rgb value=(0.2,0.6,1.0)
uniform vec3 wave_color;

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

    // Raw audio signal sampled per-pixel horizontally (iChannel1 = raw waveform)
    // The signal lives in iChannel1; center it around 0.
    float sig = texture(iChannel1, vec2(uv.x, 0.0)).x - 0.5;
    sig = clamp(sig * sensitivity, -0.5, 0.5);

    // The waveform is drawn in the lower half of the screen.
    // Map the signal (range ~ +/-0.5) into screen y near the bottom.
    // Waveform baseline sits ~60% down from top (uv.y = 0.6),
    // amplitude expands upward and downward from that baseline.
    float baseline = 0.6;
    float ampScale = 0.35;
    float waveY = baseline + sig * ampScale;

    // Vertical distance (in uv units) from the wave line to this pixel
    float dy = uv.y - waveY;
    float thickPx = (0.002 + 0.004 * thickness); // line thickness in uv space
    float line = 1.0 - clamp(abs(dy) / thickPx, 0.0, 1.0);
    line = smoothstep(0.0, 1.0, line);

    // Subtle beat-aligned shimmer (iTime is in beats)
    float beat = 0.5 + 0.5 * cos(iTime * 6.283185307);
    float shimmer = 0.85 + 0.15 * beat;

    // Overall audio energy for intensity (iChannel2 = spectrum, center bin)
    float level = clamp(texture(iChannel2, vec2(0.5, 0.0)).x * sensitivity, 0.0, 1.0);

    // Color: base color, with a subtle hue shift by energy
    vec3 col = wave_color;
    col = mix(col, hsv2rgb(vec3(fract(0.55 + level), 0.9, 1.0)), 0.5);

    vec3 c = col * line * shimmer * (1.0 + level) + col * (0.02 + 0.05 * beat);

    fragColor = vec4(c, 1.0);
}
