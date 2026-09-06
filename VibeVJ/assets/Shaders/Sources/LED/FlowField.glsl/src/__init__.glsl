//@settings dtype=float32 format=rgba rendersize=(1920,1080)

//@slider min=0.0 max=4.0 value=1.0
uniform float flow_speed;

//@slider min=0.1 max=2.0 value=0.8
uniform float flow_scale;

//@slider min=0.0 max=1.0 value=0.6
uniform float feedback_decay;

//@slider min=0.0 max=3.0 value=1.5
uniform float intensity;

//@slider min=0.0 max=1.0 value=0.3
uniform float trail_length;

//@rgb value=(1.0, 0.4, 0.1)
uniform vec3 color_fg;

//@rgb value=(0.02, 0.0, 0.05)
uniform vec3 color_bg;

uniform sampler2D feedback;

// --- 2D value noise + curl (divergence-free flow field) ---
float fhash(vec2 p)
{
    vec2 h = p * vec2(127.1, 311.7);
    return fract(sin(dot(h, vec2(12.9898, 78.233)) * 43758.5453123);
}

float vnoise(vec2 p)
{
    vec2 ip = floor(p);
    vec2 fp = fract(p);
    vec2 u = fp * fp * (3.0 - 2.0 * fp);
    float c00 = fhash(ip);
    float c10 = fhash(ip + vec2(1.0, 0.0));
    float c01 = fhash(ip + vec2(0.0, 1.0));
    float c11 = fhash(ip + vec2(1.0, 1.0));
    float x = mix(c00, c10, u.x);
    float y = mix(c01, c11, u.x);
    return mix(x, y, u.y);
}

vec2 curl(vec2 p)
{
    float e = 0.1;
    float de = 2.0 * e;
    float dPdy = (vnoise(p + vec2(0.0, e)) - vnoise(p - vec2(0.0, e))) / de;
    float dPdx = (vnoise(p + vec2(e, 0.0)) - vnoise(p - vec2(e, 0.0))) / de;
    return vec2(dPdy, dPdx * -1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;
    float t = iTime * flow_speed;

    // Sample the divergence-free flow field
    vec2 p = uv * flow_scale * 4.0 + vec2(t * 0.2, t * -0.1);
    vec2 v = curl(p);

    // Advection step: how far to trace back (trail_length controls it)
    vec2 src_uv = uv - v * texel * (4.0 + trail_length * 8.0);
    vec4 prev = texture(feedback, src_uv);

    // Fade previous frame
    vec3 col = prev.rgb * feedback_decay;

    // Emission where the flow speed is high (bright streaks)
    float emit = length(v) * intensity;
    float streak = smoothstep(0.3, 0.9, emit);
    vec3 fg = color_fg * (0.6 + emit);
    col = max(col, fg * streak);

    // Blend to background where there is no streak
    col = mix(color_bg, col, clamp(length(prev.rgb) * 4.0, 0.0, 1.0));

    fragColor = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
