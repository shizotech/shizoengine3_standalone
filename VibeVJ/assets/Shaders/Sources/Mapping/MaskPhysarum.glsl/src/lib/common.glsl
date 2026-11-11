// --- MaskPhysarum: what every pass shares (the controls, the agents, the food) ---
#define MASK_AUTO 3
#include mapping.glsl
#include mask.glsl
#include beat.glsl

uniform sampler2D food_picture;   // optional: a picture whose bright parts are food (a video, a shader)

// ---- the mask and the food ----
//@enum options=(Food around objects, Food, Walls, Container, Ignore) value=0
uniform int mask_role;         // Food around objects: the slime cannot enter the white shapes and is fed along their outlines, so it links them
//@slider min=1.0 max=60.0 value=10.0
uniform float food_band;       // pixels at 1080p: how wide the strip of food around an object is
//@slider min=0.0 max=10.0 value=2.5
uniform float food_strength;   // attractant the food gives off each step
//@int min=0 max=12 value=0
uniform int food_points;       // food at random places (oat flakes)
//@slider min=2.0 max=80.0 value=14.0
uniform float food_size;       // pixels at 1080p
//@slider min=0.0 max=2.0 value=0.0
uniform float picture_food;    // food where the picture in Food picture is bright
//@button
uniform bool brush;            // food at Brush position while it is on: map it to a pad
//@slidervec2 min=(0,0) max=(1,1) value=(0.5,0.5)
uniform vec2 brush_position;
//@slider min=2.0 max=200.0 value=30.0
uniform float brush_size;      // pixels at 1080p

// ---- the slime (Jeff Jones's agents: sense the trail ahead, turn, step, deposit) ----
//@slider min=0.01 max=0.6 value=0.12
uniform float population;      // share of the free cells with an agent: 0.12 is about 60 000 agents at 1080p, 0.5 about 250 000
//@enum options=(Everywhere, Centre, Ring, On the food) value=0
uniform int spawn;             // where the agents start (and where new ones appear when some are lost)
//@slider min=5.0 max=90.0 value=30.0
uniform float sensor_angle;    // degrees between the middle sensor and the side ones
//@slider min=2.0 max=80.0 value=18.0
uniform float sensor_distance; // pixels at 1080p: how far ahead an agent smells; longer gives a coarser network
//@slider min=5.0 max=90.0 value=40.0
uniform float turn_angle;      // degrees an agent turns towards the stronger smell
//@slider min=0.1 max=1.0 value=1.0
uniform float step_size;       // cells per step, two steps a frame: the speed
//@slider min=0.0 max=20.0 value=5.0
uniform float deposit;         // trail an agent leaves each step
//@slider min=0.005 max=0.5 value=0.1
uniform float decay;           // share of the trail that fades each step
//@slider min=0.0 max=1.0 value=1.0
uniform float diffusion;       // how much the trail spreads each step
//@slider min=0.0 max=1.0 value=0.08
uniform float wander;          // random turns
//@int min=1 max=8 value=5
uniform int strains;           // kinds of agent: each has its own colour (Palette) and moves a little differently (Behavior variation)
//@slider min=0.0 max=1.0 value=0.8
uniform float color_variation; // 0: every strain in Colour A / B, 1: the full colours of the Palette
//@slider min=0.0 max=1.0 value=0.6
uniform float behavior_variation;   // how different the strains move: sensor angle and distance, turn, speed, deposit
//@enum options=(Slime, Colour A to B, Rainbow, Fire, Ocean, Toxic, Candy) value=0
uniform int palette;           // the colours of the strains
//@int min=1 max=2 value=1
uniform int species;           // two species avoid each other's trail (Colour A and Colour B); the strains then split into the two
//@slider min=0.0 max=3.0 value=1.0
uniform float repulsion;       // how much the species (or the strains) keep away from each other's trail; 0: they share one network
//@enum options=(Walls, Wrap) value=0
uniform int borders;           // the edge of the picture
//@enum options=(Food drop, Scatter, Move food, Repel, Restart, None) value=0
uniform int pulse_action;      // what a pulse does (Pulse every, Trigger)
//@slider min=0.0 max=4.0 value=1.0
uniform float pulse_amount;

