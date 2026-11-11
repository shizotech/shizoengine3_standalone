//@settings dtype=float16 format=rgba
// --- pass A: the ferrofluid, its dish or floor and the studio in linear light; alpha is the cover of the blob ---
#include lib/common.glsl

uniform sampler2D S;

//@enum options=(Floating ball, Dish) value=0
uniform int form;                   // Dish: a puddle in a black glass dish with the magnet under it
//@slider min=0.4 max=2.0 value=1.0
uniform float size;
//@int min=40 max=400 value=160
uniform int spikes;                 // how many spikes on the ball (Dish: the spacing follows it)
//@slider min=0.0 max=1.0 value=0.12
uniform float field;                // the magnetic field without music: the spikes at rest
//@slider min=0.0 max=1.5 value=0.55
uniform float spike_height;         // how tall the spikes get at a full field, part of the size
//@slider min=0.6 max=3.0 value=1.5
uniform float sharpness;            // the shape of the spikes: low round humps, high thin needles
//@slider min=0.0 max=1.0 value=0.6
uniform float field_direction;      // 0: spikes all around alike, 1: tallest at the top and bottom (a magnet below)
//@slider min=0.0 max=1.0 value=0.4
uniform float ripples;              // the highs run ripples over the surface
//@slider min=0.0 max=1.0 value=0.35
uniform float wobble;               // the blob sways and breathes (more with the mids)
//@slider min=-2.0 max=2.0 value=0.15
uniform float spin;                 // turns per 16 beats

//@rgb value=(0.01, 0.01, 0.012)
uniform vec3 fluid_color;           // nearly black
//@slider min=0.0 max=0.5 value=0.04
uniform float roughness;
//@slider min=0.0 max=1.0 value=0.35
uniform float oil_sheen;            // the rainbow of a thin oil film in the reflections
//@slider min=200.0 max=900.0 value=420.0
uniform float film_thickness;       // nanometres: changes the colours of the sheen
//@rgb value=(1.0, 0.72, 0.5)
uniform vec3 key_color;
//@rgb value=(0.3, 0.6, 1.0)
uniform vec3 rim_color;
//@slider min=0.0 max=10.0 value=3.0
uniform float light_intensity;
//@slider min=0.0 max=360.0 value=40.0
uniform float light_angle;
//@enum options=(Studio, Neon, Dark) value=0
uniform int environment;
//@slider min=0.0 max=4.0 value=1.0
uniform float environment_brightness;
//@slider min=0.0 max=1.0 value=0.5
uniform float floor_reflection;     // Floating ball: a black glossy floor under it; 0: none

//@slider min=2.0 max=12.0 value=4.2
uniform float camera_distance;
//@slider min=-20.0 max=85.0 value=14.0
uniform float camera_height;
//@slider min=0.0 max=360.0 value=30.0
uniform float camera_angle;
//@slider min=-1.0 max=1.0 value=0.05
uniform float camera_orbit;         // turns per 16 beats
//@slider min=0.8 max=5.0 value=2.0
uniform float zoom;
//@slider min=0.0 max=1.0 value=0.15
uniform float camera_shake;
//@enum options=(Final, Normals, Steps, Spikes) value=0
uniform int debug_mode;

// ---- set once a pixel ----
float fieldNow;         // 0 .. ~1.5: how strong the field is now
float rippleAmp;
float wobbleAmp;
float shatter;
float shatterSeed;
mat3 blobRot;
float floorY;
float tNow;
float envLights = 1.0;   // the lights of the studio seen straight (dimmed) or in reflections (full)

const float PHI = 1.61803398875;

