// --- MaskSand: what every pass shares. A falling sand / liquid cellular automaton on blocks of 2 x 2 cells (Margolus
// neighbourhood: the blocks move by one cell every step, so no grain is lost or made twice). A cell: rgb its colour,
// a its kind: 0 empty, 1 sand, 2 liquid ---
#define MASK_AUTO 3
#include mapping.glsl
#include mask.glsl
#include beat.glsl

uniform sampler2D picture;    // optional: Picture colours for the grains, and Picture to sand at a pulse
bool sd_picture_linked = false;   // set by pass A from pass I (one pixel: the only pass that asks textureSize, #880)

//@enum options=(Obstacles, Container) value=0
uniform int mask_role;        // Obstacles: the grains pile up on the white shapes. Container: they fill the white shapes
//@enum options=(Sand, Liquid, Both) value=0
uniform int material;         // Both: every second spout pours liquid
//@enum options=(Floor, Open) value=0
uniform int ground;           // the bottom of the picture: grains pile up there, or fall out
//@int min=0 max=12 value=3
uniform int spouts;           // streams that pour from the top
//@slider min=0.0 max=1.0 value=0.35
uniform float pour;           // how much the spouts pour
//@slider min=1.0 max=120.0 value=14.0
uniform float spout_width;    // pixels
//@slider min=0.0 max=1.0 value=0.25
uniform float spout_wander;   // the spouts move along the top
//@slider min=0.0 max=0.05 value=0.0
uniform float snow;           // grains from the whole top edge
//@slider min=0.0 max=1.0 value=0.85
uniform float slide;          // how easily sand slides down a slope: less makes steep piles
//@slider min=0.0 max=1.0 value=0.8
uniform float flow;           // how fast a liquid spreads
//@slider min=0.0 max=0.2 value=0.0
uniform float drain;          // grains on the floor disappear: a steady state instead of filling up
//@enum options=(Pour burst, Picture to sand, Shake, Open the floor, Clear, Nothing) value=0
uniform int pulse_action;     // what a pulse does (Pulse every, Trigger)
//@slider min=0.0 max=1.0 value=0.6
uniform float pulse_amount;
//@enum options=(Sand, Strata, Rainbow, Picture colours, Two colours) value=1
uniform int color_mode;
//@rgb value=(0.86, 0.7, 0.45)
uniform vec3 color_a;
//@rgb value=(0.25, 0.55, 0.95)
uniform vec3 color_b;
//@slider min=0.0 max=1.0 value=0.12
uniform float color_speed;    // Strata, Rainbow: how fast the colour of new grains changes (turns per 16 beats)
//@button
uniform bool clear_now;       // empties the picture while it is on

// Solid for the grains: the objects (Obstacles) or the free space (Container); nothing without a mask
bool sd_solid_of(float m) {
    if (mp_mask_mode() == 4) return false;
    return mask_role == 1 ? m < 0.5 : m > 0.5;
}

// The colour of a new grain made at uv by spout k (k < 0: not a spout)
vec3 sd_new_color(vec2 uv, int k, float rnd) {
    float t = iTime * color_speed / 16.0;
    vec3 c;
    if (color_mode == 0) c = color_a;
    else if (color_mode == 1) {
        float ph = fract(t * 4.0);
        c = mix(color_a, color_b, smoothstep(0.35, 0.65, abs(ph * 2.0 - 1.0)));
        c *= 0.85 + 0.3 * mp_vnoise(vec2(t * 40.0, float(k) + 3.0));
    } else if (color_mode == 2) c = mp_hue(t * 2.0 + float(max(k, 0)) * 0.13);
    else if (color_mode == 3 && sd_picture_linked) c = texture(picture, uv).rgb;
    else if (color_mode == 3) c = color_a;
    else c = (k % 2 == 0) ? color_a : color_b;
    return c * (0.82 + 0.3 * rnd);
}

// The kind of a cell (0 empty, 1 sand, 2 liquid); a + 4 marks a grain that fell in its last step (still falling)
int sd_kind(vec4 c) { return int(c.a + 0.5) & 3; }
bool sd_falling(vec4 c) { return c.a > 3.5; }
vec4 sd_with(vec4 c, int kind, bool falling) { return vec4(c.rgb, float(kind) + (falling ? 4.0 : 0.0)); }

