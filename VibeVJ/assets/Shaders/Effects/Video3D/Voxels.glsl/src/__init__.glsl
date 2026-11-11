//@settings dtype=float32 format=rgba
// --- Voxels: a video as a city of lit blocks, extruded by its brightness (pixels as cubes) ---
// lib/common.glsl says how it works. Every pixel walks the grid of blocks along its ray (2D DDA over the cells: one
// box test a cell, at most Columns + rows cells) and lights what it hits.
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D H;
uniform sampler2D S;

float gAspect;
int gCols, gRows;
vec2 gCell;                         // the size of a cell in the world (x, z)
float gBass, gAge, gHmax;
ivec2 gHsize;

// The colour and the height of cell g (x across, y from the near edge (bottom of the picture) to the far one)
vec4 cellInfo(ivec2 g) {
    vec2 uv = vec2((float(g.x) + 0.5) / float(gCols), (float(g.y) + 0.5) / float(gRows));
    vec3 c = texelFetch(H, clamp(ivec2(uv * vec2(gHsize)), ivec2(0), gHsize - 1), 0).rgb;
    float v = pow(clamp(heightValue(c), 0.0, 1.0), height_curve);
    float h = base_height + height * v * (1.0 + bass_height * gBass);
    vec2 w = vec2(-gAspect + (float(g.x) + 0.5) * gCell.x, 1.0 - (float(g.y) + 0.5) * gCell.y);
    float r = length(w);
    float front = gAge * ripple_speed;
    h += ripple * 0.35 * exp(-pow((r - front) / 0.22, 2.0)) * exp(-gAge * 1.2);
    h += wave * 0.15 * (0.5 + 0.5 * sin(r * 5.0 - iTime * MUSIC_TAU * 0.5));
    return vec4(c, max(h, 0.0));
}

// The box of cell g with its info: min and max corner
void cellBox(ivec2 g, float h, out vec3 bmin, out vec3 bmax) {
    float inset = 0.5 * gap;
    vec2 lo = vec2(-gAspect + (float(g.x) + inset) * gCell.x, 1.0 - (float(g.y) + 1.0 - inset) * gCell.y);
    vec2 hi = vec2(-gAspect + (float(g.x) + 1.0 - inset) * gCell.x, 1.0 - (float(g.y) + inset) * gCell.y);
    float bottom = block_mode == 1 ? max(h - (hi.x - lo.x), 0.0) : 0.0;
    bmin = vec3(lo.x, bottom, lo.y);
    bmax = vec3(hi.x, h, hi.y);
}

// The ray against a box: (near, far), and the normal of the face it enters
vec2 boxHit(vec3 ro, vec3 inv, vec3 bmin, vec3 bmax, out vec3 n) {
    vec3 t0 = (bmin - ro) * inv, t1 = (bmax - ro) * inv;
    vec3 tn = min(t0, t1), tf = max(t0, t1);
    float near = max(max(tn.x, tn.y), tn.z);
    float far = min(min(tf.x, tf.y), tf.z);
    n = near == tn.x ? vec3(-sign(inv.x), 0.0, 0.0) : (near == tn.y ? vec3(0.0, -sign(inv.y), 0.0) : vec3(0.0, 0.0, -sign(inv.z)));
    return vec2(near, far);
}