// The point of a spherical Fibonacci set of n points nearest to the unit vector p: (its index, chord distance).
// After Keinert et al., "Spherical Fibonacci Mapping" (2015): the lattice is read in the (phi, cos theta) plane,
// where the neighbours of a point are found from two Fibonacci numbers, and four candidates are compared.
vec2 fibonacciNearest(vec3 p, float n) {
    float phi = min(atan(p.y, p.x), 3.14159265);
    float z = clamp(p.z, -1.0, 1.0);
    float k = max(2.0, floor(log(n * 3.14159265 * sqrt(5.0) * (1.0 - z * z)) / log(PHI * PHI)));
    float fk = pow(PHI, k) / sqrt(5.0);
    vec2 fib = vec2(floor(fk + 0.5), floor(fk * PHI + 0.5));
    vec2 ka = 2.0 * fib / n;
    vec2 kb = 6.2831853 * (fract((fib + 1.0) * PHI) - (PHI - 1.0));
    mat2 inv = mat2(ka.y, -ka.x, kb.y, -kb.x) / (ka.y * kb.x - ka.x * kb.y);
    vec2 cell = floor(inv * vec2(phi, z - (1.0 - 1.0 / n)));
    float best = 8.0, idx = 0.0;
    for (int s = 0; s < 4; s++) {
        vec2 o = vec2(float(s & 1), float(s >> 1));
        float i = clamp(dot(fib, o + cell), 0.0, n - 1.0);
        float ph = 6.2831853 * fract(i * PHI);
        float cz = 1.0 - (2.0 * i + 1.0) / n;
        float sz = sqrt(max(1.0 - cz * cz, 0.0));
        vec3 q = vec3(cos(ph) * sz, sin(ph) * sz, cz);
        float d2 = dot(q - p, q - p);
        if (d2 < best) {
            best = d2;
            idx = i;
        }
    }
    return vec2(idx, sqrt(best));
}

// The profile of one spike: x = distance from its axis / its base radius; (height, slope) for the step size
vec2 spikeProfile(float x, float h) {
    float k = sharpness;
    float u = max(1.0 - x, 0.0);
    float f = h * pow(u, k);
    float slope = h * k * pow(max(u, 0.05), k - 1.0);
    return vec2(f, slope);
}

// The blob: distance (scaled down where it is steep, so the march does not step through spikes) and the spike mask
vec2 blob(vec3 p) {
    if (form == 1) {
        // a puddle on the dish floor, a dome with spikes on a hexagonal grid
        float R = 1.25 * size;
        vec2 xz = p.xz;
        float r = length(xz);
        float sr = smoothstep(0.0, R, r);
        float domeH = 0.32 * size * (1.0 - sr * sr);
        float edge = smoothstep(R, R * 0.6, r);
        float spacing = size * 2.2 / sqrt(float(max(spikes, 4)) * 0.25);
        vec2 g = xz / spacing;
        // two rectangular grids offset by half: the nearer centre of both is the hexagonal grid
        vec2 r1 = vec2(1.0, 1.7320508);
        vec2 a = mod(g, r1) - r1 * 0.5;
        vec2 b = mod(g - r1 * 0.5, r1) - r1 * 0.5;
        vec2 gv = dot(a, a) < dot(b, b) ? a : b;
        vec2 id = g - gv;
        float x = length(gv) / 0.55;
        float hv = 0.75 + 0.5 * hash12(floor(id * 2.0 + 0.5));
        float hc = spike_height * size * 0.8 * fieldNow * hv * edge * (0.55 + 0.45 * field_direction * (1.0 - r / R));
        vec2 sp = spikeProfile(x, hc);
        float rip = rippleAmp * 0.012 * size * sin(r * 30.0 / size - tNow * 9.0) * edge;
        float surf = floorY + 0.03 * size + domeH * (0.6 + 0.4 * fieldNow) + sp.x + rip;
        float slope = sp.y / (spacing * 0.55) + domeH / R * 2.0;
        float d = (p.y - surf) / sqrt(1.0 + slope * slope);
        // outside the puddle: the fluid ends at its rim
        d = max(max(d, r - R * 1.02), floorY - p.y);
        return vec2(d, sp.x / max(hc, 1e-3));
    }
    vec3 q = blobRot * p;
    float r = length(q);
    vec3 dir = q / max(r, 1e-4);
    float R = size;
    // the blob breathes and sways: slow, smooth noise
    float wob = wobbleAmp * 0.1 * size * gradientNoise(dir * 1.6 + vec3(0.0, tNow * 0.35, 0.0));
    vec2 nf = fibonacciNearest(dir, float(spikes));
    float spacing = 3.5449 / sqrt(float(spikes));
    float x = nf.y / (spacing * 0.56);
    float hv = 0.8 + 0.4 * hash11(nf.x);
    float axial = mix(1.0, 0.45 + 0.75 * abs(dir.y), field_direction);
    float h = spike_height * size * 0.5 * fieldNow * hv * axial;
    vec2 sp = spikeProfile(x, h);
    float rip = rippleAmp * 0.01 * size * sin(dot(dir, vec3(0.6, 0.8, 0.0)) * 22.0 - tNow * 10.0)
                * sin(dot(dir, vec3(-0.7, 0.2, 0.68)) * 17.0 + tNow * 7.0);
    float surf = R + wob + sp.x + rip;
    float slope = sp.y / (spacing * 0.56 * R);
    return vec2((r - surf) / sqrt(1.0 + slope * slope), sp.x / max(h, 1e-3));
}

