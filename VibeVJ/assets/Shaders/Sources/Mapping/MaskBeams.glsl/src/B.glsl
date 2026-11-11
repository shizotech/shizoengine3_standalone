//@settings dtype=float32 format=rgba rendersize=(8,48)
// --- MaskBeams, pass B: the paths of the beams. Texel (k, r) traces ray r through the distance field of the mask
// (sphere tracing on the jump flood of passes E, J1..J10) and gives out its segment k: rows 0..23 the start and the end
// (pixels of the picture), rows 24..47 (power at the start, what ends it, 1 if it exists). Mirrors reflect, glass
// bends (Snell, total internal reflection), absorbers stop the beam ---
#include lib/common.glsl

uniform sampler2D M;
uniform sampler2D J10;
uniform sampler2D T;

vec2 g_full;    // the size of the picture in pixels

// The signed distance (pixels, negative inside the white shapes) at p (pixels of the picture)
float sdf(vec2 p) {
    vec2 jres = vec2(textureSize(J10, 0));
    vec2 q = p * jres / g_full;
    ivec2 c = ivec2(floor(q));
    ivec2 hi = ivec2(jres) - 1;
    float bd = 1e20;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec4 v = texelFetch(J10, clamp(c + ivec2(x, y), ivec2(0), hi), 0);
            if (v.w < 0.5) continue;
            vec2 e = v.xy - q;
            bd = min(bd, dot(e, e));
        }
    }
    float d = bd > 1e19 ? 1e5 : sqrt(bd) * g_full.x / jres.x;
    float inside = mp_bilinear_uv(M, p / g_full).r;
    return inside > 0.5 ? -d : d;
}

vec2 sdf_normal(vec2 p) {
    float e = 3.0;
    vec2 g = vec2(sdf(p + vec2(e, 0.0)) - sdf(p - vec2(e, 0.0)), sdf(p + vec2(0.0, e)) - sdf(p - vec2(0.0, e)));
    float l = length(g);
    return l > 1e-5 ? g / l : vec2(0.0, 1.0);
}

// Where beam b starts (pixels) and its angle (radians)
void emitter(int b, out vec2 pos, out float ang) {
    float n = float(clamp(beams, 1, 8));
    float fb = float(b);
    float base = 90.0;
    vec2 uv = vec2(0.5);
    float spread = n > 1.0 ? fb / (n - 1.0) - 0.5 : 0.0;
    if (emitter_layout == 0) { uv = vec2((fb + 0.5) / n, 0.01); base = 90.0; }
    else if (emitter_layout == 1) { uv = vec2((fb + 0.5) / n, 0.99); base = -90.0; }
    else if (emitter_layout == 2) {
        float k = floor(fb / 2.0);
        float m = ceil(n / 2.0);
        bool left = b % 2 == 0;
        uv = vec2(left ? 0.01 : 0.99, (k + 0.5) / m);
        base = left ? 0.0 : 180.0;
    } else if (emitter_layout == 3) {
        int k = b % 4;
        uv = k == 0 ? vec2(0.01, 0.01) : (k == 1 ? vec2(0.99, 0.01) : (k == 2 ? vec2(0.99, 0.99) : vec2(0.01, 0.99)));
        base = 45.0 + 90.0 * float(k) + float(b / 4) * 12.0;
    } else if (emitter_layout == 4) {
        base = 90.0 + (fan >= 359.0 ? fb / n * 360.0 : spread * fan);
    } else {
        uv = point_a;
        base = 90.0 + spread * fan;
    }
    float a = base + aim;
    vec3 pl = mp_pulse(T);
    float ph = fb * sweep_phase;
    if (motion == 1) a += 0.5 * sweep_range * sin(MP_TAU * (iTime * sweep_speed - ph));
    else if (motion == 2) a += 360.0 * (iTime * sweep_speed - ph) * (b % 2 == 0 ? 1.0 : -1.0);
    else if (motion == 3) a += (mp_rand3(ivec3(int(pl.y), b, 7)) - 0.5) * sweep_range;
    else if (motion == 4) a += (mp_vnoise(vec2(fb * 5.3, iTime * sweep_speed * 2.0)) - 0.5) * sweep_range;
    pos = uv * g_full;
    ang = radians(a);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    g_full = vec2(textureSize(M, 0)) / 0.5;
    int k = int(fragCoord.x);
    int row = int(fragCoord.y);
    bool info = row >= 24;
    int ray = info ? row - 24 : row;
    if (ray >= bm_rays() || k > bounces) {
        fragColor = vec4(0.0);
        return;
    }
    int b = bm_beam_of(ray);
    vec2 pos;
    float ang;
    emitter(b, pos, ang);
    vec2 dir = vec2(cos(ang), sin(ang));
    float ior = glass_index;
    if (dispersion > 0.0) ior += (float(ray % 3) - 1.0) * dispersion * 0.5;
    bool no_mask = mp_mask_mode() == 4;
    bool inside = !no_mask && sdf(pos) < 0.0;
    float power = 1.0;
    float maxlen = length(g_full) * 1.5;
    vec4 seg = vec4(pos, pos);
    vec4 inf = vec4(0.0);
    for (int s = 0; s <= 7; s++) {
        if (s > k) break;
        // march to the next surface or the edge of the picture
        float t = 0.0;
        int what = 0;     // 0 nothing (too far), 1 the mask, 2 the frame
        for (int i = 0; i < 120; i++) {
            vec2 p = pos + dir * t;
            float dfr = min(min(p.x, g_full.x - p.x), min(p.y, g_full.y - p.y));
            float d = no_mask ? 1e5 : sdf(p);
            if (inside) d = -d;
            if (dfr < 0.5) { what = 2; break; }
            if (d < 0.6) { what = 1; break; }
            t += max(min(d, dfr) * 0.9, 0.8);
            if (t > maxlen) break;
        }
        vec2 end = pos + dir * t;
        int ends = what == 0 ? 0 : (what == 2 ? (frame_edges == 0 ? 4 : 0) : (surfaces == 0 ? 1 : (surfaces == 1 ? 2 : 3)));
        if (s == k) {
            seg = vec4(pos, end);
            inf = vec4(power, float(ends), 1.0, 0.0);
            break;
        }
        // what happens at the end of the segment
        if (ends == 0 || ends == 3 || power < 0.01) { power = 0.0; break; }
        if (ends == 4) {
            vec2 n = abs(end.x) < 1.0 || abs(end.x - g_full.x) < 1.0 ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
            dir = reflect(dir, n);
            power *= reflectivity;
            pos = clamp(end, vec2(1.0), g_full - 1.0);
            continue;
        }
        vec2 nout = sdf_normal(end);
        if (ends == 1) {
            dir = reflect(dir, nout);
            power *= reflectivity;
            pos = end + nout * 1.5;
        } else {
            // glass: into it or out of it, bent by Snell's law; total internal reflection stays inside
            vec2 nn = inside ? -nout : nout;            // faces against the beam
            float eta = inside ? ior : 1.0 / ior;
            vec2 r = refract(dir, nn, eta);
            if (dot(r, r) < 1e-6) {
                dir = reflect(dir, nn);
                pos = end + nn * 1.5;
            } else {
                dir = normalize(r);
                inside = !inside;
                pos = end - nn * 1.5;
                power *= 0.96;
            }
        }
    }
    if (info) {
        fragColor = power <= 0.0 ? vec4(0.0) : inf;
    } else {
        fragColor = power <= 0.0 ? vec4(0.0) : seg;
    }
}
