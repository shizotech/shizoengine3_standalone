// --- MaskFire: what every pass shares (the controls of the fire, the flow that carries the flames) ---
#define MASK_AUTO 3
#include mapping.glsl
#include mask.glsl
#include beat.glsl

uniform sampler2D emit_picture;   // optional: a picture whose bright parts burn (a logo, a video)

//@enum options=(Top edges, All outlines, The surfaces, Bottom of the picture, Picture only) value=0
uniform int fire_source;      // where the flames start: on top of the objects, all around them, on their faces
//@enum options=(Obstacles, Container, Free) value=0
uniform int mask_role;        // Obstacles: the flames go around the objects. Container: only in the surfaces. Free: over everything
//@slider min=0.0 max=3.0 value=1.0
uniform float fuel;           // how hot the sources burn
//@slider min=0.0 max=4.0 value=1.0
uniform float rise;           // how fast the flames rise
//@slider min=0.0 max=0.2 value=0.04
uniform float cooling;        // more cooling: shorter flames
//@slider min=0.0 max=3.0 value=1.0
uniform float turbulence;
//@slider min=0.5 max=10.0 value=3.0
uniform float turbulence_scale;   // swirls per picture height
//@slider min=0.0 max=3.0 value=1.0
uniform float climb;          // the flames climb along the outlines, around corners
//@slider min=-1.0 max=1.0 value=0.0
uniform float wind;
//@slider min=2.0 max=60.0 value=12.0
uniform float source_width;   // pixels: how wide the burning band at an outline is
//@slider min=0.0 max=2.0 value=0.0
uniform float picture_fuel;   // the bright parts of Emit picture burn
//@slider min=0.0 max=1.0 value=0.35
uniform float smoke;          // smoke above the flames
//@enum options=(Flare, Embers, Flare and embers, Ignite all outlines, Nothing) value=2
uniform int pulse_action;     // what a pulse does (Pulse every, Trigger)
//@slider min=0.0 max=4.0 value=1.5
uniform float pulse_amount;
//@slider min=0.0 max=2.0 value=0.6
uniform float embers;         // how many sparks fly up from the flames
//@slider min=0.2 max=4.0 value=1.0
uniform float ember_life;

// The time of the simulation: frames, so the flames keep moving when the timeline stops
float fr_time() { return float(iFrame) / 60.0; }

// The mask (0..1) at a uv, from the pass M
float fr_mask(sampler2D M, vec2 uv) { return mp_bilinear_uv(M, uv).r; }

// Solid for the flames (they do not enter it): the objects (Obstacles), the free space (Container), nothing (Free)
float fr_wall_of(float m) {
    if (mp_mask_mode() == 4 || mask_role == 2) return 0.0;
    return mask_role == 1 ? 1.0 - m : m;
}

// The side the flames start from: the objects, or the free space around the surfaces (Container)
float fr_source_solid(float m) {
    if (mp_mask_mode() == 4) return 0.0;
    return mask_role == 1 ? 1.0 - m : m;
}

// The flow that carries heat, smoke and embers at uv, in pixels of the full picture per frame: up, the swirls of a
// curl noise, along the outlines (climb), around the walls
vec2 fr_velocity(sampler2D M, vec2 uv) {
    vec2 res = iResolution.xy / PASS_SCALE;    // the full picture
    float t = fr_time();
    vec2 v = vec2(wind * 1.6, 2.4) * rise;
    // curl of a noise: swirls that do not bunch up
    vec2 q = uv * vec2(res.x / res.y, 1.0) * turbulence_scale;
    float e = 0.05;
    q.y -= t * 0.6 * rise;
    float n1 = mp_vnoise(q + vec2(0.0, e)) + 0.5 * mp_vnoise(q * 2.03 + vec2(13.0, t * 0.7 + e * 2.03));
    float n2 = mp_vnoise(q - vec2(0.0, e)) + 0.5 * mp_vnoise(q * 2.03 + vec2(13.0, t * 0.7 - e * 2.03));
    float n3 = mp_vnoise(q + vec2(e, 0.0)) + 0.5 * mp_vnoise(q * 2.03 + vec2(13.0 + e * 2.03, t * 0.7));
    float n4 = mp_vnoise(q - vec2(e, 0.0)) + 0.5 * mp_vnoise(q * 2.03 + vec2(13.0 - e * 2.03, t * 0.7));
    vec2 curl = vec2(n1 - n2, -(n3 - n4)) / (2.0 * e);
    v += curl * turbulence * 0.9;

    if (mp_mask_mode() != 4) {
        // the outline: the gradient of the mask over a few pixels points into the solid side
        vec2 o = 6.0 / res;
        float l = fr_wall_of(fr_mask(M, uv - vec2(o.x, 0.0)));
        float r = fr_wall_of(fr_mask(M, uv + vec2(o.x, 0.0)));
        float d = fr_wall_of(fr_mask(M, uv - vec2(0.0, o.y)));
        float u = fr_wall_of(fr_mask(M, uv + vec2(0.0, o.y)));
        float sl = fr_source_solid(fr_mask(M, uv - vec2(o.x, 0.0)));
        float sr = fr_source_solid(fr_mask(M, uv + vec2(o.x, 0.0)));
        float sd = fr_source_solid(fr_mask(M, uv - vec2(0.0, o.y)));
        float su = fr_source_solid(fr_mask(M, uv + vec2(0.0, o.y)));
        vec2 g = vec2(sr - sl, su - sd);
        float gl = length(g);
        if (gl > 0.05) {
            vec2 n = g / gl;
            vec2 tg = vec2(-n.y, n.x);
            if (tg.y < 0.0) tg = -tg;
            v += tg * climb * 2.4 * rise * clamp(gl, 0.0, 1.0);
        }
        vec2 gw = vec2(r - l, u - d);
        float gwl = length(gw);
        if (gwl > 0.05) {
            vec2 n = gw / gwl;
            float into = dot(v, n);
            if (into > 0.0) v -= n * into * clamp(gwl * 1.5, 0.0, 1.0);
        }
    }
    float sp = length(v);
    if (sp > 6.0) v *= 6.0 / sp;
    return v;
}

float fr_luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
