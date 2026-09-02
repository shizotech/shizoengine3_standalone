//@settings dtype=float32 format=rgba rendersize=(1280,720)

//@rgb value=(0.75,0.78,0.82)
uniform vec3 colour;
//@rgb value=(0.03,0.03,0.04)
uniform vec3 background;
//@slider min=0.0 max=1.0 value=0.5
uniform float morph_strength;
//@slider min=0.1 max=3.0 value=1.0
uniform float scale;
//@slider min=0.3 max=1.0 value=0.8
uniform float smoothness;
//@int min=1 max=32 value=10
uniform int count;
//@slider min=0.0 max=0.99 value=0.92
uniform float trail_length;
//@int min=1 max=8 value=3
uniform int group_size;

uniform sampler2D feedback;

#define PI 3.141592653589793

float hash21(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}
float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i),                 hash21(i + vec2(1.0, 0.0)), u.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
        u.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv = uv * 2.0 - 1.0;

    float morph = morph_strength * (0.5 + 0.5 * sin(iTime * 0.5));
    float orbitR = 0.55 * scale * (0.7 + 0.3 * morph);
    float ringR = 0.10 * scale;
    float ringW = 0.02 * scale;
    float nf = float(count);
    float ng = float(max(group_size, 1));

    vec3 col = vec3(0.0);

    for (int i = 0; i < 32; i++) {
        if (i >= count) break;
        float fi = float(i);
        float group = floor(fi / ng);
        float inGroup = fi - group * ng;
        float groupAngle = 6.2831853 * group / ng + iTime * 0.35;
        float a = groupAngle + (inGroup / ng) * (6.2831853 / ng);
        vec2 center = vec2(cos(a), sin(a)) * orbitR;
        float d = length(uv - center);
        // smoke ring: soft annulus with noisy displacement
        float n = vnoise(vec2(d * 6.0, iTime * 0.4) + fi * 0.7);
        float disp = (n - 0.5) * 2.0 * ringW * 2.0;
        float band = smoothstep(ringW, 0.0, abs(d - ringR + disp)) * smoothness;
        // wispy smoke color with slight per-ring variation
        vec3 smk = mix(colour, colour * 0.7 + vec3(0.05), n);
        col += smk * band;
    }

    vec3 prev = texture(feedback, fragCoord / iResolution.xy, 0.0).rgb;
    vec3 bg = background;
    vec3 outcol = max(bg, max(col, prev * trail_length));

    fragColor = vec4(outcol, 1.0);
}
