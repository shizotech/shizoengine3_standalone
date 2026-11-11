// --- MaskReaction: what every pass shares (the controls, the models, the seeds) ---
#define MASK_AUTO 3
#include mapping.glsl
#include mask.glsl
#include beat.glsl

uniform sampler2D seed_picture;   // optional: a picture whose bright parts seed the reaction (a video, a shader)

// ---- the reaction ----
//@enum options=(Gray-Scott, FitzHugh-Nagumo waves, BZ spirals) value=0
uniform int model;             // Gray-Scott: Turing patterns (coral, spots, mazes). FitzHugh-Nagumo: waves and spirals of an excitable medium. BZ: the rock-paper-scissors spirals of the Belousov-Zhabotinsky reaction
//@enum options=(Coral, Mitosis, Worms, Mazes, Spots, U-skate, Holes, Chaos, Custom) value=3
uniform int pattern;           // Gray-Scott: the pattern (inside the mask with Two patterns)
//@enum options=(Coral, Mitosis, Worms, Mazes, Spots, U-skate, Holes, Chaos, Custom, Nothing) value=1
uniform int pattern_outside;   // Two patterns: the pattern outside the mask (Nothing: it dies there)
//@slider min=0.0 max=0.1 value=0.055
uniform float feed;            // Custom: the feed rate F of Gray-Scott
//@slider min=0.03 max=0.075 value=0.062
uniform float kill;            // Custom: the kill rate k
//@slider min=0.02 max=0.1 value=0.045
uniform float wave_width;      // FitzHugh-Nagumo: longer waves and slower spirals when higher
//@slider min=0.0 max=0.12 value=0.03
uniform float wave_threshold;  // FitzHugh-Nagumo: how hard a wave is to start; high values let fronts die
//@slider min=0.1 max=1.5 value=1.0
uniform float bz_rate;         // BZ: how fast the three chemicals eat each other
//@slider min=0.0 max=1.0 value=1.0
uniform float sim_speed;       // steps a frame: 1 is 8 steps, 0 stands still

// ---- the mask ----
//@enum options=(Two patterns, Inside only, Outside only, Ignore) value=0
uniform int mask_role;         // Two patterns: Pattern inside the white shapes, Pattern outside around them. Inside / Outside only: the rest is a wall the patterns line up along
//@enum options=(Walls, Wrap) value=0
uniform int borders;           // the edge of the picture

// ---- the seeds ----
//@enum options=(Random spots, Outline, Centre, Noise) value=3
uniform int seed_mode;         // how it starts (and what Restart does)
//@int min=1 max=64 value=14
uniform int seed_count;
//@slider min=2.0 max=80.0 value=14.0
uniform float seed_size;       // pixels at 1080p
//@enum options=(Seed spots, Seed outline, Ring, Restart, Disturb, None) value=0
uniform int pulse_action;      // what a pulse does (Pulse every, Trigger)
//@slider min=0.0 max=4.0 value=1.0
uniform float pulse_amount;
//@button
uniform bool brush;            // seeds at Brush position while it is on: map it to a pad
//@slidervec2 min=(0,0) max=(1,1) value=(0.5,0.5)
uniform vec2 brush_position;
//@slider min=2.0 max=200.0 value=24.0
uniform float brush_size;      // pixels at 1080p
//@slider min=0.0 max=2.0 value=0.0
uniform float picture_seed;    // seeds where the picture in Seed picture is bright

// ---- the look (lib/relief.glsl has the rest) ----
//@enum options=(Photoreal, Classic flat, Glow) value=0
uniform int look;
//@enum options=(Wet slime, Wax, Gold, Chrome, Glass jelly, Ceramic) value=1
uniform int material;
//@rgb value=(0.93, 0.86, 0.74)
uniform vec3 color_a;          // outside the mask (Two patterns), else the low parts
//@rgb value=(0.95, 0.32, 0.26)
uniform vec3 color_b;          // inside the mask, else the high parts
//@slider min=0.0 max=40.0 value=9.0
uniform float relief_height;   // pixels at 1080p

// ---- Gray-Scott parameters (Pearson's classes, F and k as in Robert Munafo's xmorphia) ----
vec2 rd_gs_params(int p) {
    if (p == 0) return vec2(0.0545, 0.062);   // coral
    if (p == 1) return vec2(0.0367, 0.0649);  // mitosis
    if (p == 2) return vec2(0.078, 0.061);    // worms
    if (p == 3) return vec2(0.029, 0.057);    // mazes
    if (p == 4) return vec2(0.035, 0.065);    // spots
    if (p == 5) return vec2(0.062, 0.0609);   // U-skate
    if (p == 6) return vec2(0.039, 0.058);    // holes
    if (p == 7) return vec2(0.026, 0.051);    // chaos
    if (p == 8) return vec2(feed, kill);
    return vec2(0.02, 0.08);                  // nothing: V dies
}

