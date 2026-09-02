//@settings dtype=float32 format=rgba rendersize=(1280,720)

//@rgb value=(0.4,0.8,1.0)
uniform vec3 colour;
//@rgb value=(0.03,0.03,0.05)
uniform vec3 background;
//@slider min=0.0 max=1.0 value=0.5
uniform float morph_strength;
//@slider min=0.1 max=3.0 value=1.0
uniform float scale;
//@slider min=0.0 max=1.0 value=1.0
uniform float smoothness;
//@int min=2 max=64 value=24
uniform int count;
//@slider min=0.0 max=1.0 value=0.03
uniform float width;
//@slider min=0.0 max=1.0 value=0.4
uniform float randomness;
//@int min=1 max=6 value=3
uniform int layer_count;

#define PI 3.141592653589793

vec3 hsv2rgb(vec3 c) {
    float h = c.x * 6.0;
    vec3 rgb;
    float mr = mod(h + 0.0, 6.0);
    float dr = mr - 2.0;
    rgb.r = clamp(abs(dr), 0.0, 1.0);
    float mg = mod(h + 4.0, 6.0);
    float dg = mg - 3.0;
    rgb.g = clamp(abs(dg), 0.0, 1.0);
    float mb = mod(h + 2.0, 6.0);
    float db = mb - 4.0;
    rgb.b = clamp(abs(db), 0.0, 1.0);
    return c.z * mix(vec3(1.0), rgb, c.y);
}

float hash11(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// distance from point to line segment (from origin center to edge)
float line_coverage(vec2 uv, vec2 end, float w, float sm) {
    // uv in normalized space centered at 0
    vec2 pa = uv;
    vec2 ba = end;
    float ba2 = dot(ba, ba);
    float h = clamp(dot(pa, ba) / ba2, 0.0, 1.0);
    vec2 closest = h * ba;
    float d = length(uv - closest);
    return smoothstep(w, 0.0, d) * sm;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv = uv * 2.0 - 1.0;

    float morph = morph_strength * (0.5 + 0.5 * sin(iTime * 0.5));
    float lenScale = (0.7 + 0.3 * morph) * scale;
    float w = width * 0.05;

    vec3 col = vec3(0.0);

    for (int layer = 0; layer < 6; layer++) {
        if (layer >= layer_count) break;
        float layerPhase = float(layer) * 0.7;

        for (int i = 0; i < 64; i++) {
            if (i >= count) break;
            float fi = float(i);
            float nf = float(count);
            // base angle evenly spaced
            float baseAng = 6.2831853 * fi / nf + iTime * 0.2 + layerPhase;
            // randomness: jitter the angle
            float jit = (hash11(fi * 7.0 + layer) - 0.5) * 6.2831853 * randomness;
            float ang = baseAng + jit;
            // line length varies with randomness
            float lenJit = 0.8 + 0.4 * hash11(fi * 13.0 + layer * 3.0);
            vec2 end = vec2(cos(ang), sin(ang)) * 1.0 * lenScale * lenJit;
            float cov = line_coverage(uv, end, w, smoothness);
            // colorful per-line variation via HSV hue rotation
            float hue = fract(colour.r + fi / nf + layer * 0.1);
            vec3 lcol = hsv2rgb(vec3(hue, 0.8, 1.0));
            col += lcol * cov;
        }
    }

    vec3 bg = background;
    vec3 outcol = max(bg, col);

    fragColor = vec4(outcol, 1.0);
}