float shattered(vec3 p) {
    if (shatter <= 0.001)
        return blob(p).x;
    float c = size * 0.38;
    vec3 id = floor(p / c);
    vec3 ctr = (id + 0.5) * c;
    vec3 h = hash33(id + floor(shatterSeed * 97.0));
    vec3 off = (h - 0.5) * c * 0.5 * shatter;
    float gap = 1.0 - 0.3 * shatter * (0.5 + h.x);
    float d = max(blob(p - off).x, sdBox(p - ctr - off, vec3(c * 0.5 * gap)));
    vec3 toBorder = c * 0.5 - abs(p - ctr);
    return min(d, max(min(min(toBorder.x, toBorder.y), toBorder.z), 0.0) + c * 0.02);
}

// The dish (Dish form): a shallow black glass bowl with a low wall
float dish(vec3 p) {
    float R = 1.6 * size;
    vec3 q = p - vec3(0.0, floorY, 0.0);
    float rr = length(q.xz);
    float wall = max(abs(rr - R) - 0.03 * size, abs(q.y - 0.06 * size) - 0.08 * size);
    float base = max(rr - R, abs(q.y + 0.02 * size) - 0.02 * size);
    return min(wall, base);
}

float map(vec3 p) {
    return shattered(p);
}

vec2 march(vec3 ro, vec3 rd, float tmin, float tmax, int steps, float stepScale) {
    float t = tmin;
    for (int i = 0; i < 160; i++) {
        if (i >= steps)
            break;
        float d = map(ro + rd * t);
        if (abs(d) < 0.0004 * t + 0.0004)
            return vec2(t, float(i));
        t += d * stepScale;
        if (t > tmax)
            break;
    }
    return vec2(-1.0, float(steps));
}

vec3 calcNormalBlob(vec3 p, float eps) {
    const vec2 k = vec2(1.0, -1.0);
    return normalize(k.xyy * map(p + k.xyy * eps) + k.yyx * map(p + k.yyx * eps)
                   + k.yxy * map(p + k.yxy * eps) + k.xxx * map(p + k.xxx * eps));
}