// One step of the automaton for cell p. offset: where the blocks start (0 or 1). S: the cells of the last step
vec4 sd_step(sampler2D S, sampler2D M, ivec2 p, int offset, uint salt, float shake, bool floor_open, float clear_rate) {
    ivec2 size = textureSize(S, 0);
    ivec2 o = ivec2(floor((vec2(p - offset)) / 2.0)) * 2 + offset;    // the lower left cell of the block
    ivec2 local = p - o;
    vec4 cell[4];      // 0 lower left, 1 lower right, 2 upper left, 3 upper right
    int kind[4];       // 0 empty, 1 sand, 2 liquid, 3 wall, 4 sink (below an open floor)
    bool fall[4];      // the grain is falling: it is no support for a grain to slide on
    for (int i = 0; i < 4; i++) {
        ivec2 q = o + ivec2(i & 1, i >> 1);
        fall[i] = false;
        if (q.x < 0 || q.x >= size.x || q.y >= size.y) {
            cell[i] = vec4(0.0);
            kind[i] = 3;
        } else if (q.y < 0) {
            cell[i] = vec4(0.0);
            kind[i] = floor_open ? 4 : 3;
        } else if (sd_solid_of(texelFetch(M, q, 0).r)) {
            cell[i] = vec4(0.0);
            kind[i] = 3;
        } else {
            cell[i] = texelFetch(S, q, 0);
            kind[i] = sd_kind(cell[i]);
            fall[i] = sd_falling(cell[i]);
        }
    }
    // the upper grains rest unless they move in this step
    bool up_moved[2];
    up_moved[0] = false;
    up_moved[1] = false;
    uint h = mp_hash(uint(o.x + 4096) * 7919u ^ uint(o.y + 4096) * 104729u ^ salt * 15485863u);
    float r1 = mp_rand(h);
    float r2 = mp_rand(h + 1u);
    float r3 = mp_rand(h + 2u);

    // sand sinks through liquid
    for (int c = 0; c < 2; c++) {
        if (kind[c + 2] == 1 && kind[c] == 2 && r3 < 0.6) {
            vec4 tc = cell[c]; cell[c] = cell[c + 2]; cell[c + 2] = tc;
            kind[c] = 1; kind[c + 2] = 2;
            fall[c] = true; fall[c + 2] = false;
        }
    }
    // fall straight down
    for (int c = 0; c < 2; c++) {
        bool mov = kind[c + 2] == 1 || kind[c + 2] == 2;
        bool free_below = kind[c] == 0 || kind[c] == 4;
        if (mov && free_below) {
            cell[c] = cell[c + 2]; kind[c] = kind[c + 2]; fall[c] = true;
            cell[c + 2] = vec4(0.0); kind[c + 2] = 0;
            up_moved[c] = true;
        }
    }
    // slide down a slope: an upper grain on a resting support goes to the free lower cell beside it
    bool lr = r1 < 0.5;
    for (int t = 0; t < 2; t++) {
        int c = (t == 0) == lr ? 0 : 1;   // the column of the grain
        int d = 1 - c;
        bool mov = (kind[c + 2] == 1 || kind[c + 2] == 2) && !up_moved[c];
        bool supported = kind[c] == 3 || ((kind[c] == 1 || kind[c] == 2) && !fall[c]);
        bool target_free = (kind[d] == 0 || kind[d] == 4) && kind[d + 2] == 0;
        float chance = kind[c + 2] == 2 ? 1.0 : slide;
        if (mov && supported && target_free && r2 < chance) {
            cell[d] = cell[c + 2]; kind[d] = kind[c + 2]; fall[d] = true;
            cell[c + 2] = vec4(0.0); kind[c + 2] = 0;
            up_moved[c] = true;
        }
    }
    // liquid spreads sideways where it rests; a shake moves sand sideways too
    for (int row = 0; row < 2; row++) {
        int a = row * 2;
        int b = a + 1;
        bool liq = (kind[a] == 2 && kind[b] == 0 && !fall[a]) || (kind[b] == 2 && kind[a] == 0 && !fall[b]);
        bool shk = ((kind[a] == 1 && kind[b] == 0) || (kind[b] == 1 && kind[a] == 0)) && r3 < shake;
        if ((liq && r1 * 0.7 + r3 * 0.3 < flow * 0.9) || shk) {
            vec4 tc = cell[a]; cell[a] = cell[b]; cell[b] = tc;
            int tk = kind[a]; kind[a] = kind[b]; kind[b] = tk;
            bool tf = fall[a]; fall[a] = fall[b]; fall[b] = tf;
        }
    }
    // an upper grain that could not move rests
    if (!up_moved[0]) fall[2] = false;
    if (!up_moved[1]) fall[3] = false;

    int me = local.x + local.y * 2;
    vec4 res = (kind[me] == 1 || kind[me] == 2) ? sd_with(cell[me], kind[me], fall[me]) : vec4(0.0);
    if (res.a > 0.5 && clear_rate > 0.0 && mp_rand(h + 7u + uint(me)) < clear_rate) res = vec4(0.0);
    return res;
}