// The resting state of a model (what a wall and an empty start hold)
vec4 rd_rest() {
    if (model == 0) return vec4(1.0, 0.0, 0.0, 1.0);
    if (model == 1) return vec4(0.0, 0.0, 0.0, 2.0);
    return vec4(0.0, 0.0, 0.0, 3.0);
}

float rd_cells(float px) { return px * iResolution.y / 1080.0; }

ivec2 rd_wrap(ivec2 p, ivec2 grid) { return (p % grid + grid) % grid; }

// A seed at a place: the state there with a seed of strength s (0..1); rnd: a random number of the place
vec4 rd_seeded(vec4 st, float s, float rnd, vec2 dir) {
    if (s <= 0.0) return st;
    if (model == 0) {
        st.x = mix(st.x, 0.25, s);
        st.y = mix(st.y, 0.5, s);
    } else if (model == 1) {
        // half a disc excited, the other half tired: the wave breaks and curls into a pair of spirals
        if (dir.x > 0.0) st.x = mix(st.x, 1.0, s);
        else st.y = mix(st.y, 0.8, s);
    } else {
        vec3 r = vec3(rnd, fract(rnd * 7.13 + 0.31), fract(rnd * 3.71 + 0.77));
        st.xyz = mix(st.xyz, r, s);
    }
    return st;
}

vec2 rd_spot_pos(int i, float epoch) {
    ivec3 k = ivec3(i, int(epoch), 9);
    return vec2(0.06 + 0.88 * mp_rand3(k), 0.08 + 0.84 * mp_rand3(k + ivec3(0, 0, 23)));
}

// Distance in pixels at 1080p between two uv of the picture, and the direction
vec2 rd_off(vec2 a, vec2 b) { return (a - b) * vec2(iResolution.x / iResolution.y, 1.0) * 1080.0; }

// How much a seed lies at uv: spots (count, size, epoch), the outline (band b of pass M), the centre, noise
float rd_seed_shape(int mode, vec2 uv, float band, float epoch, int count, float size, out vec2 dir) {
    dir = vec2(1.0, 0.0);
    float s = 0.0;
    if (mode == 0) {
        for (int i = 0; i < 64; i++) {
            if (i >= count) break;
            vec2 o = rd_off(uv, rd_spot_pos(i, epoch));
            float d = length(o) / max(size, 1.0);
            float w = 1.0 - smoothstep(0.8, 1.0, d);
            if (w > s) {
                s = w;
                dir = o;
            }
        }
    } else if (mode == 1) {
        s = band;
        dir = vec2(mp_rand2(ivec2(uv * 37.0)) - 0.5, 0.0);
    } else if (mode == 2) {
        vec2 o = rd_off(uv, vec2(0.5));
        s = 1.0 - smoothstep(0.8, 1.0, length(o) / max(size * 3.0, 1.0));
        dir = o;
    } else {
        s = step(0.75, mp_vnoise(uv * vec2(iResolution.x / iResolution.y, 1.0) * 24.0 + epoch * 13.0));
        dir = vec2(mp_vnoise(uv * 50.0) - 0.5, 0.0);
    }
    return s;
}

// The 9-point Laplacian of the chemicals (no flux through walls and, with Walls, the edge of the picture)
vec4 rd_lap(sampler2D S, sampler2D M, ivec2 c, vec4 me) {
    ivec2 grid = ivec2(iResolution.xy);
    vec4 adj = vec4(0.0);
    vec4 dia = vec4(0.0);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            if (x == 0 && y == 0) continue;
            ivec2 n = c + ivec2(x, y);
            vec4 v = me;
            if (borders == 1) n = rd_wrap(n, grid);
            if (n.x >= 0 && n.y >= 0 && n.x < grid.x && n.y < grid.y && texelFetch(M, n, 0).g < 0.5) v = texelFetch(S, n, 0);
            if (x == 0 || y == 0) adj += v;
            else dia += v;
        }
    }
    return (adj * 4.0 + dia - 20.0 * me) / 6.0;
}

