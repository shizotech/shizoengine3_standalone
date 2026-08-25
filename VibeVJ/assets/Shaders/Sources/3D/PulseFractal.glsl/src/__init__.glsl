//@settings dtype=float32 format=rgba rendersize=(1920,1080)

//@slider min=0.0 max=4.0 value=2.0
uniform float pulse_speed;

//@slider min=2 max=8 value=4
uniform int fractal_depth;

//@slidervec2 min=(0.0,0.0) max=(6.283,6.283) value=(0.0,0.0)
uniform vec2 rot_speeds;

//@rgb value=(0.3,0.7,1.0)
uniform vec3 glow_color;

// Smooth minimum for soft fractal blends
float smin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// 3D IFS (Sierpinski-style) distance field, iterated `fractal_depth` times.
// Returns signed distance approximation for the raymarcher.
float iFS(vec3 p)
{
    float d = 1e5;
    for (int i = 0; i < 8; i++)
    {
        if (i > fractal_depth) break;

        // 4 Sierpinski-style transformations (sub-scale 0.5)
        d = min(d, length(p - vec3(0.5, 0.5, 0.5) * 0.5 + vec3(0.5, 0.5, 0.5)) / 0.5);
        d = min(d, length(p - vec3(0.5, 0.5, -0.5) * 0.5 + vec3(0.5, 0.5, 0.5)) / 0.5);
        d = min(d, length(p - vec3(0.5, -0.5, 0.5) * 0.5 + vec3(0.5, 0.5, 0.5)) / 0.5);
        d = min(d, length(p - vec3(-0.5, 0.5, 0.5) * 0.5 + vec3(0.5, 0.5, 0.5)) / 0.5);

        // map back with inverse scale to iterate
        p = (p - vec3(0.5, 0.5, 0.5)) / 0.5;
        p -= vec3(0.5, 0.5, 0.5);
    }
    return d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Ray from UV
    vec2 uv = fragCoord.xy * 2.0 / iResolution.xy - 1.0;
    uv.x *= iResolution.x / iResolution.y;
    vec3 ray = normalize(vec3(uv.x, uv.y, 1.0));
    vec3 ro = vec3(0.0, 0.0, -3.0);

    // Time-driven pulse
    float t = iTime * pulse_speed;
    float pulse = 1.0 + 0.15 * sin(t);

    vec3 color = vec3(0.0);
    float acc = 0.0;

    // March
    float dist = 0.0;
    const int steps = 96;
    for (int i = 0; i < steps; i++)
    {
        vec3 pos = ro + ray * dist;

        // Rotate around Y
        float ay = rot_speeds.x * iTime * 0.2;
        float cy = cos(ay);
        float sy = sin(ay);
        vec3 rp = vec3(pos.x * cy - pos.z * sy, pos.y, pos.x * sy + pos.z * cy);

        // Rotate around X
        float ax = rot_speeds.y * iTime * 0.2;
        float cx = cos(ax);
        float sx = sin(ax);
        rp = vec3(rp.x, rp.y * cx - rp.z * sx, rp.y * sx + rp.z * cx);

        // Scale by pulse and evaluate IFS
        vec3 scaled = rp * (1.0 / pulse);
        float d = iFS(scaled) * pulse;

        if (d < 0.003)
        {
            // Hit: shade with glow color + ambient
            float ao = 1.0 - float(i) / float(steps);
            color += glow_color * (0.4 + 0.6 * ao);
            color += vec3(0.1, 0.2, 0.25) * ao;
            break;
        }
        dist += d * 0.6;
        acc += 1.0;
        if (dist > 10.0) break;
    }

    // Vignette
    vec2 vuv = fragCoord.xy / iResolution.xy;
    float vig = (vuv.x * (1.0 - vuv.x)) * (vuv.y * (1.0 - vuv.y));
    color *= pow(vig * 20.0, 0.4);

    fragColor = vec4(color, 1.0);
}
