// --- GrowFrost: what every pass shares (the controls, one step of the phase field) ---
#define MASK_AUTO 3
#include mapping.glsl
#include mask.glsl
#include beat.glsl

//@enum options=(Wither, Burn, Invert, Recede, Reseed) value=3
uniform int cycle_mode;       // how it turns when it is full: thaws from the old parts, burns, the gaps freeze, back into the seeds, new seeds take over
//@enum options=(Moss, Coral, Lichen, Embers, Ice, Deep sea, Two colours) value=4
uniform int palette;          // the colours from young to old

#define GR_DRY vec3(0.2, 0.3, 0.42)

#include growth.glsl

//@int min=2 max=8 value=6
uniform int symmetry;         // arms of a crystal: 6 snow, 4 square crystals, 2 needles
//@slider min=0.0 max=0.06 value=0.025
uniform float anisotropy;     // how strongly the crystals follow their axes: 0 round blobs
//@slider min=0.0 max=1.0 value=0.35
uniform float side_branches;  // noise at the growing tips: more side branches
//@slider min=0.1 max=1.3 value=1.0
uniform float grow_speed;     // the time step of the freezing (six steps a frame)
//@slider min=0.5 max=1.0 value=0.9
uniform float cold;           // how hard it freezes: faster, thicker crystals
//@slider min=0.8 max=2.4 value=1.6
uniform float latent_heat;    // heat the freezing gives off: more makes thinner, more branched crystals
//@slider min=0.0 max=1.0 value=0.15
uniform float cooling;        // how fast the heat goes away, so it keeps growing into the gaps; much makes compact grains
//@enum options=(Random, Same for all, Along the outlines) value=0
uniform int orientation;      // which way the crystals point: each its own, all the same, or along the outline that seeded them
//@slider min=-180.0 max=180.0 value=0.0
uniform float angle;          // Same for all: the angle of the axes, degrees

// The grid spacing and the time step of Kobayashi's model (1993); stable up to grow speed 1.3
const float FR_DX = 0.03;
const float FR_TAU = 0.0003;
const float FR_EPS = 0.01;

vec4 fr_fetch(sampler2D F, ivec2 q) {
    ivec2 hi = textureSize(F, 0) - 1;
    return texelFetch(F, clamp(q, ivec2(0), hi), 0);
}

// The phase of a neighbour: outside the soil it is the texel's own, so nothing grows through a wall
float fr_p(sampler2D F, sampler2D M, ivec2 q, float own) {
    ivec2 hi = textureSize(F, 0) - 1;
    ivec2 qc = clamp(q, ivec2(0), hi);
    return texelFetch(M, qc, 0).r < 0.5 ? own : texelFetch(F, qc, 0).x;
}

// eps and eps * eps' of a texel from its gradient and the axis of its crystal (a)
vec2 fr_eps(vec2 g, float a) {
    float th = dot(g, g) > 1e-10 ? atan(g.y, g.x) : 0.0;
    float j = float(symmetry);
    float e = FR_EPS * (1.0 + anisotropy * cos(j * (th - a)));
    float de = -FR_EPS * j * anisotropy * sin(j * (th - a));
    return vec2(e, e * de);
}

// The axis of a new crystal at uv
float fr_new_axis(vec2 uv, vec4 mm) {
    if (orientation == 1) return radians(angle);
    if (orientation == 2) return mm.a + radians(angle);
    float a = iResolution.x / max(iResolution.y, 1.0);
    return mp_vnoise(vec2(uv.x * a, uv.y) * 7.0 + gr_gen * 3.3) * MP_TAU * 2.0;
}