// One step of the model at cell c. S: the state after the last step, M: the mask (pass M)
vec4 rd_step(sampler2D S, sampler2D M, ivec2 c) {
    vec4 me = texelFetch(S, c, 0);
    vec4 mm = texelFetch(M, c, 0);
    if (mm.g > 0.5) return rd_rest();
    float inside = mm.r;
    if (mask_role == 3) inside = 1.0;
    bool dead_out = mask_role == 0 && pattern_outside == 9;
    vec4 lap = rd_lap(S, M, c, me);
    vec4 st = me;
    if (model == 0) {
        vec2 fk = mix(rd_gs_params(pattern_outside == 9 && mask_role == 0 ? 9 : (mask_role == 0 ? pattern_outside : pattern)),
                      rd_gs_params(pattern), inside);
        float u = me.x;
        float v = me.y;
        float uvv = u * v * v;
        // Sims's form: D_u = 1, D_v = 0.5 on the 9-point stencil weighted 0.2 / 0.05, dt = 1
        u += 0.3 * lap.x - uvv + fk.x * (1.0 - u);
        v += 0.15 * lap.y + uvv - (fk.x + fk.y) * v;
        st.xy = clamp(vec2(u, v), 0.0, 1.0);
    } else if (model == 1) {
        // Barkley's form of an excitable medium: u fast (the wave), v slow (the recovery)
        float eps = wave_width;
        float b = wave_threshold;
        if (mask_role == 0) {
            if (dead_out) b = mix(0.6, b, inside);
            else eps = mix(eps * 1.8, eps, inside);
        }
        float u = me.x;
        float v = me.y;
        float dt = 0.03;
        float uth = (v + b) / 0.75;
        u += dt * (lap.x + u * (1.0 - u) * (u - uth) / eps);
        v += dt * (u - v);
        st.xy = clamp(vec2(u, v), 0.0, 1.0);
    } else {
        // Alasdair Turner's BZ: the mean of the neighbours, then each chemical grows on one and is eaten by another
        vec3 m = me.xyz + lap.xyz * 0.3;
        float r = bz_rate;
        if (mask_role == 0) r *= dead_out ? inside : mix(0.6, 1.0, inside);
        vec3 n = m + m * (m.yzx - m.zxy) * r;
        st.xyz = clamp(n, 0.0, 1.0);
    }
    st.w = float(model) + 1.0;
    return st;
}

// Pass R1: the step plus the start, Restart, the seeds of the pulse, the brush and the picture. S: the last frame
vec4 rd_first(sampler2D S, sampler2D M, sampler2D T, ivec2 c) {
    ivec2 grid = ivec2(iResolution.xy);
    vec2 uv = (vec2(c) + 0.5) / iResolution.xy;
    vec3 pl = mp_pulse(T);
    vec4 mm = texelFetch(M, c, 0);
    vec4 last = texelFetch(S, c, 0);
    float rnd = mp_rand(mp_hash(uint(c.x) * 73856093u ^ uint(c.y) * 19349663u ^ uint(iFrame) * 83492791u));
    bool restart = iFrame < 2 || textureSize(S, 0) != grid || abs(last.w - (float(model) + 1.0)) > 0.5
        || (pulse_action == 3 && pl.z > 0.5);
    vec4 st;
    if (restart) {
        st = rd_rest();
        if (mm.g < 0.5) {
            vec2 dir;
            float s = rd_seed_shape(seed_mode, uv, mm.b, pl.y, seed_count, seed_size, dir);
            if (model == 2) s = max(s, seed_mode == 3 ? 1.0 : 0.0);
            st = rd_seeded(st, s, rnd, dir);
            if (model == 2 && seed_mode != 3) st.xyz = mix(vec3(0.0), st.xyz, s);
        }
    } else {
        st = sim_speed > 0.0 ? rd_step(S, M, c) : last;
    }
    if (mm.g > 0.5) return rd_rest();
    vec2 dir = vec2(1.0, 0.0);
    float s = 0.0;
    if (pl.z > 0.5 && pulse_amount > 0.0 && !restart) {
        if (pulse_action == 0) s = rd_seed_shape(0, uv, 0.0, pl.y + 100.0, int(clamp(2.0 * pulse_amount, 1.0, 8.0)), seed_size * 1.3, dir);
        else if (pulse_action == 1) s = rd_seed_shape(1, uv, mm.b, pl.y, 0, seed_size, dir) * min(pulse_amount, 1.0);
        else if (pulse_action == 2) {
            vec2 o = rd_off(uv, vec2(0.5));
            float ring = 0.25 * iResolution.y / iResolution.y * 1080.0 * (0.4 + 0.6 * fract(pl.y * 0.37));
            s = 1.0 - smoothstep(0.0, seed_size * 0.6, abs(length(o) - ring));
            dir = o;
        } else if (pulse_action == 4) {
            // disturb: the pattern is wiped in a disc and grows back into it
            vec2 o = rd_off(uv, rd_spot_pos(0, pl.y + 200.0));
            float d = 1.0 - smoothstep(0.7, 1.0, length(o) / max(seed_size * 6.0 * pulse_amount, 1.0));
            st = mix(st, rd_rest(), d);
            st.w = float(model) + 1.0;
        }
    }
    if (brush) {
        vec2 o = rd_off(uv, brush_position);
        float b = 1.0 - smoothstep(0.7, 1.0, length(o) / max(brush_size, 1.0));
        if (b > s) {
            s = b;
            dir = o;
        }
    }
    if (picture_seed > 0.0) {
        vec3 pc = texture(seed_picture, uv).rgb;
        float l = max(pc.r, max(pc.g, pc.b));
        s = max(s, clamp(l * picture_seed - 0.5, 0.0, 1.0) * step(rnd, 0.5));
    }
    st = rd_seeded(st, s, rnd, dir);
    st.w = float(model) + 1.0;
    return st;
}

// Passes R2..R8: a step, or a copy when Sim speed asks for fewer steps
vec4 rd_more(sampler2D S, sampler2D M, ivec2 c, int k) {
    if (float(k) > ceil(sim_speed * 8.0 - 1e-3)) return texelFetch(S, c, 0);
    return rd_step(S, M, c);
}