// ---- the look (lib/relief.glsl has the rest) ----
//@enum options=(Photoreal, Classic flat, Glow) value=0
uniform int look;
//@enum options=(Wet slime, Wax, Gold, Chrome, Glass jelly, Ceramic) value=0
uniform int material;
//@rgb value=(1.0, 0.84, 0.12)
uniform vec3 color_a;          // the thin, young parts (two species: the first)
//@rgb value=(0.96, 0.7, 0.1)
uniform vec3 color_b;          // the thick veins (two species: the second)
//@slider min=0.0 max=40.0 value=12.0
uniform float relief_height;   // pixels at 1080p: how high the thickest veins stand
//@slider min=0.1 max=4.0 value=1.0
uniform float vein_thickness;  // how much trail makes a full vein
//@slider min=0.0 max=2.0 value=1.0
uniform float capillaries;     // thin veins: the trail of a few agents, and a fine net of veinlets around the thick veins
//@slider min=0.0 max=2.0 value=0.2
uniform float show_agents;     // every agent as a tiny bright dot in its strain's colour

// ---- the agents: rgba of the state passes ----
// r: the trail. g, b: the trail as a vector, every strain lays its own direction (ph_strain().sig): the strains smell
// their own kind (two species: g is the first minus the second, b 0) and the colour of a vein is the angle of the
// vector. a: the agent, an integer below 2^24 (exact in a float): 0 no agent, else 1 + strain << 21 | heading << 12 |
// x << 6 | y, heading in 512ths of a turn, x and y its place in the cell in 64ths (#892)
struct Agent {
    bool alive;
    vec2 frac;
    float heading;
    int strain;
};

Agent ph_decode(vec4 s) {
    Agent a;
    a.alive = s.a > 0.5;
    uint u = uint(max(s.a, 1.0) + 0.5) - 1u;
    a.strain = int(u >> 21u);
    a.heading = (float((u >> 12u) & 511u) + 0.5) * (MP_TAU / 512.0);
    a.frac = (vec2(float((u >> 6u) & 63u), float(u & 63u)) + 0.5) / 64.0;
    return a;
}

// h: a hash for the rounding (random rounding: no drift towards the grid, also at small steps and turns)
float ph_encode(Agent a, uint h) {
    if (!a.alive) return 0.0;
    float hq = floor(fract(a.heading / MP_TAU) * 512.0 - 0.5 + mp_rand(h));
    uint hd = uint(int(hq) + 512) & 511u;
    vec2 f = clamp(floor(a.frac * 64.0 - 0.5 + vec2(mp_rand(h + 1u), mp_rand(h + 2u))), 0.0, 63.0);
    uint u = (uint(clamp(a.strain, 0, 7)) << 21u) | (hd << 12u) | (uint(f.x) << 6u) | uint(f.y);
    return float(u + 1u);
}

// pixels at 1080p in cells of the simulation (iResolution is the size of the simulation pass)
float ph_cells(float px) { return px * iResolution.y / 1080.0; }

// ---- the strains (#892): strain 0 moves with the controls as they are, the others vary them along three axes ----
// scale (sensor distance and deposit: coarse, thick veins or a fine web), agility (sensor and turn angle: straight or
// curly), and speed. The tables spread the first strains far apart, so even 3 strains differ clearly
const float PH_SCALE[8] = float[8](0.0, 1.0, -0.8, 0.45, -0.35, 0.8, -1.0, 0.3);
const float PH_AGILE[8] = float[8](0.0, -0.6, 0.9, 0.6, -1.0, 0.2, -0.3, 1.0);
const float PH_SLOW[8] = float[8](0.0, 0.5, 0.15, 1.0, 0.6, 0.1, 0.8, 0.4);

int ph_strain_count() { return clamp(max(strains, species), 1, 8); }

struct Strain {
    float sensor_angle;   // radians
    float sensor_dist;    // cells
    float turn;           // radians
    float step;           // cells
    float deposit;
    vec2 sig;             // its direction in the trail vector
};

Strain ph_strain(int s) {
    int n = ph_strain_count();
    s = clamp(s, 0, 7);
    float v = strains > 1 ? behavior_variation : 0.0;
    Strain st;
    st.sensor_angle = radians(sensor_angle) * exp2(0.7 * v * PH_AGILE[s]);
    st.sensor_dist = ph_cells(sensor_distance) * exp2(0.9 * v * PH_SCALE[s]);
    st.turn = radians(turn_angle) * exp2(0.6 * v * PH_AGILE[s]);
    st.step = step_size * (1.0 - 0.45 * v * PH_SLOW[s]);
    st.deposit = deposit * exp2(0.7 * v * PH_SCALE[s]);
    // two species: the first along +x, the second along -x (the strains alternate); else spread round the circle
    float ang = species > 1 ? MP_PI * float(s & 1) : MP_TAU * float(s) / float(n);
    st.sig = vec2(cos(ang), sin(ang));
    return st;
}

