//@settings dtype=float32 format=rgba rendersize=(1280,720)

//@rgb value=(0.02,0.02,0.05)
uniform vec3 background;
//@slider min=0.0 max=1.0 value=0.5
uniform float morph_strength;
//@slider min=0.1 max=3.0 value=1.0
uniform float scale;
//@slider min=0.5 max=1.0 value=0.85
uniform float smoothness;
//@int min=1 max=32 value=10
uniform int count;
//@slider min=0.0 max=0.99 value=0.9
uniform float trail_length;
//@int min=1 max=8 value=4
uniform int group_size;
//@int min=1 max=4 value=2
uniform int layer_count;
//@slider min=0.0 max=1.0 value=0.0
uniform float colorful;        // >0 enables rainbow per-rocket colours
//@slider min=0.0 max=1.0 value=0.3
uniform float outward;         // how far the points drift outward from the center
//@slider min=0.0 max=1.0 value=0.5
uniform float interval_random;  // randomness of the time interval until the next rocket flies outward
//@rgb value=(1.0,0.5,0.05)
uniform vec3 fore_color;       // foreground colour of the fire objects

uniform sampler2D feedback;

#define PI 3.141592653589793

// ---- HSV -> RGB (scalar, branch-based) ----
vec3 hsv2rgb(vec3 c) {
    float h = fract(c.x) * 6.0;
    float s = c.y;
    float v = c.z;
    float hi = floor(h);
    float f = h - hi;
    float p = v * (1.0 - s);
    float q = v * (1.0 - s * f);
    float t = v * (1.0 - s * (1.0 - f));
    vec3 rgb;
    if (hi < 1.0)      rgb = vec3(v, t, p);
    else if (hi < 2.0) rgb = vec3(q, v, p);
    else if (hi < 3.0) rgb = vec3(p, v, t);
    else if (hi < 4.0) rgb = vec3(p, q, v);
    else if (hi < 5.0) rgb = vec3(t, p, v);
    else                 rgb = vec3(v, p, q);
    return rgb;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv = uv * 2.0 - 1.0;

    float morph = morph_strength * (0.5 + 0.5 * sin(iTime * 0.6));
    // scale now drives the SIZE of the individual fire objects;
    // the orbital radius is kept independent of scale
    float orbitR = 0.6 * (0.7 + 0.3 * morph) + outward;
    float fireR = 0.08 * scale;
    float nf = float(count);
    float ng = float(max(group_size, 1));

    vec3 col = vec3(0.0);

    // Each layer is an independent set of fireworks at a different phase
    for (int layer = 0; layer < 4; layer++) {
        if (layer >= layer_count) break;
        float layerPhase = float(layer) * 1.7;   // offset each layer

        for (int i = 0; i < 32; i++) {
            if (i >= count) break;
            float fi = float(i);
            float group = floor(fi / ng);
            float inGroup = fi - group * ng;
            // rockets travel outward then burst into small fire circles
            float groupAngle = 6.2831853 * group / ng + iTime * 0.5 + layerPhase;
            float a = groupAngle + (inGroup / ng) * (6.2831853 / ng);
            vec2 center = vec2(cos(a), sin(a)) * orbitR;

            // randomized launch interval: each rocket fires at its own rhythm
            float seed = fract(sin((fi + 1.0) * 12.9898 + layerPhase * 78.233) * 43758.5453);
            float rate = 0.3 + 0.7 * seed;
            float burstPhase = fract(iTime * rate + fi * 0.13 + seed * 6.2831853 * interval_random);
            // points drift outward over the burst cycle
            float burstR = fireR * (0.5 + 1.5 * burstPhase + outward * burstPhase);
            vec2 d = uv - center;
            float dist = length(d);
            // fire circle glow
            float t = clamp(1.0 - dist / burstR, 0.0, 1.0);
            float glow = pow(t, 2.0) * smoothness;
            // color: fire gradient, or rainbow when colorful is enabled
            vec3 fcol = mix(fore_color, vec3(1.0, 1.0, 0.6), t);
            if (colorful > 0.0) {
                float hue = fract(fi * 0.06 + iTime * 0.15 + interval_random * 0.5);
                fcol = hsv2rgb(vec3(hue, 0.95, 1.0)) * colorful;
            }
            col += fcol * glow;
        }
    }

    vec3 prev = texture(feedback, fragCoord / iResolution.xy, 0.0).rgb;
    vec3 bg = background;
    vec3 outcol = max(bg, max(col, prev * trail_length));

    fragColor = vec4(outcol, 1.0);
}
