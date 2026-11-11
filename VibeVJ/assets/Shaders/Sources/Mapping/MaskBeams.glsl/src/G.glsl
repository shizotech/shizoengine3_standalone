//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskBeams, pass G: the light of the beams at half size: for every segment of pass B the distance to it, a core
// and a glow, the glow in a drifting haze, and hot spots where a beam hits a surface ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D B;
uniform sampler2D T;

//@slider min=0.5 max=20.0 value=2.5
uniform float beam_width;     // pixels
//@slider min=0.0 max=3.0 value=1.0
uniform float glow;
//@slider min=2.0 max=200.0 value=28.0
uniform float glow_width;     // pixels
//@slider min=0.0 max=1.0 value=0.5
uniform float haze;           // the glow lights up a drifting haze, unevenly
//@slider min=0.5 max=10.0 value=3.0
uniform float haze_scale;
//@slider min=0.0 max=4.0 value=1.2
uniform float hit_glow;       // a hot spot where a beam hits a surface
//@slider min=2.0 max=120.0 value=18.0
uniform float hit_size;       // pixels
//@enum options=(Flash, Strobe, Nothing) value=0
uniform int pulse_look;       // Flash: brighter at a pulse. Strobe: the beams are only on at a pulse (Motion Step on pulse moves them too)
//@slider min=0.0 max=4.0 value=1.0
uniform float pulse_amount;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 full = iResolution.xy / PASS_SCALE;
    vec2 p = fragCoord / PASS_SCALE;            // pixels of the picture
    float t = float(iFrame) / 60.0;
    vec2 hq = p / full.y * haze_scale;
    float hz = mp_vnoise(hq + vec2(t * 0.11, t * 0.05)) * 0.65 + mp_vnoise(hq * 2.3 - vec2(t * 0.07, 0.0)) * 0.35;
    float hazef = mix(1.0, hz * 1.8, haze);
    float w = max(beam_width, 0.5);
    float gw = max(glow_width, 1.0);
    vec3 light = vec3(0.0);
    int rays = bm_rays();
    for (int r = 0; r < 24; r++) {
        if (r >= rays) break;
        vec3 col = bm_ray_color(r);
        for (int k = 0; k < 8; k++) {
            vec4 inf = texelFetch(B, ivec2(k, r + 24), 0);
            if (inf.z < 0.5) break;
            vec4 sg = texelFetch(B, ivec2(k, r), 0);
            vec2 a = sg.xy;
            vec2 ba = sg.zw - a;
            vec2 pa = p - a;
            float hh = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
            float d = length(pa - ba * hh);
            float core = exp(-(d * d) / (w * w));
            float g = glow * exp(-d / gw) * 0.35 * hazef;
            float v = (core + g) * inf.x;
            float ends = inf.y;
            if (ends > 0.5 && ends < 3.5) {
                // a hot spot at the end (a mirror, glass or an absorber)
                float de = length(p - sg.zw);
                float big = ends > 2.5 ? 1.0 : (ends > 1.5 ? 0.12 : 0.3);
                v += hit_glow * big * inf.x * (exp(-(de * de) / (hit_size * hit_size)) + 0.5 * exp(-de / (hit_size * 0.25)));
            }
            light += col * v;
        }
    }
    vec3 pl = mp_pulse(T);
    if (pulse_look == 0) light *= 1.0 + pulse_amount * pl.x;
    else if (pulse_look == 1) light *= clamp(pl.x * (1.0 + pulse_amount), 0.0, 3.0);
    fragColor = vec4(light, 1.0);
}