// How much a sensor likes the trail t (r, g, b of a state pass)
float ph_smell(vec3 t, Strain st) {
    float own = dot(t.yz, st.sig);          // the own kind counts more, the opposite kind less
    if (species > 1) return 0.5 * (t.x + own) - repulsion * 0.5 * (t.x - own);   // own - Repulsion * other
    return t.x + repulsion * own;
}

// The colours of the strains: a loop through four colours, sRGB
vec3 ph_palette(float t) {
    vec3 k0, k1, k2, k3;
    if (palette == 0) { k0 = vec3(1.0, 0.86, 0.08); k1 = vec3(1.0, 0.56, 0.04); k2 = vec3(1.0, 0.94, 0.62); k3 = vec3(0.86, 0.6, 0.1); }
    else if (palette == 1) { k0 = color_a; k1 = mix(color_a, color_b, 0.5) * 0.8; k2 = color_b; k3 = mix(color_a, vec3(1.0), 0.45); }
    else if (palette == 2) return mix(mp_hue(t), vec3(1.0), 0.12);
    else if (palette == 3) { k0 = vec3(1.0, 0.22, 0.04); k1 = vec3(1.0, 0.62, 0.08); k2 = vec3(1.0, 0.93, 0.45); k3 = vec3(0.8, 0.06, 0.14); }
    else if (palette == 4) { k0 = vec3(0.08, 0.8, 0.95); k1 = vec3(0.15, 0.38, 1.0); k2 = vec3(0.55, 0.3, 1.0); k3 = vec3(0.2, 0.95, 0.62); }
    else if (palette == 5) { k0 = vec3(0.55, 1.0, 0.08); k1 = vec3(1.0, 0.95, 0.1); k2 = vec3(0.15, 1.0, 0.55); k3 = vec3(0.95, 0.25, 0.9); }
    else { k0 = vec3(1.0, 0.5, 0.72); k1 = vec3(0.55, 0.95, 0.85); k2 = vec3(0.72, 0.58, 1.0); k3 = vec3(1.0, 0.8, 0.5); }
    float x = fract(t) * 4.0;
    float f = smoothstep(0.0, 1.0, fract(x));
    int i = int(x);
    vec3 a = i == 0 ? k0 : (i == 1 ? k1 : (i == 2 ? k2 : k3));
    vec3 b = i == 0 ? k1 : (i == 1 ? k2 : (i == 2 ? k3 : k0));
    return mix(a, b, f);
}

// The colour (sRGB) of the slime from pass H: r height, g and b the trail vector over the trail (the strains). One
// strain: Colour A on the thin, B on the thick parts; two species: A and B; strains: the Palette at the vector's angle,
// towards the palette's mean where strains mix
vec3 ph_albedo(vec4 hf) {
    vec3 base = mix(color_a, color_b, smoothstep(0.6, 0.98, hf.r));
    if (species > 1) return mix(color_a, color_b, clamp(0.5 - 0.5 * hf.g, 0.0, 1.0));
    if (ph_strain_count() < 2) return base;
    // where strains mix the vector is short: there the mean of the palette
    vec3 mean = 0.25 * (ph_palette(0.125) + ph_palette(0.375) + ph_palette(0.625) + ph_palette(0.875));
    vec3 pc = mix(mean, ph_palette(atan(hf.b, hf.g) / MP_TAU), smoothstep(0.05, 0.5, length(hf.gb)));
    return mix(base, pc, color_variation);
}
#define RL_ALBEDO ph_albedo

// The colour of one agent (show_agents)
vec3 ph_strain_color(int s) {
    if (species > 1) return (s & 1) == 0 ? color_a : color_b;
    if (ph_strain_count() < 2) return color_a;
    return mix(color_a, ph_palette(float(s) / float(ph_strain_count())), color_variation);
}

