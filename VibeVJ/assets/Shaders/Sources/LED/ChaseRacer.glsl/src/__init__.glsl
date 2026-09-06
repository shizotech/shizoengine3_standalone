//@settings dtype=float32 format=rgba

//@rgb value=(1.0, 1.0, 1.0)
uniform vec3 racer_color;   // hot white

//@rgb value=(1.0, 0.4, 0.1)
uniform vec3 trail_color;   // orange

//@slider min=0.1 max=8.0 value=1.0
uniform float racer_speed;   // beats per traversal

//@slider min=0.05 max=1.0 value=0.3
uniform float trail_length;

//@slider min=0.01 max=0.5 value=0.08
uniform float head_width;

//@slider min=0.0 max=4.0 value=1.0
uniform float glow;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    // Work in a horizontal strip: position along x (0..1)
    float x = uv.x;
    // Slight vertical centering so the effect reads along a strip
    float y = uv.y;

    vec3 col = vec3(0.0);

    // 4 staggered racers, each offset by 1/4 of the traversal
    for (int k = 0; k < 4; k++)
    {
        float fk = float(k);
        // Head position along x: loops over [0,1], beat-synced via iTime (beats)
        float p = fract(iTime * racer_speed + fk / 4.0);

        // Head distance: how far behind/around the head
        float dHead = abs(x - p);
        // Wrap-aware distance (head near edge should also affect the other edge)
        float dHeadW = min(dHead, 1.0 - dHead);

        // Head: a bright, narrow band in racer_color (smooth decay from the head center)
        float head = smoothstep(head_width * 2.0, 0.0, dHeadW);

        // Trail: a smooth glow decaying behind the head (trailing glow in trail_color).
        // Wrap-aware distance measured "behind" the head.
        float behind = p - x;             // positive -> pixel is behind head
        float wrapBehind = (1.0 + p) - x; // used when the head is near x=1
        float trail = 0.0;
        if (behind >= 0.0 && behind < trail_length)
        {
            trail = 1.0 - behind / trail_length;
        }
        else if (wrapBehind >= 0.0 && wrapBehind < trail_length)
        {
            trail = 1.0 - wrapBehind / trail_length;
        }

        // Additive accumulation for richness
        col += head * racer_color * (1.0 + glow);
        col += trail * trail_color * (1.0 + glow);
    }

    // Subtle vertical shaping so a 2D panel reads as a band rather than flat
    float vBand = smoothstep(0.5, 0.35, abs(y - 0.5));
    col *= (0.35 + 0.65 * vBand);

    fragColor = vec4(col, 1.0);
}
