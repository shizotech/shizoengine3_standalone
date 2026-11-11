//@settings dtype=float32 format=rgba rendersize=(35,12)
// --- MaskLightning, pass L: the arcs. Row i is arc i (0..5 the main arcs, 6..11 a side arc of each), texel 0..32 its
// points (pixels of the picture, by midpoint displacement: every level halves the pieces and moves their middles
// sideways, kept out of the objects), texel 33 the box around it, texel 34 (brightness, 1 for a side arc, 1 if it
// exists, 1 for a strike). The ends come from the outlines of the mask (passes E, J1..J10) ---
#include lib/common.glsl

uniform sampler2D M;
uniform sampler2D J10;
uniform sampler2D T;

vec2 sdf_normal(vec2 p) {
    vec2 s;
    float e = 3.0;
    vec2 g = vec2(lt_sdf(J10, M, p + vec2(e, 0.0), s) - lt_sdf(J10, M, p - vec2(e, 0.0), s),
                  lt_sdf(J10, M, p + vec2(0.0, e), s) - lt_sdf(J10, M, p - vec2(0.0, e), s));
    float l = length(g);
    return l > 1e-5 ? g / l : vec2(0.0, 1.0);
}

// March from p along dir until a surface, the frame or max length; what: 0 nothing, 1 a surface, 2 the frame
vec2 march(vec2 p, vec2 dir, float maxl, bool use_mask, out int what) {
    float t = 0.0;
    what = 0;
    vec2 s;
    for (int i = 0; i < 80; i++) {
        vec2 q = p + dir * t;
        float dfr = min(min(q.x, g_full.x - q.x), min(q.y, g_full.y - q.y));
        if (dfr < 0.5) { what = 2; break; }
        float d = use_mask ? lt_sdf(J10, M, q, s) : 1e5;
        if (d < 0.6) { what = 1; break; }
        t += max(min(d, dfr) * 0.9, 1.0);
        if (t > maxl) { t = maxl; break; }
    }
    return p + dir * t;
}

float rnd(uint a, uint b, uint c) { return mp_rand(mp_hash(a * 2654435761u ^ mp_hash(b * 40503u + c * 7919u))); }

// The two ends of main arc i of strike k; false if it found none
bool arc_ends(int i, uint k, out vec2 A, out vec2 B) {
    bool use_mask = mp_mask_mode() != 4;
    uint ii = uint(i);
    for (int tr = 0; tr < 4; tr++) {
        uint tt = uint(tr);
        float r1 = rnd(k, ii * 8u + tt, 1u);
        float r2 = rnd(k, ii * 8u + tt, 2u);
        float r3 = rnd(k, ii * 8u + tt, 3u);
        if (arc_mode == 4 || (!use_mask && arc_mode != 1)) {
            A = point_a * g_full + (vec2(r1, r2) - 0.5) * 12.0;
            B = point_b * g_full + (vec2(r2, r3) - 0.5) * 12.0;
            if (!use_mask && arc_mode != 4) {
                A = vec2(r1, r2) * g_full;
                B = A + vec2(cos(r3 * MP_TAU), sin(r3 * MP_TAU)) * max_length * 0.5;
                B = clamp(B, vec2(1.0), g_full - 1.0);
            }
            return true;
        }
        if (arc_mode == 1) {
            // from the top down onto the first surface below
            A = vec2(r1 * g_full.x, g_full.y - 1.0);
            float a = radians(-90.0 + (r2 - 0.5) * 30.0);
            int what;
            B = march(A, vec2(cos(a), sin(a)), g_full.y * 1.5, use_mask, what);
            return true;
        }
        // a point on an outline
        vec2 s;
        lt_sdf(J10, M, vec2(r1, r2) * g_full, s);
        A = s;
        vec2 n = sdf_normal(A);
        if (arc_mode == 3) {
            // crawl: the next point along the outline
            vec2 tg = vec2(-n.y, n.x) * (r3 < 0.5 ? 1.0 : -1.0);
            vec2 far = A + tg * max_length * (0.15 + 0.2 * r3) + n * 20.0;
            lt_sdf(J10, M, far, s);
            B = s;
            if (length(B - A) > 20.0) return true;
            continue;
        }
        float a = atan(n.y, n.x) + radians((r3 - 0.5) * 2.0 * spread);
        vec2 dir = vec2(cos(a), sin(a));
        int what;
        B = march(A + n * 3.0, dir, max_length, true, what);
        if (arc_mode == 2) {
            if (what != 1) return true;           // reached the frame (or far enough)
            continue;
        }
        if (what == 1 && length(B - A) > 24.0) return true;
    }
    return false;
}