// Walks the grid along the ray: the first box it hits (t, its normal, its cell, its info); false when none
bool traceGrid(vec3 ro, vec3 rd, int maxSteps, out float tHit, out vec3 nHit, out ivec2 gHit, out vec4 info) {
    tHit = 0.0;
    nHit = vec3(0.0, 1.0, 0.0);
    gHit = ivec2(0);
    info = vec4(0.0);
    rd = vec3(abs(rd.x) < 1e-6 ? 1e-6 : rd.x, abs(rd.y) < 1e-6 ? 1e-6 : rd.y, abs(rd.z) < 1e-6 ? 1e-6 : rd.z);
    vec3 inv = 1.0 / rd;
    vec3 nb;
    vec2 tb = boxHit(ro, inv, vec3(-gAspect, 0.0, -1.0), vec3(gAspect, gHmax, 1.0), nb);
    if (tb.y < max(tb.x, 0.0))
        return false;
    float t = max(tb.x, 0.0);
    vec3 p = ro + rd * (t + 1e-5);
    // cell coordinates: x across from the left, y from the near edge (z = 1) to the far one (z = -1)
    vec2 gp = vec2((p.x + gAspect) / gCell.x, (1.0 - p.z) / gCell.y);
    ivec2 g = clamp(ivec2(floor(gp)), ivec2(0), ivec2(gCols - 1, gRows - 1));
    ivec2 stp = ivec2(rd.x > 0.0 ? 1 : -1, rd.z < 0.0 ? 1 : -1);
    vec2 tDelta = abs(gCell / rd.xz);
    float bx = -gAspect + float(g.x + (stp.x > 0 ? 1 : 0)) * gCell.x;
    float bz = 1.0 - float(g.y + (stp.y > 0 ? 1 : 0)) * gCell.y;
    vec2 tMax = vec2((bx - ro.x) * inv.x, (bz - ro.z) * inv.z);
    for (int i = 0; i < maxSteps; i++) {
        vec4 ci = cellInfo(g);
        vec3 bmin, bmax, n;
        cellBox(g, ci.w, bmin, bmax);
        vec2 h = boxHit(ro, inv, bmin, bmax, n);
        if (h.x <= h.y && h.y > 0.0 && ci.w > 0.0) {
            tHit = max(h.x, 0.0);
            nHit = n;
            gHit = g;
            info = ci;
            return true;
        }
        if (tMax.x < tMax.y) {
            t = tMax.x;
            tMax.x += tDelta.x;
            g.x += stp.x;
        } else {
            t = tMax.y;
            tMax.y += tDelta.y;
            g.y += stp.y;
        }
        if (g.x < 0 || g.y < 0 || g.x >= gCols || g.y >= gRows || t > tb.y)
            break;
    }
    return false;
}

vec3 toLinear(vec3 c) { return pow(max(c, vec3(0.0)), vec3(2.2)); }

