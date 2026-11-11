//@settings dtype=float32 format=rgba renderscale=0.125
// --- MaskSwarm, pass B: the boids on a grid of cells at an eighth of the size, one boid a cell at most. A cell keeps
// the boid that moves into it, steers it (separation, alignment, cohesion from the neighbours within View radius,
// around the walls of the mask with the jump flood, along the outlines, to the target, with the wind and the pulse)
// and moves it on. New boids appear in empty cells while the flock is smaller than Population (pass C counts it) ---
#define PASS_SCALE 0.125
#include lib/common.glsl

uniform sampler2D feedback;
uniform sampler2D C;
uniform sampler2D M;
uniform sampler2D J10;
uniform sampler2D T;

ivec2 wrap_cell(ivec2 n, ivec2 grid) { return (n % grid + grid) % grid; }

// The outline seen from a place (cells): the distance in pixels (negative inside the walls) and the direction out of
// the walls
float wall_distance(vec2 pos, out vec2 out_dir) {
    vec2 suv;
    vec2 nrm;
    float strength;
    float d = jfa_lookup(J10, pos, suv, nrm, strength);
    vec2 uv = pos / iResolution.xy;
    float wall = sw_wall_of(mp_bilinear_uv(M, uv).r);
    vec2 to_seed = suv * iResolution.xy - pos;
    float l = length(to_seed);
    vec2 dir = l > 1e-4 ? to_seed / l : -nrm;
    if (wall > 0.5) {
        out_dir = dir;        // inside: out is towards the outline
        return -d;
    }
    out_dir = -dir;           // outside: away from it
    return d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 grid = ivec2(iResolution.xy);
    vec2 gridF = vec2(grid);
    ivec2 c = ivec2(floor(fragCoord));
    Boid none;
    none.alive = false;
    none.pos = vec2(0.0);
    none.vel = vec2(0.0);
    none.seed = 0.0;
    if (iFrame < 2 || textureSize(feedback, 0) != grid) {
        fragColor = sw_encode(none);
        return;
    }
    bool use_mask = mp_mask_mode() != 4 && mask_role != 2;
    bool has_outline = mp_mask_mode() != 4;
    float px = 1.0 / PASS_SCALE;                    // pixels of the full picture in a cell
    vec3 pl = mp_pulse(T);

    // the boid that moved into this cell
    Boid me = none;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            ivec2 n = c + ivec2(x, y);
            if (borders == 0) n = wrap_cell(n, grid);
            else if (n.x < 0 || n.y < 0 || n.x >= grid.x || n.y >= grid.y) continue;
            Boid b = sw_decode(texelFetch(feedback, n, 0));
            if (!b.alive || ivec2(floor(b.pos)) != c) continue;
            if (!me.alive || b.seed < me.seed) me = b;
        }
    }

    uint h0 = mp_hash(uint(c.x) * 73856093u ^ uint(c.y) * 19349663u ^ uint(iFrame) * 83492791u);
    if (!me.alive) {
        // a new boid while the flock is too small
        float share = texelFetch(C, ivec2(0, 0), 0).r;
        float deficit = clamp((population - share) / max(population, 1e-3), 0.0, 1.0);
        vec2 cc = vec2(c) + 0.5;
        float place = 1.0;
        vec2 dir = vec2(cos(mp_rand(h0 + 5u) * MP_TAU), sin(mp_rand(h0 + 5u) * MP_TAU));
        if (spawn == 1) {
            float e = min(min(cc.x, gridF.x - cc.x), min(cc.y, gridF.y - cc.y));
            place = e < 1.5 ? 1.0 : 0.0;
            dir = normalize(gridF * 0.5 - cc + (vec2(mp_rand(h0 + 6u), mp_rand(h0 + 7u)) - 0.5) * gridF.y);
        } else if (spawn == 2 && has_outline) {
            vec2 od;
            float d = wall_distance(cc, od);
            place = d > 0.0 && d < 3.0 * px ? 1.0 : 0.0;
            dir = od;
        } else if (spawn == 3) {
            vec2 t = target * gridF;
            place = length(cc - t) < 4.0 ? 1.0 : 0.0;
            dir = normalize(cc - t + 1e-3);
        }
        if (use_mask && sw_wall_of(texelFetch(M, ivec2(cc / gridF * vec2(textureSize(M, 0))), 0).r) > 0.5) place = 0.0;
        float chance = deficit * 0.03 * place * (spawn == 0 ? 1.0 : 6.0);
        if (mp_rand(h0) >= chance) {
            fragColor = sw_encode(none);
            return;
        }
        me.alive = true;
        me.pos = vec2(c) + 0.1 + 0.8 * vec2(mp_rand(h0 + 1u), mp_rand(h0 + 2u));
        me.vel = dir * speed;
        me.seed = floor(mp_rand(h0 + 3u) * 64.0);
    }

    // the neighbours
    vec2 sep = vec2(0.0);
    vec2 sum_v = vec2(0.0);
    vec2 sum_p = vec2(0.0);
    float count = 0.0;
    float vr = clamp(view_radius, 1.0, 3.0);
    for (int y = -3; y <= 3; y++) {
        for (int x = -3; x <= 3; x++) {
            if (float(abs(x)) > vr + 0.5 || float(abs(y)) > vr + 0.5) continue;
            ivec2 n = c + ivec2(x, y);
            if (borders == 0) n = wrap_cell(n, grid);
            else if (n.x < 0 || n.y < 0 || n.x >= grid.x || n.y >= grid.y) continue;
            Boid b = sw_decode(texelFetch(feedback, n, 0));
            if (!b.alive) continue;
            vec2 d = b.pos - me.pos;
            if (borders == 0) d -= gridF * floor(d / gridF + 0.5);
            float dl = length(d);
            if (dl < 1e-4 || dl > vr) continue;
            count += 1.0;
            sum_v += b.vel;
            sum_p += d;
            if (dl < 1.6) sep -= d / (dl * dl + 0.05);
        }
    }

    vec2 acc = vec2(0.0);
    float pulse = pl.x * pulse_amount;
    float coh = cohesion;
    if (pulse_action == 0) coh -= pulse * 4.0;
    if (count > 0.0) {
        acc += (sum_v / count - me.vel) * alignment * 0.08;
        acc += (sum_p / count) * coh * 0.01;
    }
    acc += sep * separation * 0.02;

    // the wind: the curl of a noise
    vec2 q = me.pos / gridF.y * wander_scale + vec2(0.0, float(iFrame) * 0.002);
    float e = 0.05;
    float n1 = mp_vnoise(q + vec2(0.0, e));
    float n2 = mp_vnoise(q - vec2(0.0, e));
    float n3 = mp_vnoise(q + vec2(e, 0.0));
    float n4 = mp_vnoise(q - vec2(e, 0.0));
    acc += vec2(n1 - n2, n4 - n3) / (2.0 * e) * wander * 0.01;

    // the mask: steer around the walls (seen a few frames ahead), along the outlines, out of a wall
    if (has_outline) {
        vec2 od;
        float ahead = 4.0;
        float da = wall_distance(me.pos + me.vel * ahead, od);
        vec2 od_here;
        float dh = wall_distance(me.pos, od_here);
        if (use_mask) {
            float prox = clamp(1.0 - da / max(avoid_distance, 1.0), 0.0, 2.0);
            if (prox > 0.0) {
                vec2 tg = vec2(-od.y, od.x);
                if (dot(tg, me.vel) < 0.0) tg = -tg;
                acc += (od * 0.7 + tg * 0.6) * prox * prox * avoid * 0.04;
            }
            if (dh < 0.0) {
                acc += od_here * avoid * 0.1;
                if (dh < -6.0 * px) me.alive = false;     // deep in a wall (the mask moved): gone
            }
        }
        float ea = edge_attract;
        if (pulse_action == 2) ea += pulse * 2.0;
        if (ea > 0.0) {
            float off = dh - edge_offset;
            acc -= od_here * clamp(off / (6.0 * px), -1.0, 1.0) * ea * 0.03;
            vec2 tg = vec2(-od_here.y, od_here.x);
            acc += tg * edge_flow * ea * 0.02 * exp(-abs(off) / (8.0 * px));
        }
        if (pulse_action == 1 && pulse > 0.0) acc += od_here * pulse * 0.08 * exp(-max(dh, 0.0) / (30.0 * px));
    }

    // the target
    if (attract > 0.0) {
        vec2 t = target * gridF - me.pos;
        float tl = length(t);
        if (tl > 1e-3) acc += t / tl * attract * 0.02 * min(tl / 8.0, 1.0);
    }
    // the edges of the picture
    if (borders == 1) {
        float m = 4.0;
        acc.x += (smoothstep(m, 0.0, me.pos.x) - smoothstep(gridF.x - m, gridF.x, me.pos.x)) * 0.05;
        acc.y += (smoothstep(m, 0.0, me.pos.y) - smoothstep(gridF.y - m, gridF.y, me.pos.y)) * 0.05;
    }

    vec2 v = me.vel + acc;
    if (pulse_action == 3 && pl.z > 0.5) v = -v;
    float vmax = min(speed * (pulse_action == 4 ? 1.0 + pulse : 1.0), SW_VMAX);
    float sp = length(v);
    float vmin = speed * min_speed;
    if (sp < 1e-5) v = vec2(vmin, 0.0);
    else if (sp > vmax) v *= vmax / sp;
    else if (sp < vmin) v *= vmin / sp;
    if (pulse_action == 0 && pl.z > 0.5 && count > 0.0) {
        // scatter: a kick away from the neighbours
        vec2 away = -(sum_p / count);
        float al = length(away);
        if (al > 1e-3) v = normalize(v + away / al * 0.9) * vmax;
    }
    me.vel = v;
    me.pos += v;
    if (borders == 0) me.pos = mod(me.pos, gridF);
    if (isnan(me.pos.x) || isnan(me.pos.y) || isnan(v.x) || isnan(v.y)) me.alive = false;
    fragColor = sw_encode(me);
}
