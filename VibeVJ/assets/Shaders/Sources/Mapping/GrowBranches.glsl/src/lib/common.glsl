// --- GrowBranches: what every pass shares (the controls, the growing tips) ---
#define MASK_AUTO 2
#include mapping.glsl
#include mask.glsl
#include beat.glsl

//@enum options=(Wither, Burn, Invert, Recede, Reseed) value=1
uniform int cycle_mode;       // how it turns when it is full: dies from the roots on, burns along the branches, new shoots from the old wood, back into the seeds, new seeds take over
//@enum options=(Moss, Coral, Lichen, Embers, Ice, Deep sea, Two colours) value=5
uniform int palette;          // the colours from young to old

#include growth.glsl
#include jfa.glsl

//@slider min=0.05 max=1.0 value=0.5
uniform float grow_speed;     // texels a tip moves in a step (two steps a frame, half size)
//@slider min=0.0 max=1.0 value=0.35
uniform float branching;      // how often a tip splits
//@slider min=5.0 max=90.0 value=35.0
uniform float branch_angle;   // degrees between a branch and the tip it splits from
//@slider min=0.0 max=1.0 value=0.35
uniform float wander;         // how much the tips meander
//@slider min=-1.0 max=1.0 value=0.25
uniform float climb;          // the tips turn up (climbing plants, positive) or down (roots, negative)
//@slider min=0.0 max=1.0 value=0.5
uniform float avoid;          // the tips turn away from other branches and walls ahead
//@slider min=0.0 max=1.0 value=0.4
uniform float follow_edges;   // near an outline of the mask the tips run along it
//@slider min=1.0 max=24.0 value=9.0
uniform float thickness;      // pixels of the oldest, thickest parts
//@slider min=0.5 max=1.0 value=0.82
uniform float taper;          // each branch is this much thinner than the one it came from
//@slider min=4.0 max=120.0 value=40.0
uniform float spacing;        // pixels: the area within this distance of a branch counts as grown

const float BR_MAX_ORDER = 14.0;

vec2 br_dir(float a) { return vec2(cos(a), sin(a)); }

vec4 br_fetch(sampler2D B, ivec2 q) {
    ivec2 hi = textureSize(B, 0) - 1;
    if (q.x < 0 || q.y < 0 || q.x > hi.x || q.y > hi.y) return vec4(3.0, -1.0, 0.0, 0.0);   // outside: a wall
    return texelFetch(B, q, 0);
}

// How blocked the place q (texels) is, 0..1: branches and the edge of the soil around it
float br_sense(sampler2D B, sampler2D M, vec2 q) {
    ivec2 c = ivec2(floor(q));
    ivec2 hi = textureSize(B, 0) - 1;
    float s = 0.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            ivec2 k = c + ivec2(x, y);
            if (k.x < 0 || k.y < 0 || k.x > hi.x || k.y > hi.y) { s += 1.0; continue; }
            if (texelFetch(B, k, 0).x > 0.5 || texelFetch(M, k, 0).r < 0.5) s += 1.0;
        }
    }
    return s / 9.0;
}

// A tip: x 2, y its cell, z its order (how many splits from its seed) * 8 + its direction + 4, w the length of its
// path from the seed (texels) * 256 + its place in its texel (16 x 16). Wood: x 1, y its cell, z its order, w its path.
float br_order(vec4 st) { return st.x > 1.5 ? floor(st.z / 8.0) : st.z; }
float br_theta(vec4 st) { return st.z - floor(st.z / 8.0) * 8.0 - 4.0; }
float br_path(vec4 st) { return st.x > 1.5 ? floor(st.w / 256.0) : st.w; }
vec2 br_frac(vec4 st) {
    float r = st.w - floor(st.w / 256.0) * 256.0;
    return (vec2(floor(r / 16.0), r - floor(r / 16.0) * 16.0) + 0.5) / 16.0;
}
vec4 br_tip(float cell, float order, float th, float path, vec2 f) {
    vec2 q = clamp(floor(f * 16.0), 0.0, 15.0);
    th = mod(th + MP_PI, MP_TAU) - MP_PI;
    return vec4(2.0, cell, min(order, BR_MAX_ORDER) * 8.0 + th + 4.0, min(path, 65000.0) * 256.0 + q.x * 16.0 + q.y);
}
vec4 br_wood(vec4 tip) { return vec4(1.0, tip.y, br_order(tip), br_path(tip)); }