// The strain of a new agent at uv: patches of the picture (low noise) with a fifth of strangers, so the strains start
// as territories that meet and mix
int ph_new_strain(uint h, vec2 uv) {
    int n = ph_strain_count();
    if (n < 2) return 0;
    if (species > 1 && strains < 2) return mp_rand(h) < 0.5 ? 0 : 1;
    float t = mp_vnoise(uv * vec2(iResolution.x / iResolution.y, 1.0) * 2.2 + 3.7) * 1.6 - 0.3;
    if (mp_rand(h) < 0.2) t = mp_rand(h + 1u);
    return clamp(int(floor(clamp(t, 0.0, 0.999) * float(n))), 0, n - 1);
}

vec2 ph_dir(float h) { return vec2(cos(h), sin(h)); }

ivec2 ph_wrap(ivec2 p, ivec2 grid) { return (p % grid + grid) % grid; }

bool ph_outside(ivec2 p, ivec2 grid) { return p.x < 0 || p.y < 0 || p.x >= grid.x || p.y >= grid.y; }

// A cell an agent may not be in (pass M, b): a wall of the mask
bool ph_blocked(sampler2D M, ivec2 p) { return texelFetch(M, p, 0).b > 0.5; }

// The place of food point i (uv); Move food: new places at every pulse
vec2 ph_food_pos(int i, float epoch) {
    ivec3 k = ivec3(i, int(epoch), 3);
    return vec2(0.08 + 0.84 * mp_rand3(k), 0.1 + 0.8 * mp_rand3(k + ivec3(0, 0, 17)));
}
vec2 ph_burst_pos(float k) {
    int ki = int(k);
    return vec2(0.12 + 0.76 * mp_rand3(ivec3(ki, 41, 5)), 0.12 + 0.76 * mp_rand3(ivec3(ki, 7, 29)));
}

// Distance in pixels at 1080p between two uv of the picture
float ph_px(vec2 a, vec2 b) {
    vec2 d = (a - b) * vec2(iResolution.x / iResolution.y, 1.0) * 1080.0;
    return length(d);
}

// The food at uv besides the mask's (the points, the brush, a pulse, the picture), 0..
float ph_food_extra(vec2 uv, vec3 pl) {
    float f = 0.0;
    float epoch = pulse_action == 2 ? pl.y : 0.0;
    for (int i = 0; i < 12; i++) {
        if (i >= food_points) break;
        float d = ph_px(uv, ph_food_pos(i, epoch)) / max(food_size, 1.0);
        f += exp(-d * d);
    }
    if (brush) {
        float d = ph_px(uv, brush_position) / max(brush_size, 1.0);
        f += 1.5 * exp(-d * d);
    }
    if (pulse_action == 0 && pl.x > 0.01) {
        float d = ph_px(uv, ph_burst_pos(pl.y)) / max(food_size * 2.0, 1.0);
        f += 2.0 * pulse_amount * pl.x * exp(-d * d);
    }
    if (picture_food > 0.0) {
        vec3 c = texture(food_picture, uv).rgb;
        f += picture_food * max(c.r, max(c.g, c.b));
    }
    return f;
}