// ---- the studio ----
// A rectangle of light in direction c, half size in radians (about), soft edges
float softbox(vec3 d, vec3 c, vec2 halfSize, float soft) {
    vec3 up = abs(c.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
    vec3 rt = normalize(cross(up, c));
    vec3 u2 = cross(c, rt);
    float dd = dot(d, c);
    if (dd <= 0.0)
        return 0.0;
    vec2 q = vec2(dot(d, rt), dot(d, u2)) / dd;
    vec2 e = abs(q) - halfSize;
    return smoothstep(soft, -soft, max(e.x, e.y));
}

vec3 environmentColor(vec3 d) {
    vec3 kc = srgbToLinear(key_color), rc = srgbToLinear(rim_color);
    float y = d.y;
    vec3 col;
    float a = radians(light_angle);
    if (environment == 2) {
        col = vec3(0.001) + vec3(0.5) * softbox(d, vec3(0.0, 1.0, 0.0), vec2(0.4), 0.05) * envLights;
    } else if (environment == 1) {
        float az = length(d.xz) > 1e-5 ? atan(d.z, d.x) : 0.0;
        col = vec3(0.003, 0.002, 0.006);
        for (int i = 0; i < 6; i++) {
            float b = float(i) * 1.0472;
            float da = abs(mod(az - b + 3.14159265, 6.2831853) - 3.14159265);
            col += ((i % 2 == 0) ? kc : rc) * 6.0 * smoothstep(0.03, 0.015, da) * smoothstep(-0.2, -0.1, y) * smoothstep(0.7, 0.6, y) * envLights;
        }
        col += rc * 0.8 * softbox(d, vec3(0.0, 1.0, 0.0), vec2(0.6, 0.05), 0.02) * envLights;
    } else {
        // a dark grey studio: a big soft box above, a strip light in each light colour, a white fill
        col = mix(vec3(0.018, 0.018, 0.02), vec3(0.003), smoothstep(-0.2, 0.9, y));
        vec3 lights = vec3(1.0, 0.98, 0.95) * 6.0 * softbox(d, normalize(vec3(0.2, 1.0, 0.1)), vec2(0.55, 0.35), 0.06);
        lights += kc * 5.0 * softbox(d, normalize(vec3(cos(a), 0.15, sin(a))), vec2(0.06, 0.6), 0.02);
        lights += rc * 5.0 * softbox(d, normalize(vec3(-cos(a + 0.6), 0.25, -sin(a + 0.6))), vec2(0.05, 0.55), 0.02);
        lights += vec3(0.9, 0.95, 1.0) * 2.5 * softbox(d, normalize(vec3(sin(a), 0.05, -cos(a))), vec2(0.4, 0.12), 0.05);
        col += lights * envLights;
    }
    return col * environment_brightness;
}

// The colour of a thin oil film (thickness in nm, the cosine inside the film): two reflections interfere
vec3 thinFilm(float thick, float cosT) {
    vec3 lam = vec3(650.0, 540.0, 450.0);
    vec3 phase = 6.2831853 * 2.0 * 1.45 * thick * cosT / lam;
    return 0.5 + 0.5 * cos(phase);
}

vec3 shade(vec3 p, vec3 n, vec3 rd, float spikeMask, vec3 refl, float ao) {
    vec3 v = -rd;
    float NoV = max(dot(n, v), 1e-4);
    vec3 kc = srgbToLinear(key_color) * light_intensity, rc = srgbToLinear(rim_color) * light_intensity;
    float a = radians(light_angle);
    vec3 lk = normalize(vec3(cos(a), 0.6, sin(a)));
    vec3 lr = normalize(vec3(-cos(a + 0.6), 0.4, -sin(a + 0.6)));
    // the film: its thickness varies over the surface and drifts
    float th = film_thickness * (0.7 + 0.5 * gradientNoise(p * 2.2 / size + vec3(tNow * 0.15)));
    float cosT = sqrt(max(1.0 - (1.0 - NoV * NoV) / (1.45 * 1.45), 0.0));
    vec3 film = mix(vec3(1.0), thinFilm(th, cosT) * 1.5, oil_sheen * 0.7);
    vec3 f0 = vec3(0.14) * film;
    vec3 base = srgbToLinear(fluid_color);
    vec3 col = (base * max(dot(n, lk), 0.0) * kc + base * max(dot(n, lr), 0.0) * rc) * ao;
    col += specularGGX(n, v, lk, max(roughness, 0.12), f0) * kc;
    col += specularGGX(n, v, lr, max(roughness, 0.12), f0) * rc;
    col += refl * envBRDFApprox(f0, NoV, roughness) * mix(0.6, 1.0, ao) * 1.5;
    if (debug_mode == 3)
        col = vec3(spikeMask);
    return col;
}

vec3 floorColor(vec3 ro, vec3 rd, float t) {
    vec3 fp = ro + rd * t;
    vec3 r = reflect(rd, vec3(0.0, 1.0, 0.0));
    float F = fresnelSchlick(max(-rd.y, 0.0), vec3(0.04)).x;
    envLights = 0.03;
    vec3 refl = environmentColor(r);
    envLights = 1.0;
    // the blob in the floor: march it (it is near)
    vec2 h = march(fp + r * 0.01, r, 0.0, 8.0 * size, quality == 1 ? 40 : 60, 0.7);
    if (h.x > 0.0) {
        vec3 p = fp + r * (h.x + 0.01);
        vec3 n = calcNormalBlob(p, 0.002 * size);
        refl = shade(p, n, r, 0.0, environmentColor(reflect(r, n)), 1.0);
    }
    float dist = length(fp.xz);
    float occ = 1.0 - 0.7 * exp(-dist * dist / (size * size * 1.2));
    vec3 col = (refl * mix(0.03, 1.0, F) * floor_reflection * 1.5 + vec3(0.002)) * occ;
    envLights = 0.0;
    vec3 far = environmentColor(rd);
    envLights = 1.0;
    return mix(far, col, exp(-0.01 * t * t));
}

vec4 render(vec3 ro, vec3 rd, out float steps) {
    steps = 0.0;
    float bound = form == 1 ? 2.2 * size : size * (1.0 + spike_height * 0.9 + 0.15) + 0.05;
    vec3 bc = form == 1 ? vec3(0.0, floorY, 0.0) : vec3(0.0);
    vec2 bs = iSphere(ro, rd, bc, bound);
    vec2 hit = vec2(-1.0);
    float stepScale = shatter > 0.001 ? 0.5 : 0.8;
    if (bs.y > 0.0) {
        hit = march(ro, rd, max(bs.x, 0.0), bs.y, quality == 1 ? 90 : 130, stepScale);
        steps = hit.y;
    }
    // the dish (Dish form)
    float tDish = -1.0;
    if (form == 1 && bs.y > 0.0) {
        float t = max(bs.x, 0.0);
        for (int i = 0; i < 48; i++) {
            float d = dish(ro + rd * t);
            if (d < 0.001) {
                tDish = t;
                break;
            }
            t += d;
            if (t > bs.y)
                break;
        }
    }
    float tFloor = rd.y < 0.0 ? (floorY - ro.y) / rd.y : -1.0;
    bool showFloor = background_mode == 0 && (form == 1 || floor_reflection > 0.0);
    vec3 col;
    float cover = 0.0;
    if (hit.x > 0.0 && (tDish < 0.0 || hit.x < tDish)) {
        vec3 p = ro + rd * hit.x;
        vec3 n = calcNormalBlob(p, max(0.0006 * hit.x, 0.0015 * size));
        float mask = blob(p).y;
        vec3 r = reflect(rd, n);
        vec3 refl;
        float ao = 1.0;
        if (quality >= 2) {
            vec2 h2 = march(p + n * 0.006 * size, r, 0.0, 3.0 * size, 40, 0.7);
            if (h2.x > 0.0) {
                vec3 p2 = p + n * 0.006 * size + r * h2.x;
                vec3 n2 = calcNormalBlob(p2, 0.002 * size);
                refl = shade(p2, n2, r, 0.0, environmentColor(reflect(r, n2)) * 0.6, 0.6);
            } else {
                refl = environmentColor(r);
            }
            // occlusion between the spikes
            float occ = 0.0;
            for (int i = 1; i <= 4; i++) {
                float hd = 0.04 * size * float(i);
                occ += (hd - map(p + n * hd)) / hd * (1.0 / float(i));
            }
            ao = clamp(1.0 - 0.6 * occ, 0.0, 1.0);
        } else {
            refl = environmentColor(r);
            ao = mix(0.55, 1.0, mask);
        }
        if (showFloor && r.y < 0.0) {
            float fade = exp(-0.05 * dot(p.xz, p.xz));
            refl = mix(refl, refl * 0.5, fade * 0.6);
        }
        col = shade(p, n, rd, mask, refl, ao);
        if (debug_mode == 1)
            col = debugNormal(n);
        cover = 1.0;
    } else if (tDish > 0.0) {
        // black glass: it mirrors the studio
        vec3 p = ro + rd * tDish;
        const vec2 k = vec2(1.0, -1.0);
        float e = 0.002 * size;
        vec3 n = normalize(k.xyy * dish(p + k.xyy * e) + k.yyx * dish(p + k.yyx * e) + k.yxy * dish(p + k.yxy * e) + k.xxx * dish(p + k.xxx * e));
        float F = fresnelSchlick(max(dot(n, -rd), 0.0), vec3(0.04)).x;
        col = environmentColor(reflect(rd, n)) * F * 1.5 + vec3(0.003);
        cover = 1.0;
    } else if (showFloor && tFloor > 0.0) {
        col = floorColor(ro, rd, tFloor);
    } else {
        envLights = 0.0;
        col = environmentColor(rd);
        envLights = 1.0;
    }
    if (background_mode != 0)
        col *= cover;
    return vec4(col, cover);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 lv = texelFetch(S, ivec2(ST_LEVELS, 0), 0);
    vec4 bt = texelFetch(S, ivec2(ST_BEAT, 0), 0);
    vec4 sp = texelFetch(S, ivec2(ST_SPRING, 0), 0);
    float t = iTime;
    tNow = t;
    fieldNow = clamp(field + sp.x, 0.0, 1.6);
    rippleAmp = ripples * (0.15 + 1.6 * lv.z * react);
    wobbleAmp = wobble * (0.5 + 1.5 * lv.y * react);
    float g = glitchAmount(bt);
    shatter = (glitchKindFor(bt.z + floor(iTime * 2.0) * 0.37) == 4) ? g : 0.0;
    shatterSeed = fract(bt.z + floor(iTime * 4.0) * 0.1234567);
    floorY = form == 1 ? -0.45 * size : -1.75 * size;
    float yaw = t * 6.2831853 / 16.0 * spin;
    float sway = wobbleAmp * 0.12 * sin(t * 6.2831853 / 8.0);
    mat3 ry = mat3(cos(yaw), 0.0, -sin(yaw), 0.0, 1.0, 0.0, sin(yaw), 0.0, cos(yaw));
    mat3 rx = mat3(1.0, 0.0, 0.0, 0.0, cos(sway), sin(sway), 0.0, -sin(sway), cos(sway));
    blobRot = rx * ry;

    float ca = radians(camera_angle) + t * 6.2831853 / 16.0 * camera_orbit;
    float ch = radians(camera_height);
    float shake = camera_shake * 0.04;
    ca += shake * gradientNoise(vec2(t * 0.11, 1.7)) * 2.0;
    ch += shake * gradientNoise(vec2(t * 0.13, 5.3));
    vec3 ta = form == 1 ? vec3(0.0, floorY + 0.25 * size, 0.0) : vec3(0.0);
    vec3 ro = ta + camera_distance * size * vec3(cos(ch) * cos(ca), sin(ch), cos(ch) * sin(ca));
    mat3 cam = cameraMatrix(ro, ta, shake * gradientNoise(vec2(t * 0.09, 3.1)) * 0.5);

    int aa = quality >= 3 ? 2 : 1;
    vec4 acc = vec4(0.0);
    float steps = 0.0;
    for (int j = 0; j < 2; j++) {
        for (int i = 0; i < 2; i++) {
            if (i >= aa || j >= aa)
                continue;
            vec2 o = aa > 1 ? (vec2(float(i), float(j)) - 0.5) * 0.5 + vec2(0.125, -0.125) * (float(j) * 2.0 - 1.0) : vec2(0.0);
            vec2 uv = (2.0 * (fragCoord + o) - iResolution.xy) / iResolution.y;
            float st;
            acc += render(ro, cameraRay(cam, uv, zoom), st);
            steps = max(steps, st);
        }
    }
    acc /= float(aa * aa);
    if (debug_mode == 2)
        acc = vec4(debugHeat(steps / 130.0), 1.0);
    fragColor = acc;
}