// What the tip at texel n (state st) does in this step: where it goes (np, texels), its new direction, whether it dies,
// and whether it splits (cp, thc: the place and direction of the new branch). The tip and its neighbours all call
// this with the same values, so they agree on where it goes.
void br_plan(sampler2D B, sampler2D M, ivec2 n, vec4 st, int step_id,
             out vec2 np, out float th, out bool die, out bool fork, out vec2 cp, out float thc) {
    float order = br_order(st);
    vec2 pos = vec2(n) + br_frac(st);
    th = br_theta(st);
    ivec3 h = ivec3(n, iFrame * 2 + step_id);
    // meander, climb (turn towards up or down), along the outlines
    th += (mp_rand3(h) - 0.5) * wander * 0.9;
    float up = climb >= 0.0 ? MP_PI * 0.5 : -MP_PI * 0.5;
    th += abs(climb) * 0.12 * sin(up - th);
    vec4 mm = texelFetch(M, n, 0);
    if (follow_edges > 0.0 && mm.g > 0.5) {
        float t1 = mm.a + MP_PI * 0.5;
        float t2 = mm.a - MP_PI * 0.5;
        float tt = cos(t1 - th) > cos(t2 - th) ? t1 : t2;
        th += follow_edges * 0.5 * sin(tt - th);
    }
    // feelers to the left and the right: away from other branches and walls
    if (avoid > 0.0) {
        float sl = br_sense(B, M, pos + br_dir(th + 0.55) * 4.5) + br_sense(B, M, pos + br_dir(th + 0.3) * 8.0);
        float sr = br_sense(B, M, pos + br_dir(th - 0.55) * 4.5) + br_sense(B, M, pos + br_dir(th - 0.3) * 8.0);
        th += avoid * 0.6 * (sr - sl);
    }
    th = mod(th + MP_PI, MP_TAU) - MP_PI;
    np = pos + br_dir(th) * grow_speed;
    // a tip that stood still for 3 beats (blocked) or belongs to the generation before dies
    die = !gr_is_current(st.y) || gr_clock - gr_cell_birth(st.y) > 3.0;
    fork = order < BR_MAX_ORDER && mp_rand3(h + ivec3(0, 0, 7)) < branching * 0.05 * grow_speed * pow(0.88, order);
    float side = mp_rand3(h + ivec3(0, 0, 11)) < 0.5 ? 1.0 : -1.0;
    thc = th + side * radians(branch_angle);
    cp = pos + br_dir(thc) * 1.25;
}