// Pass X: the trail spreads and fades, agents and food add to it, every agent smells ahead and turns.
// S: the state after the last step
vec4 ph_sense(sampler2D S, sampler2D M, sampler2D T, ivec2 c, int stepi) {
    ivec2 grid = ivec2(iResolution.xy);
    vec2 uv = (vec2(c) + 0.5) / iResolution.xy;
    vec3 pl = mp_pulse(T);
    vec4 mm = texelFetch(M, c, 0);
    bool restart = stepi == 0 && (iFrame < 2 || textureSize(S, 0) != grid || (pulse_action == 4 && pl.z > 0.5));
    if (restart) {
        // the first agents
        uint h0 = mp_hash(uint(c.x) * 73856093u ^ uint(c.y) * 19349663u ^ uint(iFrame) * 83492791u);
        Agent a;
        a.alive = false;
        a.frac = vec2(mp_rand(h0 + 1u), mp_rand(h0 + 2u));
        a.heading = mp_rand(h0 + 3u) * MP_TAU;
        a.strain = ph_new_strain(h0 + 4u, uv);
        float place = 1.0;
        vec2 d = (uv - 0.5) * vec2(iResolution.x / iResolution.y, 1.0);
        if (spawn == 1) place = 1.0 - smoothstep(0.1, 0.13, length(d));
        else if (spawn == 2) place = 1.0 - smoothstep(0.01, 0.03, abs(length(d) - 0.33));
        else if (spawn == 3) place = clamp((mm.g + ph_food_extra(uv, pl)) * 4.0, 0.0, 1.0);
        float chance = spawn == 0 ? population : (spawn == 3 ? 0.5 : 0.6);
        if (mm.b < 0.5 && mp_rand(h0) < chance * place) a.alive = true;
        if (spawn == 1 || spawn == 2) a.heading = atan(d.y, d.x) + (mp_rand(h0 + 5u) - 0.5) * 1.2;
        return vec4(0.0, 0.0, 0.0, ph_encode(a, h0 + 9u));
    }

    vec4 s = texelFetch(S, c, 0);
    // the trail: a 3 x 3 mean (no flux through the walls of the picture or of the mask), fade
    vec3 sum = vec3(0.0);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            ivec2 n = c + ivec2(x, y);
            if (borders == 1) n = ph_wrap(n, grid);
            else if (ph_outside(n, grid)) n = c;
            if (ph_blocked(M, n)) n = c;
            sum += texelFetch(S, n, 0).rgb;
        }
    }
    vec3 tr = mix(s.rgb, sum / 9.0, diffusion) * (1.0 - decay);
    if (mm.b > 0.5) tr = vec3(0.0);

    // food: every strain likes it (it has no direction in the trail vector)
    float food = mm.g + ph_food_extra(uv, pl);
    tr.x += food * food_strength;
    if (pulse_action == 3 && pl.x > 0.01) {
        float d = ph_px(uv, ph_burst_pos(pl.y)) / max(food_size * 3.0, 1.0);
        tr.x -= pl.x * pulse_amount * 6.0 * exp(-d * d);
    }
    tr.x = max(tr.x, -40.0);
    float vl = length(tr.yz);
    if (vl > max(tr.x, 0.0)) tr.yz *= max(tr.x, 0.0) / vl;   // the vector is never longer than the trail

    Agent a = ph_decode(s);
    uint hr = mp_hash(uint(c.x) * 2654435761u ^ uint(c.y) * 40503u ^ uint(iFrame * 2 + stepi) * 9973u);
    if (a.alive) {
        Strain st = ph_strain(a.strain);
        tr += st.deposit * vec3(1.0, st.sig);
        // three sensors ahead: the trail as this strain smells it, far less a wall
        vec2 pos = vec2(c) + a.frac;
        float v[3];
        for (int k = 0; k < 3; k++) {
            vec2 sp = pos + ph_dir(a.heading + float(k - 1) * st.sensor_angle) * st.sensor_dist;
            if (borders == 1) sp = mod(sp, vec2(grid));
            float val = ph_smell(mp_bilinear(S, sp).rgb, st);
            val -= 100.0 * mp_bilinear(M, sp).b;
            if (borders == 0 && (sp.x < 0.0 || sp.y < 0.0 || sp.x > float(grid.x) || sp.y > float(grid.y))) val -= 100.0;
            v[k] = val;
        }
        float ta = st.turn;
        float r1 = mp_rand(hr);
        if (v[1] > v[0] && v[1] > v[2]) {
            // straight on
        } else if (v[1] < v[0] && v[1] < v[2]) {
            a.heading += (r1 < 0.5 ? -ta : ta);
        } else if (v[0] > v[2]) {
            a.heading -= ta;
        } else if (v[2] > v[0]) {
            a.heading += ta;
        }
        a.heading += (mp_rand(hr + 7u) - 0.5) * 2.0 * ta * wander;
        if (pulse_action == 1 && pl.z > 0.5 && mp_rand(hr + 11u) < 0.5 * pulse_amount) a.heading = mp_rand(hr + 13u) * MP_TAU;
    }
    if (pulse_action == 1 && pl.z > 0.5) tr *= 1.0 - 0.2 * min(pulse_amount, 4.0);
    return vec4(tr, ph_encode(a, hr + 17u));
}

// The cell an agent in cell n wants to step into this step, and its new place
ivec2 ph_target(Agent a, ivec2 n, ivec2 grid, out vec2 np) {
    np = vec2(n) + a.frac + ph_dir(a.heading) * ph_strain(a.strain).step;
    ivec2 t = ivec2(floor(np));
    if (borders == 1) t = ph_wrap(t, grid);
    return t;
}

float ph_priority(ivec2 n, int stepi) {
    return mp_rand(mp_hash(uint(n.x) * 1597334677u ^ uint(n.y) * 3812015801u ^ uint(iFrame * 2 + stepi) * 2654435769u));
}