// The colour of one ray (linear), alpha 1 where it hits something
vec4 shade(vec3 ro, vec3 rd, vec3 sun) {
    float t;
    vec3 n;
    ivec2 g;
    vec4 info;
    int steps = gCols + gRows + 2;
    bool hit = traceGrid(ro, rd, steps, t, n, g, info);
    vec3 p;
    vec3 col;
    if (!hit) {
        // the ground in the gaps and around the blocks inside the grid
        if (rd.y >= 0.0)
            return vec4(0.0);
        float tf = -ro.y / rd.y;
        p = ro + rd * tf;
        if (abs(p.x) > gAspect || abs(p.z) > 1.0)
            return vec4(0.0);
        float sh = 1.0;
        if (quality >= 2) {
            float ts;
            vec3 ns;
            ivec2 gs;
            vec4 is;
            if (traceGrid(p + vec3(0.0, 1e-3, 0.0), sun, steps, ts, ns, gs, is))
                sh = 0.0;
        }
        col = toLinear(floor_color) * (ambient + sun_strength * max(sun.y, 0.0) * sh);
        return vec4(col, 1.0);
    }
    p = ro + rd * t;
    vec3 bmin, bmax;
    cellBox(g, info.w, bmin, bmax);
    vec3 center = 0.5 * (bmin + bmax), half_ = 0.5 * (bmax - bmin);
    vec3 q = p - center;
    // bevel: the normal of a rounded box (the shape stays square, the light rounds the edges)
    float r = min(bevel * gCell.x * 0.5, 0.95 * min(half_.x, min(half_.y, half_.z)));
    vec3 e = max(abs(q) - (half_ - r), 0.0);
    vec3 nb = length(e) > 1e-6 ? normalize(sign(q) * e) : n;
    if (r > 1e-5)
        n = normalize(mix(n, nb, 0.85));

    vec3 c = info.rgb;
    float l = lumaOf(c);
    vec3 albedo = toLinear(clamp(mix(vec3(l), c, saturation_boost), 0.0, 1.0));
    bool top = n.y > 0.7;
    if (!top)
        albedo *= 1.0 - side_shade;
    float sh = 1.0;
    float ndl = dot(n, sun);
    if (quality >= 2 && ndl > 0.0) {
        float ts;
        vec3 ns;
        ivec2 gs;
        vec4 is;
        if (traceGrid(p + n * 2e-3, sun, steps, ts, ns, gs, is))
            sh = 0.0;
    }
    // sides darker near the ground (the light that does not reach between the blocks)
    float ao = top ? 1.0 : mix(0.35, 1.0, smoothstep(0.0, 0.35, p.y - bmin.y));
    vec3 sunc = vec3(1.0, 0.95, 0.86);
    vec3 skyc = vec3(0.55, 0.65, 0.85);
    col = albedo * (sun_strength * max(ndl, 0.0) * sh * sunc + ambient * (0.55 + 0.45 * n.y) * ao * skyc);
    vec3 hv = normalize(sun - rd);
    col += specular * sh * pow(max(dot(n, hv), 0.0), 48.0) * sunc * (top ? 1.0 : 0.5);
    col += emission * albedo * 0.5;
    // light lines along the edges of the face
    if (edge_glow > 0.0) {
        vec3 a = abs(q) / max(half_, vec3(1e-5));
        vec3 m = abs(n);
        float d = m.x > 0.5 ? max(a.y, a.z) : (m.y > 0.5 ? max(a.x, a.z) : max(a.x, a.y));
        col += edge_glow * smoothstep(0.82, 1.0, d) * (albedo * 2.0 + vec3(0.08, 0.1, 0.14));
    }
    return vec4(col, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    gAspect = iResolution.x / iResolution.y;
    gCols = max(columns, 1);
    gRows = max(int(float(gCols) / gAspect + 0.5), 1);
    gCell = vec2(2.0 * gAspect / float(gCols), 2.0 / float(gRows));
    gHsize = textureSize(H, 0);
    vec4 lv = musicLevels(S);
    vec4 hit = musicHit(S);
    gBass = lv.x;
    gAge = hit.y;
    gHmax = base_height + height * (1.0 + bass_height * gBass) + ripple * 0.35 + wave * 0.15 + 0.01;

    // the camera orbits the middle of the picture
    float tb = iTime / 16.0;
    float yaw = radians(camera_turn + camera_sway * sin(MUSIC_TAU * tb)) + MUSIC_TAU * camera_orbit * tb;
    float el = radians(camera_tilt);
    vec3 target = vec3(0.0, 0.3 * height, 0.0);
    vec3 ro = target + camera_distance * vec3(cos(el) * sin(yaw), sin(el), cos(el) * cos(yaw));
    vec3 fw = normalize(target - ro);
    vec3 right = normalize(cross(fw, vec3(0.0, 1.0, 0.0)));
    vec3 up = cross(right, fw);
    float f = zoom * camera_distance * 0.92;
    float sa = radians(sun_angle), se = radians(sun_height);
    vec3 sun = normalize(vec3(cos(se) * sin(sa), sin(se), cos(se) * cos(sa)));

    int aa = quality >= 3 ? 2 : 1;
    vec4 acc = vec4(0.0);
    for (int sy = 0; sy < 2; sy++) {
        for (int sx = 0; sx < 2; sx++) {
            if (sx >= aa || sy >= aa)
                continue;
            vec2 o = aa == 1 ? vec2(0.5) : (vec2(sx, sy) + 0.5) / float(aa);
            vec2 s = (2.0 * (floor(fragCoord) + o) - iResolution.xy) / iResolution.y;
            vec3 rd = normalize(fw * f + right * s.x + up * s.y);
            vec4 c = shade(ro, rd, sun);
            c.rgb = 1.0 - exp(-c.rgb * exposure);
            acc += c;
        }
    }
    acc /= float(aa * aa);
    vec3 col = pow(acc.rgb, vec3(1.0 / 2.2));
    if (background_mode == 1) {
        fragColor = vec4(col, acc.a);
        return;
    }
    vec3 bg = background_mode == 2 ? texture(input, uv).rgb : background_color;
    fragColor = vec4(mix(bg, col, acc.a), 1.0);
}
