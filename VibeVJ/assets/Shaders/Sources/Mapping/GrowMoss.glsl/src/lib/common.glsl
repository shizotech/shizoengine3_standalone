// --- GrowMoss: what every pass shares (the controls, one step of the spreading) ---
#define MASK_AUTO 2
#include mapping.glsl
#include mask.glsl
#include beat.glsl

//@enum options=(Wither, Burn, Invert, Recede, Reseed) value=0
uniform int cycle_mode;       // how it turns when it is full: dries from the old parts, burns, the gaps grow, back into the seeds, new colonies take over
//@enum options=(Moss, Coral, Lichen, Embers, Ice, Deep sea, Two colours) value=0
uniform int palette;          // the colours from young to old

#include growth.glsl

//@enum options=(Moss, Lichen, Mould) value=0
uniform int style;            // Moss: soft tufts. Lichen: flat crusts with growth rings. Mould: fuzzy, glowing threads
//@slider min=0.0 max=1.0 value=0.5
uniform float grow_speed;     // how fast it spreads (two steps a frame)
//@slider min=0.0 max=1.0 value=0.6
uniform float patchiness;     // some places are fertile, some barren: ragged, organic fronts
//@slider min=0.5 max=8.0 value=2.5
uniform float patch_size;     // the size of the fertile places
//@slider min=0.0 max=1.0 value=0.5
uniform float follow_edges;   // spreads faster along the outlines of the mask (cracks, joints)
//@slider min=0.0 max=1.0 value=0.35
uniform float thicken;        // how fast the covered parts get thick

// How fertile uv is (0..1): where it spreads fast and gets thick
float ms_fertile(vec2 uv) {
    float a = iResolution.x / max(iResolution.y, 1.0);
    vec2 q = vec2(uv.x * a, uv.y) * patch_size + vec2(gr_gen * 5.31, gr_gen * 2.17);
    float n = mp_vnoise(q) * 0.6 + mp_vnoise(q * 2.3 + 7.0) * 0.3 + mp_vnoise(q * 5.1 + 3.0) * 0.1;
    return mix(1.0, smoothstep(0.25, 0.75, n), patchiness);
}

vec4 ms_fetch(sampler2D G, ivec2 q) {
    ivec2 hi = textureSize(G, 0) - 1;
    return texelFetch(G, clamp(q, ivec2(0), hi), 0);
}

// One step of the spreading at texel p. G: the step before (r the thickness 0..1, g the fertility, b the cell:
// gr_pack or -1, a its colony: a variation 0..1 it got from its seed), M: the soil and the outlines.
vec4 moss_step(sampler2D G, sampler2D M, sampler2D T, ivec2 p, bool first_step) {
    if (iFrame < 3) return vec4(0.0, 0.0, -1.0, 0.0);
    vec2 res = vec2(textureSize(G, 0));
    vec2 uv = (vec2(p) + 0.5) / res;
    vec4 c = texelFetch(G, p, 0);
    vec4 mm = texelFetch(M, p, 0);
    float th = c.x;
    float cell = c.z;
    float colony = c.w;
    float fert = ms_fertile(uv);
    int step_id = first_step ? 0 : 1;

    // the 8 neighbours: how many are living cells of this generation, how many of the one before, a colony to take
    int cur_n = 0;
    int old_n = 0;
    float take = colony;
    float pick = mp_rand3(ivec3(p, iFrame * 2 + step_id));
    int k = 0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            if (x == 0 && y == 0) continue;
            vec4 nb = ms_fetch(G, p + ivec2(x, y));
            if (nb.z < 0.0) continue;
            if (gr_is_current(nb.z)) {
                cur_n++;
                if (float(k) <= pick * 8.0) take = nb.w;
                k++;
            } else old_n++;
        }
    }

    if (cell >= 0.0 && !gr_is_current(cell)) {
        float dec = gr_decay(cell, uv);
        if (cycle_mode == 4 && cur_n > 0 && dec < 1.0 && pick < 0.12 * float(cur_n)) {
            cell = gr_new_cell();   // Reseed: the new colonies overgrow the old ones
            colony = take;
        } else if (dec >= 1.0) {
            cell = -1.0;
            th = 0.0;
        } else {
            th = min(th, 1.0 - dec);
        }
    } else if (cell >= 0.0) {
        // a living cell gets thicker, up to what its place gives
        float target = mix(0.35, 1.0, fert);
        th += (target - th) * thicken * 0.02;
    }

    if (cell < 0.0) {
        th = 0.0;
        if (gr_regrow && cur_n > 0 && mm.r > 0.5) {
            // a free texel next to living ones is reached with a chance per step: more neighbours, fertile ground and
            // the outlines make it likelier
            float edge = mm.g * follow_edges * 3.0;
            float chance = grow_speed * 0.18 * float(cur_n) / 3.0 * (fert * fert + edge);
            if (old_n > 0 && cur_n == 0) chance = 0.0;
            if (mp_rand3(ivec3(p, iFrame * 2 + step_id + 1000)) < chance) {
                cell = gr_new_cell();
                colony = take;
                th = 0.05;
            }
        }
    }

    if (first_step) {
        float s = gr_seeds(M, T, p, 3.0, 4.0, 0.5, 0.5);
        if (cycle_mode == 2 && gr_seed_now && cell < 0.0 && old_n > 0 && mp_rand3(ivec3(p, 77)) < 0.3) s = 1.0;
        if (s > 0.0 && cell < 0.0) {
            cell = gr_new_cell();
            colony = mp_rand3(ivec3(ivec2(uv * 9.0), int(gr_gen) + 300));
            th = 0.2;
        }
    }

    if (mm.r < 0.5) {
        th = 0.0;
        cell = -1.0;
    }
    return vec4(clamp(th, 0.0, 1.0), fert, cell, colony);
}