// Pass Y: every agent steps one cell at most. A cell takes one agent: of those that want into a free cell the one
// with the highest priority gets it, the others stay and turn at random (as in Jones's model)
vec4 ph_move(sampler2D X, sampler2D M, sampler2D C, ivec2 c, int stepi) {
    ivec2 grid = ivec2(iResolution.xy);
    vec4 s = texelFetch(X, c, 0);
    Agent a = ph_decode(s);
    bool wall = ph_blocked(M, c);
    uint hq = mp_hash(uint(c.x) * 19349663u ^ uint(c.y) * 83492791u ^ uint(iFrame * 2 + stepi) * 73856093u);
    if (a.alive) {
        if (wall) return vec4(s.rgb, 0.0);          // the mask moved over it: gone
        vec2 np;
        ivec2 t = ph_target(a, c, grid, np);
        if (t == c) {
            a.frac = np - floor(np);
            return vec4(s.rgb, ph_encode(a, hq + 3u));
        }
        bool free_cell = !ph_outside(t, grid) && !ph_blocked(M, t) && texelFetch(X, t, 0).a < 0.5;
        bool won = free_cell;
        if (free_cell) {
            float mine = ph_priority(c, stepi);
            for (int y = -1; y <= 1 && won; y++) {
                for (int x = -1; x <= 1; x++) {
                    ivec2 n = t + ivec2(x, y);
                    if (borders == 1) n = ph_wrap(n, grid);
                    else if (ph_outside(n, grid)) continue;
                    if (n == c || n == t) continue;
                    Agent b = ph_decode(texelFetch(X, n, 0));
                    if (!b.alive) continue;
                    vec2 bp;
                    if (ph_target(b, n, grid, bp) == t && ph_priority(n, stepi) > mine) {
                        won = false;
                        break;
                    }
                }
            }
        }
        if (won) return vec4(s.rgb, 0.0);           // it left
        a.heading = mp_rand(hq) * MP_TAU;
        return vec4(s.rgb, ph_encode(a, hq + 3u));
    }
    if (wall) return vec4(s.rgb, 0.0);
    // which agent steps in
    float best = -1.0;
    Agent got = a;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            if (x == 0 && y == 0) continue;
            ivec2 n = c + ivec2(x, y);
            if (borders == 1) n = ph_wrap(n, grid);
            else if (ph_outside(n, grid)) continue;
            Agent b = ph_decode(texelFetch(X, n, 0));
            if (!b.alive) continue;
            vec2 bp;
            if (ph_target(b, n, grid, bp) != c) continue;
            float pr = ph_priority(n, stepi);
            if (pr > best) {
                best = pr;
                got = b;
                got.frac = bp - floor(bp);
            }
        }
    }
    if (best >= 0.0) return vec4(s.rgb, ph_encode(got, hq + 5u));
    // a new agent while there are fewer than Population (pass C counts them)
    float share = texelFetch(C, ivec2(0, 0), 0).r;
    float deficit = clamp((population - share) / max(population, 1e-3), 0.0, 1.0);
    if (deficit > 0.02) {
        uint h0 = mp_hash(uint(c.x) * 83492791u ^ uint(c.y) * 2654435761u ^ uint(iFrame * 2 + stepi) * 19349663u);
        vec2 uv = (vec2(c) + 0.5) / iResolution.xy;
        vec2 d = (uv - 0.5) * vec2(iResolution.x / iResolution.y, 1.0);
        float place = 1.0;
        if (spawn == 1) place = 1.0 - smoothstep(0.1, 0.13, length(d));
        else if (spawn == 2) place = 1.0 - smoothstep(0.01, 0.03, abs(length(d) - 0.33));
        else if (spawn == 3) place = clamp(texelFetch(M, c, 0).g * 4.0, 0.0, 1.0);
        if (mp_rand(h0) < deficit * 0.01 * place * (spawn == 0 ? 1.0 : 8.0)) {
            Agent n;
            n.alive = true;
            n.frac = vec2(mp_rand(h0 + 1u), mp_rand(h0 + 2u));
            n.heading = mp_rand(h0 + 3u) * MP_TAU;
            n.strain = ph_new_strain(h0 + 4u, uv);
            return vec4(s.rgb, ph_encode(n, h0 + 9u));
        }
    }
    return vec4(s.rgb, 0.0);
}
