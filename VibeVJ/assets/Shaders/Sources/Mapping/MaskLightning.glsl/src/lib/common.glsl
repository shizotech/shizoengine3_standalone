// --- MaskLightning: what every pass shares (where the arcs go, when they strike) ---
#define MASK_AUTO 3
#include mapping.glsl
#include mask.glsl
#include beat.glsl
#include jfa.glsl

//@enum options=(Between objects, Sky strikes, To the frame, Crawl on outlines, Between A and B) value=0
uniform int arc_mode;         // where the arcs jump: from one object to the next, from the top down onto the objects, ...
//@int min=1 max=6 value=3
uniform int arcs;             // arcs at a time
//@enum options=(Strikes on pulses, Continuous, Both) value=2
uniform int timing;           // Strikes: a flash at each pulse (Pulse every, Trigger). Continuous: arcs that crackle all the time
//@slider min=0.0 max=1.0 value=0.35
uniform float continuous_level;   // how bright the continuous arcs are
//@int min=1 max=240 value=10
uniform int hold;             // frames an arc keeps its two ends (Continuous)
//@slider min=0.0 max=1.0 value=0.6
uniform float crackle;        // how often the path between the ends changes: 1 every frame
//@slider min=0.0 max=1.0 value=0.35
uniform float roughness;      // how much the path zigzags
//@slider min=0.0 max=1.0 value=0.6
uniform float branches;       // side arcs
//@slider min=20.0 max=2000.0 value=700.0
uniform float max_length;     // pixels: the longest jump
//@slider min=0.0 max=120.0 value=50.0
uniform float spread;         // degrees: how far an arc may leave an outline off its normal
//@slidervec2 min=(0,0) max=(1,1) value=(0.2,0.5)
uniform vec2 point_a;         // Between A and B: the two electrodes
//@slidervec2 min=(0,0) max=(1,1) value=(0.8,0.5)
uniform vec2 point_b;

vec2 g_full;    // the size of the picture in pixels; set by each pass

// The signed distance (pixels, negative inside the white shapes) at p (pixels), and the point on the outline
float lt_sdf(sampler2D J10, sampler2D M, vec2 p, out vec2 seed) {
    vec2 jres = vec2(textureSize(J10, 0));
    vec2 q = p * jres / g_full;
    ivec2 c = ivec2(floor(q));
    ivec2 hi = ivec2(jres) - 1;
    float bd = 1e20;
    seed = p;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec4 v = texelFetch(J10, clamp(c + ivec2(x, y), ivec2(0), hi), 0);
            if (v.w < 0.5) continue;
            vec2 e = v.xy - q;
            float d2 = dot(e, e);
            if (d2 < bd) { bd = d2; seed = v.xy / jres * g_full; }
        }
    }
    float d = bd > 1e19 ? 1e5 : sqrt(bd) * g_full.x / jres.x;
    float inside = mp_bilinear_uv(M, p / g_full).r;
    return inside > 0.5 ? -d : d;
}