// Point v (0..32) of an arc from A to B, path seed ps
vec2 arc_point(vec2 A, vec2 B, uint ps, int v, bool keep_out, bool crawl) {
    vec2 a = A;
    vec2 b = B;
    int lo = 0;
    int hi = 32;
    for (int lvl = 0; lvl < 5; lvl++) {
        int mid = (lo + hi) / 2;
        vec2 ab = b - a;
        float len = length(ab);
        vec2 perp = len > 1e-4 ? vec2(-ab.y, ab.x) / len : vec2(0.0, 1.0);
        float off = (rnd(ps, uint(mid), uint(lvl) + 11u) - 0.5) * 2.0 * roughness * len * 0.42;
        vec2 m = (a + b) * 0.5 + perp * off;
        if (keep_out || crawl) {
            vec2 s;
            float d = lt_sdf(J10, M, m, s);
            if (crawl) {
                // stay near the outline, a little outside
                vec2 out_dir = d > 0.0 ? normalize(m - s + 1e-4) : normalize(s - m + 1e-4);
                m = s + out_dir * (2.0 + abs(off) * 0.3);
            } else if (d < 2.0) {
                vec2 nn = sdf_normal(m);
                m += nn * (2.0 - d);
            }
        }
        if (v == mid) return m;
        if (v < mid) { b = m; hi = mid; }
        else { a = m; lo = mid; }
    }
    return v <= lo ? a : b;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    g_full = vec2(textureSize(M, 0)) / 0.5;
    int col = int(fragCoord.x);
    int row = int(fragCoord.y);
    bool side = row >= 6;
    int main_i = side ? row - 6 : row;
    if (main_i >= clamp(arcs, 1, 6)) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 pl = mp_pulse(T);
    // strikes at the pulses, continuous arcs between them
    float strike = (timing == 0 || timing == 2) ? pow(pl.x, 0.6) : 0.0;
    float cont = (timing == 1 || timing == 2) ? continuous_level : 0.0;
    bool use_strike = strike > cont;
    uint frame = uint(max(iFrame, 0));
    uint k = use_strike ? uint(pl.y) * 977u + 13u : (frame / uint(max(hold, 1))) * 31u + 7u;
    float bright = use_strike ? strike : cont;
    // flicker: a strike flashes again a few times as it fades
    float fl = rnd(frame / 2u, uint(main_i), 77u);
    bright *= use_strike ? (0.55 + 0.45 * step(0.3, fl)) : (0.6 + 0.4 * fl);

    vec2 A;
    vec2 B;
    bool ok = arc_ends(main_i, k, A, B);
    if (!ok || bright < 0.005) {
        fragColor = vec4(0.0);
        return;
    }
    float cr = clamp(crackle, 0.0, 1.0);
    uint pstep = cr > 0.0 ? uint(1.0 / max(cr * cr, 0.01)) : 100000u;
    uint ps = k * 101u + frame / max(pstep, 1u) * 7u + uint(main_i) * 13u;
    bool keep_out = mp_mask_mode() != 4 && arc_mode != 3;
    bool crawl = arc_mode == 3 && mp_mask_mode() != 4;

    if (side) {
        // a side arc from a point of the main arc, off at an angle, shorter, free at its end
        float has = step(rnd(k, uint(main_i), 91u), branches);
        if (has < 0.5) {
            fragColor = vec4(0.0);
            return;
        }
        int at = 8 + int(rnd(ps, uint(main_i), 92u) * 16.0);
        vec2 S = arc_point(A, B, ps, at, keep_out, crawl);
        vec2 ab = B - A;
        float ang = atan(ab.y, ab.x) + (rnd(ps, uint(main_i), 93u) < 0.5 ? 1.0 : -1.0) * radians(25.0 + 35.0 * rnd(ps, uint(main_i), 94u));
        float len = length(ab) * (0.2 + 0.3 * rnd(ps, uint(main_i), 95u));
        int what;
        vec2 E = march(S, vec2(cos(ang), sin(ang)), len, mp_mask_mode() != 4, what);
        A = S;
        B = E;
        ps += 5003u;
        bright *= 0.6;
    }
    if (col <= 32) {
        fragColor = vec4(arc_point(A, B, ps, col, keep_out, crawl), 0.0, 1.0);
    } else if (col == 33) {
        vec2 lo = min(A, B);
        vec2 hi = max(A, B);
        for (int v = 1; v < 32; v++) {
            vec2 p = arc_point(A, B, ps, v, keep_out, crawl);
            lo = min(lo, p);
            hi = max(hi, p);
        }
        fragColor = vec4(lo, hi);
    } else {
        fragColor = vec4(bright, side ? 1.0 : 0.0, 1.0, use_strike ? 1.0 : 0.0);
    }
}