// One step of the tips at texel p. B: the step before (x 0 empty / 1 wood / 2 tip, y the cell: gr_pack or -1,
// z the direction of a tip or the order of the wood (how many splits from the seed), w a tip's order and the place in
// its texel), M: the soil (r), the outlines (g) and their direction (a).
vec4 br_step(sampler2D B, sampler2D M, sampler2D T, ivec2 p, bool first_step) {
    if (iFrame < 3) return vec4(0.0, -1.0, 0.0, 0.0);
    int step_id = first_step ? 0 : 1;
    vec2 res = vec2(textureSize(B, 0));
    vec2 uv = (vec2(p) + 0.5) / res;
    vec4 c = texelFetch(B, p, 0);
    vec4 mm = texelFetch(M, p, 0);

    // the turn: the generation before dies in the order of the mode
    if (c.x > 0.5 && !gr_is_current(c.y)) {
        if (gr_decay(c.y, uv) >= 1.0) c = vec4(0.0, -1.0, 0.0, 0.0);
        else if (c.x > 1.5) c = br_wood(c);   // its tips stop
    }

    if (c.x > 1.5) {
        // a tip: stays (still in its texel), moves on (it becomes wood here) or dies
        vec2 np;
        float th;
        bool die;
        bool fork;
        vec2 cp;
        float thc;
        br_plan(B, M, p, c, step_id, np, th, die, fork, cp, thc);
        float order = br_order(c);
        if (die) return br_wood(c);
        ivec2 t = ivec2(floor(np));
        if (t == p) return br_tip(c.y, order, th, br_path(c), fract(np));
        vec4 tc = br_fetch(B, t);
        bool soil = t.x >= 0 && t.y >= 0 && t.x < int(res.x) && t.y < int(res.y) && texelFetch(M, t, 0).r > 0.5;
        if (tc.x < 0.5 && soil) return br_wood(c);
        if (!soil) return br_tip(c.y, order, th + (mp_rand3(ivec3(p, iFrame)) < 0.5 ? 0.6 : -0.6), br_path(c), br_frac(c));  // a wall: turn
        return br_wood(c);   // ran into a branch: ends here
    }
    if (c.x > 0.5) return c;   // wood stays

    // empty: a tip next to it may move here, or split into here
    if (mm.r > 0.5 && gr_regrow) {
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                if (x == 0 && y == 0) continue;
                ivec2 n = p + ivec2(x, y);
                vec4 nb = br_fetch(B, n);
                if (nb.x < 1.5 || nb.x > 2.5) continue;
                vec2 np;
                float th;
                bool die;
                bool fork;
                vec2 cp;
                float thc;
                br_plan(B, M, n, nb, step_id, np, th, die, fork, cp, thc);
                if (die) continue;
                float order = br_order(nb);
                float path = br_path(nb) + 1.0;
                if (ivec2(floor(np)) == p) return br_tip(gr_new_cell(), order, th, path, fract(np));
                if (fork && ivec2(floor(cp)) == p && ivec2(floor(np)) != p)
                    return br_tip(gr_new_cell(), order + 1.0, thc, path, fract(cp));
            }
        }
    }

    // seeds: a single tip each
    if (first_step && mm.r > 0.5) {
        float s = gr_seeds(M, T, p, 0.8, 1.0, 0.0, 0.004);
        float th0 = climb > 0.05 ? MP_PI * 0.5 : (climb < -0.05 ? -MP_PI * 0.5 : mp_rand3(ivec3(p, 5)) * MP_TAU);
        th0 += (mp_rand3(ivec3(p, 9)) - 0.5) * 1.2;
        if (gr_seed_now && seed_edges > 0.0 && mm.g > 0.5 && mp_rand3(ivec3(p, int(gr_gen) + 900)) < seed_edges * 0.02) {
            // out of the outline into the soil
            s = 1.0;
            th0 = (mask_role == 1 ? mm.a + MP_PI : mm.a) + (mp_rand3(ivec3(p, 13)) - 0.5) * 1.4;
        }
        // Invert: new shoots out of the old wood, into the gaps
        if (cycle_mode == 2 && gr_seed_now) {
            for (int k = 0; k < 4; k++) {
                ivec2 o = k == 0 ? ivec2(1, 0) : (k == 1 ? ivec2(-1, 0) : (k == 2 ? ivec2(0, 1) : ivec2(0, -1)));
                vec4 nb = br_fetch(B, p + o);
                if (nb.x > 0.5 && nb.x < 2.5 && nb.y >= 0.0 && mp_rand3(ivec3(p, 77 + k)) < 0.012) {
                    s = 1.0;
                    th0 = atan(-float(o.y), -float(o.x)) + (mp_rand3(ivec3(p, 31)) - 0.5) * 1.2;
                }
            }
        }
        if (s > 0.5) return br_tip(gr_new_cell(), 0.0, th0, 0.0, vec2(0.5));
    }
    return vec4(0.0, -1.0, 0.0, 0.0);
}

// The radius (texels of the simulation) of the wood at a cell: the oldest and lowest order is the thickest
float br_radius(vec4 st, float age) {
    float order = br_order(st);
    float grow = 0.45 + 0.55 * (1.0 - exp(-age / max(age_span, 0.5)));
    return max(thickness * 0.25 * pow(taper, order) * grow, 0.8);   // half of the width, at half size
}
