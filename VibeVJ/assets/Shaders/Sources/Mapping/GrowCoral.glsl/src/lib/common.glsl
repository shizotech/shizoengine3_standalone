// --- GrowCoral: what every pass shares (the controls, one step of the reaction and diffusion) ---
#define MASK_AUTO 2
#include mapping.glsl
#include mask.glsl
#include beat.glsl

//@enum options=(Wither, Burn, Invert, Recede, Reseed) value=0
uniform int cycle_mode;       // how it turns when it is full: dies from the old parts, burns, the gaps grow, back into the seeds, new seeds take over
//@enum options=(Moss, Coral, Lichen, Embers, Ice, Deep sea, Two colours) value=1
uniform int palette;          // the colours from young to old

#include growth.glsl

//@enum options=(Coral, Maze, Fingerprint, Spots, Worms, Bubbles) value=0
uniform int pattern;          // the kind of shape the reaction makes
//@slider min=0.05 max=1.0 value=1.0
uniform float grow_speed;     // the time step of the reaction (six steps a frame)
//@slider min=0.0 max=1.0 value=0.35
uniform float variation;      // the pattern changes from place to place
//@slider min=-0.01 max=0.01 value=0.0
uniform float feed_offset;    // fine tuning: more feed gives fuller shapes
//@slider min=-0.005 max=0.005 value=0.0
uniform float kill_offset;    // fine tuning: more kill gives thinner shapes, too much and they die

// Feed and kill of the Gray-Scott reaction at uv
vec2 rd_params(vec2 uv) {
    vec2 fk = vec2(0.0545, 0.062);
    if (pattern == 1) fk = vec2(0.029, 0.057);
    else if (pattern == 2) fk = vec2(0.037, 0.06);
    else if (pattern == 3) fk = vec2(0.0367, 0.0649);
    else if (pattern == 4) fk = vec2(0.078, 0.061);
    else if (pattern == 5) fk = vec2(0.039, 0.058);
    float a = iResolution.x / max(iResolution.y, 1.0);
    vec2 q = vec2(uv.x * a, uv.y) * 2.2 + vec2(gr_gen * 1.37, 0.0);
    float n = mp_vnoise(q) - 0.5;
    fk += variation * vec2(n * 0.008, n * 0.0025);
    fk += vec2(feed_offset, kill_offset);
    return fk;
}

vec4 rd_fetch(sampler2D R, ivec2 q) {
    ivec2 hi = textureSize(R, 0) - 1;
    return texelFetch(R, clamp(q, ivec2(0), hi), 0);
}

// U and V of a neighbour for the diffusion: outside the soil the texel's own (no flow through a wall, so the shapes
// do not stick to the outlines)
vec2 rd_nb(sampler2D R, sampler2D M, ivec2 q, vec2 own) {
    ivec2 hi = textureSize(R, 0) - 1;
    ivec2 qc = clamp(q, ivec2(0), hi);
    return texelFetch(M, qc, 0).r < 0.5 ? own : texelFetch(R, qc, 0).xy;
}

