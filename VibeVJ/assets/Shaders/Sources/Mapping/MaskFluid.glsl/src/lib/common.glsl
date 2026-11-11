// --- MaskFluid: what every pass shares (the controls, the emitters, reading the simulation grid) ---
#define MASK_AUTO 3
#include mapping.glsl
#include mask.glsl
#include beat.glsl

uniform sampler2D emit_picture;   // optional: a picture that emits smoke where it is bright (a video, a shader)

//@enum options=(Obstacles, Container) value=0
uniform int mask_role;        // Obstacles: the fluid flows around the white shapes. Container: it stays inside them
//@enum options=(Walls, Open) value=0
uniform int borders;          // the edge of the picture: a wall, or open (smoke leaves the picture)
//@slider min=0.0 max=2.0 value=1.0
uniform float sim_speed;      // the time step of the simulation per frame
//@slider min=0.0 max=1.0 value=0.35
uniform float vorticity;      // keeps the small swirls alive
//@slider min=0.0 max=0.2 value=0.01
uniform float velocity_fade;  // the motion dies down
//@slider min=0.0 max=0.1 value=0.006
uniform float dye_fade;       // the smoke fades
//@slider min=-1.0 max=1.0 value=0.25
uniform float buoyancy;       // smoke rises (negative: it sinks, like cold fog)
//@slidervec2 min=(-1,-1) max=(1,1) value=(0.0,0.0)
uniform vec2 wind;
//@slider min=0.0 max=1.0 value=0.2
uniform float wall_bounce;    // 0: the flow slides along a wall, 1: it bounces back

//@enum options=(Bottom row, Around the edges, Circle, Wander, None) value=0
uniform int emitter_layout;
//@int min=1 max=8 value=3
uniform int emitter_count;
//@slider min=2.0 max=120.0 value=26.0
uniform float emitter_size;   // pixels
//@slider min=0.0 max=4.0 value=1.2
uniform float jet_strength;
//@slider min=-180.0 max=180.0 value=90.0
uniform float jet_angle;      // degrees, 90 is up (Bottom row); for the other layouts it turns the jets
//@slider min=0.0 max=90.0 value=25.0
uniform float jet_wobble;     // degrees the jets swing
//@slider min=0.0 max=2.0 value=1.0
uniform float dye_amount;     // smoke from the jets
//@slider min=0.0 max=2.0 value=0.15
uniform float edge_emit;      // smoke from the outlines of the mask: the objects smoke
//@slider min=-2.0 max=2.0 value=0.2
uniform float edge_push;      // the outlines push the flow away (negative: they pull it in)
//@slider min=0.0 max=2.0 value=0.0
uniform float picture_emit;   // smoke where the picture in Emit picture is bright, in its colours
//@slider min=0.0 max=2.0 value=0.3
uniform float picture_push;   // and how hard the bright parts push up
//@enum options=(Random point, All jets, Outlines) value=0
uniform int burst_mode;       // what a pulse does (Pulse every, Trigger)
//@slider min=0.0 max=4.0 value=1.5
uniform float burst_amount;

//@enum options=(Two colours, Rainbow, Picture colours) value=1
uniform int color_mode;
//@rgb value=(0.2, 0.6, 1.0)
uniform vec3 color_a;
//@rgb value=(1.0, 0.3, 0.6)
uniform vec3 color_b;
//@rgb value=(0.9, 0.95, 1.0)
uniform vec3 edge_color;
//@slider min=0.0 max=1.0 value=0.05
uniform float hue_speed;      // Rainbow: turns per beat

// Solid (1) or free (0) in the simulation; outside the picture it is a wall unless the borders are open
float fl_solid_raw(vec2 uv) {
    float m = mp_mask(uv);
    if (mp_mask_mode() == 4) m = 0.0;
    return mask_role == 1 ? 1.0 - m : m;
}

