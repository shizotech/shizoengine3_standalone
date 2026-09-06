//@settings dtype=float32 format=rgba rendersize=(1920,1080)

//@slider min=0.0 max=0.95 value=0.35
uniform float feedback_amount;

//@slider min=0.0 max=3.0 value=1.0
uniform float zoom_speed;

//@slider min=0.0 max=6.0 value=2.0
uniform float rotation;

//@slider min=0.0 max=1.0 value=0.4
uniform float distort;

//@slider min=0.0 max=4.0 value=1.5
uniform float speed;

//@slider min=0.0 max=3.0 value=1.0
uniform float glow;

//@int min=1 max=16 value=6
uniform int ball_count;

//@slider min=0.05 max=0.6 value=0.25
uniform float ball_size;

//@rgb value=(0.2, 0.85, 1.0)
uniform vec3 color_fg;

//@rgb value=(0.0, 0.0, 0.1)
uniform vec3 color_bg;

uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;

    float t = iTime * speed;

    // Zoom + rotation
    float z = 1.0 + 0.4 * sin(t * 0.3) * zoom_speed;
    p /= max(z, 0.1);
    float a = t * rotation * 0.5;
    float ca = cos(a), sa = sin(a);
    p = vec2(ca * p.x - sa * p.y, sa * p.x + ca * p.y);

    // Noise-based distortion
    p += distort * vec2(sin(p.y * 3.0 + t), cos(p.x * 3.0 - t));

    // Moving SDF metaballs
    float d = 1e5;
    for (int i = 0; i < 16; i++)
    {
        if (i >= ball_count) break;
        float fi = float(i);
        vec2 pos = 0.8 * vec2(cos(t * 0.7 + fi), sin(t * 0.9 + fi * 1.3));
        d = min(d, length(p - pos) - ball_size);
    }

    float shape = 1.0 - smoothstep(0.0, 0.1, d);
    vec3 col = mix(color_bg, color_fg, shape);

    // Feedback trail: blend with previous frame
    vec4 prev = texture(feedback, uv);
    col = mix(col, prev.rgb, feedback_amount);

    // Cheap glow: average of 4 surrounding feedback taps
    vec2 texel = 1.0 / iResolution.xy;
    vec3 blur = prev.rgb;
    blur += texture(feedback, uv + vec2(texel.x, 0.0)).rgb;
    blur += texture(feedback, uv + vec2(-texel.x, 0.0)).rgb;
    blur += texture(feedback, uv + vec2(0.0, texel.y)).rgb;
    blur += texture(feedback, uv + vec2(0.0, -texel.y)).rgb;
    blur *= 0.25;
    col += glow * blur;

    fragColor = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