// One step of the reaction and diffusion at texel p. R: the step before (r U, g V, b the cell: gr_pack or -1,
// a its variation), M: the soil (r) and the outlines (g). The first step of a frame also plants the seeds.
vec4 rd_step(sampler2D R, sampler2D M, sampler2D T, ivec2 p, bool first_step) {
    if (iFrame < 3) return vec4(1.0, 0.0, -1.0, 0.0);
    vec2 res = vec2(textureSize(R, 0));
    vec2 uv = (vec2(p) + 0.5) / res;
    vec4 c = texelFetch(R, p, 0);
    vec4 l = rd_fetch(R, p - ivec2(1, 0));
    vec4 r = rd_fetch(R, p + ivec2(1, 0));
    vec4 d = rd_fetch(R, p - ivec2(0, 1));
    vec4 u = rd_fetch(R, p + ivec2(0, 1));
    vec2 lap = 0.2 * (rd_nb(R, M, p - ivec2(1, 0), c.xy) + rd_nb(R, M, p + ivec2(1, 0), c.xy)
                    + rd_nb(R, M, p - ivec2(0, 1), c.xy) + rd_nb(R, M, p + ivec2(0, 1), c.xy)) - c.xy;
    lap += 0.05 * (rd_nb(R, M, p + ivec2(1, 1), c.xy) + rd_nb(R, M, p + ivec2(-1, 1), c.xy)
                 + rd_nb(R, M, p + ivec2(1, -1), c.xy) + rd_nb(R, M, p + ivec2(-1, -1), c.xy));
    vec2 fk = rd_params(uv);
    float dt = grow_speed;
    float U = c.x;
    float V = c.y;
    float uvv = U * V * V;
    U += dt * (lap.x - uvv + fk.x * (1.0 - U));
    V += dt * (0.5 * lap.y + uvv - (fk.x + fk.y) * V);
    float cell = c.z;
    float vari = c.w;

    // the turn: the cells of the generation before die in the order of the mode; Reseed: the new generation
    // overgrows them
    bool cur_l = gr_is_current(l.z);
    bool cur_r = gr_is_current(r.z);
    bool cur_d = gr_is_current(d.z);
    bool cur_u = gr_is_current(u.z);
    bool next_to_new = cur_l || cur_r || cur_d || cur_u;
    if (cell >= 0.0 && !gr_is_current(cell)) {
        float dec = gr_decay(cell, uv);
        if (cycle_mode == 4 && next_to_new && dec < 1.0 && mp_rand3(ivec3(p, iFrame)) < 0.3) {
            // Reseed: the new generation overgrows the old one
            cell = gr_new_cell();
        } else if (dec >= 1.0) {
            cell = -1.0;
            U = 1.0;
            V = 0.0;
        } else {
            // dying: the shapes thin out and the reaction stops
            V = min(V, (1.0 - dec) * 0.5);
            U = max(U, dec);
        }
    }
    if (cell < 0.0) {
        bool next_to_old = (l.z >= 0.0 && !cur_l) || (r.z >= 0.0 && !cur_r) || (d.z >= 0.0 && !cur_d) || (u.z >= 0.0 && !cur_u);
        if (!gr_regrow || (next_to_old && !next_to_new)) {
            // fallow: nothing grows here before the new generation may, and the old one does not spread
            U = 1.0;
            V = 0.0;
        } else if (V > 0.25) {
            // reached by the front: a new cell with the variation of a neighbour
            cell = gr_new_cell();
            vari = cur_l ? l.w : (cur_r ? r.w : (cur_d ? d.w : (cur_u ? u.w : vari)));
        }
    }

    if (first_step) {
        float s = gr_seeds(M, T, p, 3.5, 6.0, 0.8, 1.0);
        // Invert: the gaps of the old generation are the new soil, seeded along its edges
        if (cycle_mode == 2 && gr_seed_now && cell < 0.0
            && (l.z >= 0.0 || r.z >= 0.0 || d.z >= 0.0 || u.z >= 0.0) && mp_rand3(ivec3(p, 77)) < 0.2) s = 1.0;
        if (s > 0.0) {
            V = max(V, (0.45 + 0.2 * mp_rand3(ivec3(p, iFrame + 9))) * s);
            U = min(U, mix(1.0, 0.35, s));
            if (cell < 0.0) {
                cell = gr_new_cell();
                vari = fract(mp_vnoise(uv * 5.0 + gr_gen * 1.7) * 2.3);
            }
        }
    }

    // walls: nothing grows outside the soil
    if (texelFetch(M, p, 0).r < 0.5) {
        U = 1.0;
        V = 0.0;
        cell = -1.0;
    }
    return vec4(clamp(U, 0.0, 1.0), clamp(V, 0.0, 1.0), cell, vari);
}