// The emitter i: place (uv) and direction
void fl_emitter(int i, out vec2 pos, out vec2 dir) {
    float n = float(max(emitter_count, 1));
    float fi = float(i);
    float a = iResolution.x / iResolution.y;
    float wob = (mp_vnoise(vec2(fi * 7.31 + 3.0, iTime * 0.7)) - 0.5) * 2.0 * radians(jet_wobble);
    float ang = radians(jet_angle) + wob;
    if (emitter_layout == 1) {
        float s = fract((fi + 0.5) / n + 0.125);
        float per = 2.0 * (a + 1.0);
        float d = s * per;
        vec2 inward;
        if (d < a) { pos = vec2(d / a, 0.03); inward = vec2(0.0, 1.0); }
        else if (d < a + 1.0) { pos = vec2(0.97, d - a); inward = vec2(-1.0, 0.0); }
        else if (d < 2.0 * a + 1.0) { pos = vec2(1.0 - (d - a - 1.0) / a, 0.97); inward = vec2(0.0, -1.0); }
        else { pos = vec2(0.03, 1.0 - (d - 2.0 * a - 1.0)); inward = vec2(1.0, 0.0); }
        dir = mp_rot(ang - radians(90.0)) * inward;
    } else if (emitter_layout == 2) {
        float t = MP_TAU * fi / n + iTime * 0.03;
        pos = vec2(0.5) + vec2(cos(t) / a, sin(t)) * 0.4;
        dir = mp_rot(ang) * vec2(cos(t), sin(t));
    } else if (emitter_layout == 3) {
        float t = iTime * 0.12;
        pos = vec2(mp_vnoise(vec2(fi * 13.1, t)), mp_vnoise(vec2(fi * 5.7 + 40.0, t))) * 1.3 - 0.15;
        pos = clamp(pos, 0.05, 0.95);
        float wa = mp_vnoise(vec2(fi * 3.3 + 80.0, t * 2.0)) * MP_TAU * 2.0;
        dir = vec2(cos(wa), sin(wa));
    } else {
        pos = vec2((fi + 0.5) / n, 0.03);
        dir = vec2(cos(ang), sin(ang));
    }
}

vec3 fl_emitter_color(int i) {
    float n = float(max(emitter_count, 1));
    if (color_mode == 1) return mp_hue(float(i) / n + iTime * hue_speed);
    if (color_mode == 2) {
        vec2 pos;
        vec2 dir;
        fl_emitter(i, pos, dir);
        vec3 c = texture(emit_picture, pos).rgb;
        return c / max(max(c.r, max(c.g, c.b)), 0.25);
    }
    return (i % 2 == 0) ? color_a : color_b;
}

// The place of the burst of pulse number k (uv), somewhere in the middle part of the picture
vec2 fl_burst_pos(float k) {
    int ki = int(k);
    return vec2(0.15 + 0.7 * mp_rand3(ivec3(ki, 11, 5)), 0.15 + 0.7 * mp_rand3(ivec3(ki, 23, 9)));
}

// A texel of a simulation pass; out of the picture: a wall (Walls) or the nearest texel (Open)
vec4 fl_fetch(sampler2D tex, ivec2 p) {
    ivec2 hi = textureSize(tex, 0) - 1;
    return texelFetch(tex, clamp(p, ivec2(0), hi), 0);
}
bool fl_outside(sampler2D tex, ivec2 p) {
    ivec2 s = textureSize(tex, 0);
    return p.x < 0 || p.y < 0 || p.x >= s.x || p.y >= s.y;
}
// Is texel p of the grid a wall (the mask, or outside the picture with Walls)
bool fl_wall(sampler2D M, ivec2 p) {
    if (fl_outside(M, p)) return borders == 0;
    return texelFetch(M, p, 0).r > 0.5;
}

// No flow into a wall: the part of v towards a wall next to p is taken away (slide) or turned back (bounce)
vec2 fl_walls(sampler2D M, ivec2 p, vec2 v) {
    float b = 1.0 + wall_bounce;
    if (fl_wall(M, p + ivec2(1, 0)) && v.x > 0.0) v.x -= b * v.x;
    if (fl_wall(M, p - ivec2(1, 0)) && v.x < 0.0) v.x -= b * v.x;
    if (fl_wall(M, p + ivec2(0, 1)) && v.y > 0.0) v.y -= b * v.y;
    if (fl_wall(M, p - ivec2(0, 1)) && v.y < 0.0) v.y -= b * v.y;
    return v;
}

// Pressure of texel q for the Jacobi passes and the projection: next to a wall the pressure of p (no flow
// through it), outside an open border 0 (the flow leaves)
float fl_pressure(sampler2D P, int channel, sampler2D M, ivec2 q, float pc) {
    if (fl_outside(M, q)) return borders == 0 ? pc : 0.0;
    if (texelFetch(M, q, 0).r > 0.5) return pc;
    return texelFetch(P, q, 0)[channel];
}
