// --- MaskSwarm: what every pass shares (the controls of the flock, a boid in a cell, its colour) ---
#define MASK_AUTO 3
#include mapping.glsl
#include mask.glsl
#include beat.glsl
#include jfa.glsl

//@enum options=(Obstacles, Container, Ignore) value=0
uniform int mask_role;        // Obstacles: the flock streams around the white shapes. Container: it stays inside them
//@slider min=0.0 max=0.5 value=0.07
uniform float population;     // the share of the cells with a boid: about 2300 at 0.07 in a 1080p picture
//@slider min=0.05 max=0.9 value=0.4
uniform float speed;          // cells a frame (a cell is 8 pixels at 1080p)
//@slider min=0.0 max=1.0 value=0.35
uniform float min_speed;      // a share of Speed: no boid is slower
//@slider min=1.0 max=3.0 value=3.0
uniform float view_radius;    // cells: how far a boid sees its neighbours
//@slider min=0.0 max=2.0 value=0.8
uniform float separation;
//@slider min=0.0 max=2.0 value=0.8
uniform float alignment;
//@slider min=0.0 max=2.0 value=0.35
uniform float cohesion;
//@slider min=0.0 max=2.0 value=0.25
uniform float wander;         // a swirling wind that moves the flocks around
//@slider min=0.5 max=8.0 value=2.0
uniform float wander_scale;   // swirls per picture height
//@slider min=0.0 max=3.0 value=1.2
uniform float avoid;          // how hard the boids steer around the walls of the mask
//@slider min=4.0 max=200.0 value=40.0
uniform float avoid_distance; // pixels: how early they steer
//@slider min=0.0 max=2.0 value=0.0
uniform float edge_attract;   // the boids gather along the outlines of the mask
//@slider min=0.0 max=120.0 value=18.0
uniform float edge_offset;    // pixels from the outline where they gather
//@slider min=-2.0 max=2.0 value=0.6
uniform float edge_flow;      // along the outline: one way round or the other
//@slider min=0.0 max=2.0 value=0.0
uniform float attract;        // to the point Target (a fader pair or an XY pad); negative values are not needed: use Scatter
//@slidervec2 min=(0,0) max=(1,1) value=(0.5,0.5)
uniform vec2 target;
//@enum options=(Wrap, Bounce, Open) value=1
uniform int borders;          // the edge of the picture: the boids come back on the other side, turn, or fly out
//@enum options=(Anywhere, Picture edges, Outlines, Target) value=0
uniform int spawn;            // where new boids appear while there are fewer than Population
//@enum options=(Scatter, Burst from the outlines, Gather on the outlines, Turn around, Speed up, Nothing) value=4
uniform int pulse_action;     // what a pulse does (Pulse every, Trigger); Scatter breaks the flocks up: give it a pulse every 8 beats or more
//@slider min=0.0 max=3.0 value=0.8
uniform float pulse_amount;

//@enum options=(Single colour, Two colours, By heading, By speed, Rainbow) value=4
uniform int color_mode;
//@rgb value=(0.95, 0.95, 1.0)
uniform vec3 color_a;
//@rgb value=(0.3, 0.7, 1.0)
uniform vec3 color_b;

const float SW_VMAX = 0.92;

// A cell: r, g the place of its boid in cells, plus 2048 times a 3-bit seed each; b, a its velocity. r < 0: empty
struct Boid {
    bool alive;
    vec2 pos;
    vec2 vel;
    float seed;      // 0..63
};

Boid sw_decode(vec4 c) {
    Boid b;
    b.alive = c.r >= 0.0;
    float sx = floor(c.r / 2048.0);
    float sy = floor(c.g / 2048.0);
    b.pos = vec2(c.r - sx * 2048.0, c.g - sy * 2048.0);
    b.vel = c.ba;
    b.seed = sx + sy * 8.0;
    return b;
}

vec4 sw_encode(Boid b) {
    if (!b.alive) return vec4(-1.0, -1.0, 0.0, 0.0);
    float sx = mod(b.seed, 8.0);
    float sy = floor(b.seed / 8.0);
    return vec4(b.pos + vec2(sx, sy) * 2048.0, b.vel);
}

vec3 sw_color(Boid b, float spd) {
    if (color_mode == 0) return color_a;
    if (color_mode == 1) return mod(b.seed, 2.0) < 0.5 ? color_a : color_b;
    if (color_mode == 2) return mp_hue(atan(b.vel.y, b.vel.x) / MP_TAU + 0.5);
    if (color_mode == 3) return mix(color_b, color_a, clamp(length(b.vel) / max(spd, 0.05), 0.0, 1.0));
    return mp_hue(b.seed / 64.0 * 0.35 + iTime * 0.02);
}

// Solid for the boids: the objects (Obstacles), the free space (Container), nothing (Ignore or no mask)
float sw_wall_of(float m) {
    if (mp_mask_mode() == 4 || mask_role == 2) return 0.0;
    return mask_role == 1 ? 1.0 - m : m;
}