// One step of the phase field at texel p. F: the step before (r the phase: 0 water 1 ice, g the temperature, b the
// cell: gr_pack or -1, a the axis of its crystal), M: the soil. The first step of a frame also plants the seeds.
vec4 frost_step(sampler2D F, sampler2D M, sampler2D T, ivec2 p, bool first_step) {
    if (iFrame < 3) return vec4(0.0, 0.0, -1.0, 0.0);
    vec2 res = vec2(textureSize(F, 0));
    vec2 uv = (vec2(p) + 0.5) / res;
    vec4 c = texelFetch(F, p, 0);
    vec4 mm = texelFetch(M, p, 0);
    float p0 = c.x;
    // the phase on a cross of 13 texels (walls: the own value)
    float pl = fr_p(F, M, p + ivec2(-1, 0), p0);
    float pr = fr_p(F, M, p + ivec2(1, 0), p0);
    float pd = fr_p(F, M, p + ivec2(0, -1), p0);
    float pu = fr_p(F, M, p + ivec2(0, 1), p0);
    float pll = fr_p(F, M, p + ivec2(-2, 0), pl);
    float prr = fr_p(F, M, p + ivec2(2, 0), pr);
    float pdd = fr_p(F, M, p + ivec2(0, -2), pd);
    float puu = fr_p(F, M, p + ivec2(0, 2), pu);
    float plu = fr_p(F, M, p + ivec2(-1, 1), p0);
    float pld = fr_p(F, M, p + ivec2(-1, -1), p0);
    float pru = fr_p(F, M, p + ivec2(1, 1), p0);
    float prd = fr_p(F, M, p + ivec2(1, -1), p0);
    vec4 cl = fr_fetch(F, p + ivec2(-1, 0));
    vec4 cr = fr_fetch(F, p + ivec2(1, 0));
    vec4 cd = fr_fetch(F, p + ivec2(0, -1));
    vec4 cu = fr_fetch(F, p + ivec2(0, 1));
    float h2 = 2.0 * FR_DX;
    vec2 g0 = vec2(pr - pl, pu - pd) / h2;
    vec2 gl = vec2(p0 - pll, plu - pld) / h2;
    vec2 gr = vec2(prr - p0, pru - prd) / h2;
    vec2 gd = vec2(prd - pld, p0 - pdd) / h2;
    vec2 gu = vec2(pru - plu, puu - p0) / h2;
    vec2 e0 = fr_eps(g0, c.w);
    vec2 el = fr_eps(gl, cl.w);
    vec2 er = fr_eps(gr, cr.w);
    vec2 ed = fr_eps(gd, cd.w);
    vec2 eu = fr_eps(gu, cu.w);
    float lap = (pl + pr + pd + pu - 4.0 * p0) / (FR_DX * FR_DX);
    float div = e0.x * e0.x * lap + (er.x * er.x - el.x * el.x) / h2 * g0.x + (eu.x * eu.x - ed.x * ed.x) / h2 * g0.y;
    float t1 = -(er.y * gr.y - el.y * gl.y) / h2;
    float t2 = (eu.y * gu.x - ed.y * gd.x) / h2;
    float temp = c.y;
    float m = cold / MP_PI * atan(10.0 * (1.0 - temp));
    float noise = (mp_rand3(ivec3(p, iFrame)) - 0.5) * side_branches * 0.1;
    float dp = (t1 + t2 + div + p0 * (1.0 - p0) * (p0 - 0.5 + m + noise)) / FR_TAU;
    float dt = 1e-4 * grow_speed;
    float pn = clamp(p0 + dt * dp, 0.0, 1.0);
    // the heat: spreads (the walls keep it), comes from freezing, goes away by Cooling
    float tl = texelFetch(M, clamp(p + ivec2(-1, 0), ivec2(0), ivec2(res) - 1), 0).r < 0.5 ? temp : cl.y;
    float tr = texelFetch(M, clamp(p + ivec2(1, 0), ivec2(0), ivec2(res) - 1), 0).r < 0.5 ? temp : cr.y;
    float td = texelFetch(M, clamp(p + ivec2(0, -1), ivec2(0), ivec2(res) - 1), 0).r < 0.5 ? temp : cd.y;
    float tu = texelFetch(M, clamp(p + ivec2(0, 1), ivec2(0), ivec2(res) - 1), 0).r < 0.5 ? temp : cu.y;
    float tn = temp + dt * (tl + tr + td + tu - 4.0 * temp) / (FR_DX * FR_DX) + latent_heat * (pn - p0);
    tn *= 1.0 - cooling * 0.001 * grow_speed;
    float cell = c.z;
    float axis = c.w;

    bool cur_l = gr_is_current(cl.z);
    bool cur_r = gr_is_current(cr.z);
    bool cur_d = gr_is_current(cd.z);
    bool cur_u = gr_is_current(cu.z);
    bool next_to_new = cur_l || cur_r || cur_d || cur_u;
    if (cell >= 0.0 && !gr_is_current(cell)) {
        float dec = gr_decay(cell, uv);
        if (cycle_mode == 4 && next_to_new && dec < 1.0 && mp_rand3(ivec3(p, iFrame)) < 0.2) {
            cell = gr_new_cell();   // Reseed: the new crystals take the old ice over
        } else if (dec >= 1.0) {
            cell = -1.0;
            pn = 0.0;
            tn = 0.0;
        } else {
            // thawing takes the heat back, so the water is cold again for the next generation
            pn = min(pn, 1.0 - dec);
            tn *= 1.0 - 0.05 * dec;
        }
    }
    if (cell < 0.0) {
        bool next_to_old = (cl.z >= 0.0 && !cur_l) || (cr.z >= 0.0 && !cur_r) || (cd.z >= 0.0 && !cur_d) || (cu.z >= 0.0 && !cur_u);
        if (!gr_regrow || (next_to_old && !next_to_new)) {
            pn = 0.0;   // nothing freezes here before the new generation may, the old ice does not grow
            tn *= 0.95;
        } else if (pn > 0.5) {
            cell = gr_new_cell();
            // the axis of the crystal it grew from
            float best = -1.0;
            if (cur_l && cl.x > best) { best = cl.x; axis = cl.w; }
            if (cur_r && cr.x > best) { best = cr.x; axis = cr.w; }
            if (cur_d && cd.x > best) { best = cd.x; axis = cd.w; }
            if (cur_u && cu.x > best) { best = cu.x; axis = cu.w; }
        } else if (pn > 0.02) {
            // the soft edge of a growing crystal carries its axis
            if (cur_l) axis = cl.w;
            else if (cur_r) axis = cr.w;
            else if (cur_d) axis = cd.w;
            else if (cur_u) axis = cu.w;
        }
    }

    if (first_step) {
        float s = gr_seeds(M, T, p, 2.5, 1.5, 0.25, 0.3);
        // Invert: the gaps freeze, seeded along the edges of the old ice
        if (cycle_mode == 2 && gr_seed_now && cell < 0.0
            && (cl.z >= 0.0 || cr.z >= 0.0 || cd.z >= 0.0 || cu.z >= 0.0) && mp_rand3(ivec3(p, 77)) < 0.15) s = 1.0;
        if (s > 0.0) {
            pn = max(pn, s);
            if (cell < 0.0) {
                cell = gr_new_cell();
                axis = fr_new_axis(uv, mm);
                tn = 0.0;
            }
        }
    }

    if (mm.r < 0.5) {
        pn = 0.0;
        tn = 0.0;
        cell = -1.0;
    }
    return vec4(pn, clamp(tn, -1.0, 2.0), cell, axis);
}
