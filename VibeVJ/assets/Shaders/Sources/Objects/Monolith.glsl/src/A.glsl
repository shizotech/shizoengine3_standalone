//@settings dtype=float16 format=rgba
// --- pass A: the objects, the floor, the world and the glow in linear light; alpha is the cover of the objects ---
#include lib/common.glsl

uniform sampler2D S;

//@enum options=(Cube, Pyramid, Triangle prism, Octahedron, Slab) value=0
uniform int shape;
//@enum options=(Single, Trio, Ring, Orbit) value=0
uniform int arrangement;            // Ring: a big one in the middle and 6 small ones around; Orbit: 3 small ones fly around
//@slider min=0.0 max=0.25 value=0.04
uniform float bevel;                // the rounded edges, part of the size
//@slider min=-2.0 max=2.0 value=0.25
uniform float spin;                 // turns per 16 beats
//@slider min=0.0 max=90.0 value=35.0
uniform float tilt;                 // degrees: 35 stands a cube nearly on a corner
//@slider min=0.0 max=1.0 value=0.35
uniform float pulse;                // the music makes the object bigger for a moment

//@rgb value=(0.012, 0.012, 0.016)
uniform vec3 base_color;            // the lacquer: nearly black
//@slider min=0.02 max=1.0 value=0.28
uniform float roughness;            // of the lacquer under the clear coat
//@slider min=0.0 max=1.0 value=1.0
uniform float clear_coat;           // a sharp mirror layer on top
//@slider min=0.0 max=1.0 value=0.3
uniform float smudges;              // fingerprints and dust that roughen the clear coat in spots
//@rgb value=(0.75, 0.75, 0.8)
uniform vec3 edge_color;            // the brushed metal of the bevels
//@slider min=0.0 max=1.0 value=0.8
uniform float anisotropy;           // how far the highlights on the bevels are stretched along the brushing

//@enum options=(Edges, Circuit, Scan, Off) value=0
uniform int lines;                  // the glowing lines: on the edges, circuit traces, or a band that runs up on the beat
//@rgb value=(0.1, 0.85, 1.0)
uniform vec3 line_color;
//@slider min=0.0 max=30.0 value=6.0
uniform float line_intensity;
//@slider min=0.0 max=1.0 value=0.35
uniform float line_width;
//@slider min=0.0 max=1.0 value=0.7
uniform float lines_react;          // how much the lines follow the music (the mids and the kicks)

//@enum options=(City, Panels, Studio, Void) value=3
uniform int environment;            // what is all around and in the reflections; Void: nothing, only the glow
//@rgb value=(1.0, 0.18, 0.62)
uniform vec3 neon_a;                // the first neon colour (city signs, panels, key light)
//@rgb value=(0.12, 0.6, 1.0)
uniform vec3 neon_b;                // the second neon colour (rim light, panels)
//@slider min=0.0 max=4.0 value=1.0
uniform float environment_brightness;
//@slider min=0.0 max=4.0 value=2.0
uniform float reflections;          // how strongly the clear coat mirrors the world (1 is physically right, more reads better)
//@slider min=0.0 max=1.0 value=0.35
uniform float background_blur;      // the world behind the object out of focus
//@slider min=0.0 max=10.0 value=3.0
uniform float light_intensity;      // the key and rim lights
//@slider min=0.0 max=360.0 value=35.0
uniform float light_angle;          // degrees around the object
//@slider min=0.0 max=1.0 value=0.0
uniform float floor_reflection;     // a wet black floor; 0: no floor, the object floats in the dark
//@slider min=0.0 max=1.0 value=0.35
uniform float haze;                 // the air glows in the neon colours; Void: smoke in the glow

//@slider min=0.0 max=4.0 value=1.0
uniform float glow;                 // how much light the object pours into the space around it
//@slider min=0.0 max=1.0 value=0.55
uniform float glow_radius;          // 0 a tight halo, 1 the glow fills the whole picture
//@rgb value=(0.2, 0.45, 1.0)
uniform vec3 glow_color;
//@slider min=0.0 max=1.0 value=0.6
uniform float glow_beat;            // the glow pulses with the kicks (the beat without sound)
//@slider min=0.0 max=1.0 value=0.0
uniform float flicker;              // the lines and the glow flicker like a failing neon tube
//@slider min=0.0 max=1.0 value=0.4
uniform float face_glow;            // veins of light run over the faces, as if the object glowed inside

//@enum options=(Final, Normals, Steps, Edges) value=0
uniform int debug_mode;

// ---- set once a pixel in mainImage ----
mat3 objRot;            // the turn of the objects
float objScale;         // size with the pulse
float bob;              // the height of the hover
float shatter;          // 0 .. 1 while the glitch Shatter runs
float shatterSeed;
float floorY;
float pixelAngle;       // the angle one pixel covers (radians)
float glowNow;          // the glow with the beat and the flicker
float lineNow;          // the flicker of the lines (1: on)
vec3 glowCol;           // the colours of the glow and the lines, linear, with Color cycle
vec3 lineCol;
float marchMin;         // the nearest the last march came to the object
float pieceNow;         // the distance to the nearest piece of the last map (without the block borders of Shatter)

float sdTetra(vec3 q, float s) {
    return (max(abs(q.x + q.y) - q.z, abs(q.x - q.y) + q.z) - s) * 0.57735;
}
float sdTriPrism(vec3 q, vec2 h) {
    vec3 a = abs(q);
    return max(a.z - h.y, max(a.x * 0.866025 + q.y * 0.5, -q.y) - h.x * 0.5);
}

float shapeDistR(vec3 q, float s, float b) {
    if (shape == 1)
        return sdTetra(q, s * 1.15 - b * 1.7320508) - b;
    if (shape == 2)
        return sdTriPrism(q, vec2(s * 1.9 - b * 2.0, s * 0.9 - b)) - b;
    if (shape == 3)
        return sdOctahedron(q, s * 1.45 - b * 1.7320508) - b;
    if (shape == 4)
        return sdRoundBox(q, s * vec3(0.17, 1.55, 0.69), min(b, s * 0.15));
    return sdRoundBox(q, vec3(s), b);
}
float shapeDist(vec3 q, float s) {
    return shapeDistR(q, s, clamp(bevel, 0.0, 0.25) * s);
}

// The voxel shatter of the glitch: the shape cut into blocks that fly apart a little
float shapeShattered(vec3 q, float s) {
    if (shatter <= 0.001) {
        float d0 = shapeDist(q, s);
        pieceNow = min(pieceNow, d0);
        return d0;
    }
    float c = s * 0.42;
    vec3 id = floor(q / c);
    vec3 ctr = (id + 0.5) * c;
    vec3 h = hash33(id + floor(shatterSeed * 97.0));
    vec3 off = (h - 0.5) * c * 0.45 * shatter;
    float gap = 1.0 - 0.25 * shatter * (0.5 + h.x);
    float d = max(shapeDist(q - off, s), sdBox(q - ctr - off, vec3(c * 0.5 * gap)));
    pieceNow = min(pieceNow, d);
    // never step past the border of this block: the next block may hold something
    vec3 toBorder = c * 0.5 - abs(q - ctr);
    float border = max(min(min(toBorder.x, toBorder.y), toBorder.z), 0.0) + c * 0.02;
    return min(d, border);
}

// The nearest object: its distance, and the point in its own frame (q) with its size (s)
float objects(vec3 p, out vec3 q, out float s) {
    vec3 c = p - vec3(0.0, bob, 0.0);
    s = objScale;
    if (arrangement == 1) {
        // three on a triangle, each a bit different
        float best = 1e5;
        vec3 bq = c;
        float bs = s;
        for (int i = 0; i < 3; i++) {
            float a = float(i) * 2.0944 + 0.5;
            float si = s * (i == 0 ? 0.62 : (i == 1 ? 0.48 : 0.4));
            vec3 o = vec3(cos(a), 0.0, sin(a)) * s * 1.25 + vec3(0.0, (float(i) - 1.0) * s * 0.35, 0.0);
            vec3 qi = (c - o) * objRot;
            if (i == 1)
                qi = qi.yzx;
            if (i == 2)
                qi = qi.zxy;
            float d = shapeShattered(qi, si);
            if (d < best) {
                best = d;
                bq = qi;
                bs = si;
            }
        }
        q = bq;
        s = bs;
        return best;
    }
    if (arrangement == 2 || arrangement == 3) {
        float big = shapeShattered(c * objRot, s * 0.7);
        // the small ones: 6 in a ring (polar repetition, one evaluation) or 3 on tilted orbits
        float ang = iTime * LIB_TAU / 16.0 * spin * 1.5;
        vec3 r = c;
        float n = arrangement == 2 ? 6.0 : 3.0;
        float rad = s * (arrangement == 2 ? 2.0 : 1.9);
        r.xz = rot2(ang) * r.xz;
        if (arrangement == 3)
            r.xy = rot2(0.35) * r.xy;
        r.xz = domPolar(r.xz, n);
        r.x -= rad;
        vec3 sq = (r * objRot).zxy;
        float small = shapeShattered(sq, s * 0.22);
        if (small < big) {
            q = sq;
            s = s * 0.22;
            return small;
        }
        q = c * objRot;
        s = s * 0.7;
        return big;
    }
    q = c * objRot;
    return shapeShattered(q, s);
}

float map(vec3 p) {
    vec3 q;
    float s;
    return objects(p, q, s);
}

// Normal and curvature (the Laplacian of the distance: 0 on flat faces, about 1 / radius on the bevels)
vec4 normalCurv(vec3 p, float eps) {
    const vec2 k = vec2(1.0, -1.0);
    float a = map(p + k.xyy * eps), b = map(p + k.yyx * eps), c = map(p + k.yxy * eps), d = map(p + k.xxx * eps);
    vec3 n = normalize(k.xyy * a + k.yyx * b + k.yxy * c + k.xxx * d);
    float lap = (a + b + c + d - 4.0 * map(p)) / (2.0 * eps * eps);
    return vec4(n, lap);
}

vec2 march(vec3 ro, vec3 rd, float tmin, float tmax, int steps) {
    float t = tmin;
    float stepScale = shatter > 0.001 ? 0.6 : 0.95;
    for (int i = 0; i < 160; i++) {
        if (i >= steps)
            break;
        pieceNow = 1e5;
        float d = map(ro + rd * t);
        marchMin = min(marchMin, pieceNow);
        if (abs(d) < 0.0004 * t + 0.0003)
            return vec2(t, float(i));
        t += d * stepScale;
        if (t > tmax)
            break;
    }
    return vec2(-1.0, float(steps));
}

// ---- the world around: a neon city, light panels or a studio ----
float panel(float az, float y, float az0, float w, float y0, float y1, float blur) {
    float da = abs(mod(az - az0 + 3.14159265, 6.2831853) - 3.14159265);
    float e = 0.004 + blur * 0.25;
    return smoothstep(w + e, w - e, da) * smoothstep(y0 - e, y0 + e, y) * smoothstep(y1 + e, y1 - e, y);
}

vec3 environmentColor(vec3 rd, float blur) {
    vec3 ca = srgbToLinear(neon_a), cb = srgbToLinear(neon_b);
    float y = rd.y;
    float az = length(rd.xz) > 1e-5 ? atan(rd.z, rd.x) : 0.0;
    float ay = abs(y);
    vec3 col = mix(vec3(0.012, 0.01, 0.022), vec3(0.002, 0.002, 0.005), smoothstep(0.0, 0.7, ay));
    // windows smaller than a pixel are averaged (no flicker), and so is a blurred background
    float smoothing = max(smoothstep(0.0, 0.05, blur), smoothstep(0.25, 0.7, pixelAngle * 300.0));
    if (environment == 0) {
        // the city: two rows of towers on the horizon, lit windows, neon signs, a pink haze
        col += ca * 0.12 * exp(-ay * 9.0) + cb * 0.05 * exp(-ay * 3.0);
        for (int layer = 1; layer >= 0; layer--) {
            float fl = float(layer);
            float cols = layer == 0 ? 44.0 : 90.0;
            float u = az / 6.2831853 * cols + fl * 13.7;
            float id = floor(u);
            float fu = fract(u);
            float h = (layer == 0 ? 0.05 : 0.03) + pow(hash11(id + fl * 100.0), 1.6) * (layer == 0 ? 0.6 : 0.3);
            float wgap = 0.06 + 0.1 * hash11(id + 7.0);
            float e = 0.003 + blur * 0.15;
            float body = smoothstep(wgap - e, wgap + e, fu) * smoothstep(1.0 - wgap + e, 1.0 - wgap - e, fu)
                         * smoothstep(h + e, h - e, ay);
            if (body > 0.0) {
                vec3 b = mix(vec3(0.004, 0.004, 0.008), ca * 0.02, 0.3 * exp(-ay * 6.0));
                // windows: a grid on the tower, some lit
                vec2 wc = vec2(fu * (5.0 + 4.0 * hash11(id + 3.0)), ay * (layer == 0 ? 200.0 : 300.0));
                vec2 wi = floor(wc);
                vec2 wf = fract(wc);
                // whole floors dark or lit, single windows on and off, each its own brightness
                float floorOn = step(hash12(vec2(wi.y, id + fl * 61.0)), 0.55);
                float lit = step(hash12(wi + id * 31.0 + fl * 7.0), 0.45) * floorOn;
                float win = smoothstep(0.3, 0.18, abs(wf.x - 0.5)) * smoothstep(0.3, 0.16, abs(wf.y - 0.5)) * lit;
                vec3 wcol = mix(vec3(1.0, 0.7, 0.4), vec3(0.6, 0.85, 1.0), hash12(wi + 5.0)) * (0.25 + 1.1 * hash12(wi + 9.0));
                b += wcol * mix(win, 0.06, smoothing) * (layer == 0 ? 1.0 : 0.5);
                // a neon sign on some towers
                float sgn = step(hash11(id + 11.0 + fl * 50.0), 0.22);
                float sy = h * (0.35 + 0.4 * hash11(id + 13.0));
                float sh = 0.012 + 0.02 * hash11(id + 17.0);
                float sw = 0.04 + 0.08 * hash11(id + 23.0);
                float sign = sgn * smoothstep(sw + e, sw - e, abs(fu - 0.3 - 0.4 * hash11(id + 29.0))) * smoothstep(sh * 1.2 + e, sh * 1.2 - e, abs(ay - sy));
                b += mix(ca, cb, step(0.5, hash11(id + 19.0))) * sign * 8.0;
                // the air between: towers far away and high up fade into the pink haze
                vec3 hz = ca * 0.06 + cb * 0.02;
                b = mix(b, hz, clamp((layer == 0 ? 0.15 : 0.45) + ay * 0.6, 0.0, 0.85));
                col = mix(col, b, body);
            }
        }
        // two big billboards
        col += ca * 10.0 * panel(az, ay, 0.9, 0.025, 0.03, 0.07, blur);
        col += cb * 10.0 * panel(az, ay, 3.6, 0.018, 0.04, 0.11, blur);
        // the glow of the city lights in the clouds, and two long light strips high up (the reflections on the top)
        col += mix(ca, cb, 0.5 + 0.5 * sin(az * 2.0)) * 0.03 * exp(-max(y, 0.0) * 2.5) * step(0.0, y);
        col += vec3(0.85, 0.9, 1.0) * 8.0 * panel(az, y, 2.2, 0.5, 0.62, 0.66, blur);
        col += ca * 5.0 * panel(az, y, 5.2, 0.4, 0.45, 0.48, blur);
    } else if (environment == 1) {
        // panels: tall light strips around, in the two neon colours, and a ring of strips above
        for (int i = 0; i < 6; i++) {
            float a = float(i) * 1.0472 + 0.3;
            vec3 pc = (i % 2 == 0) ? ca : cb;
            col += pc * 14.0 * panel(az, y, a, 0.018, -0.25, 0.55, blur);
        }
        col += vec3(1.0) * 3.0 * smoothstep(0.82 - blur * 0.3, 0.86, y) * (0.6 + 0.4 * step(0.5, fract(az * 3.0 / 3.14159265)));
    } else if (environment == 3) {
        // Void: nothing around, only the glow of the object, and two soft strips the clear coat picks up
        col = glowCol * 0.05 * (0.4 + 0.6 * smoothstep(-0.6, 0.6, y)) * glowNow;
        col += ca * 0.35 * panel(az, y, 0.7, 0.3, 0.15, 0.75, blur + 0.12);
        col += cb * 0.5 * panel(az, y, 3.9, 0.22, -0.1, 0.5, blur + 0.12);
        col += vec3(0.5) * smoothstep(0.75 - blur * 0.3, 0.95, y);
    } else {
        // studio: two big soft boxes and a light from above
        col = mix(vec3(0.09), vec3(0.015), smoothstep(-0.1, 0.8, y));
        col += vec3(1.0, 0.97, 0.92) * 10.0 * panel(az, y, 0.6, 0.22, -0.05, 0.5, blur + 0.03);
        col += vec3(0.9, 0.95, 1.0) * 6.0 * panel(az, y, 3.9, 0.14, 0.0, 0.45, blur + 0.03);
        col += vec3(1.0) * 4.0 * smoothstep(0.88 - blur * 0.3, 0.93, y);
    }
    // below the horizon: a dark street that mirrors a little of it
    col *= mix(1.0, 0.25 * smoothstep(-0.6, 0.0, y), smoothstep(0.0, -0.04, y));
    return col * environment_brightness;
}

// The two lights: a key light in Neon A and a rim light in Neon B behind the object
vec3 keyDir() {
    float a = radians(light_angle);
    return normalize(vec3(cos(a), 0.7, sin(a)));
}
vec3 rimDir() {
    float a = radians(light_angle + 150.0);
    return normalize(vec3(cos(a), 0.35, sin(a)));
}

// Anisotropic GGX for the brushed bevels: t is the brushing direction
vec3 specAniso(vec3 n, vec3 v, vec3 l, vec3 t, float rough, float aniso, vec3 f0) {
    vec3 h = normalize(v + l);
    float NoL = max(dot(n, l), 0.0);
    float NoV = max(dot(n, v), 1e-4);
    if (NoL <= 0.0)
        return vec3(0.0);
    vec3 b = normalize(cross(n, t));
    vec3 tt = cross(b, n);
    float a = max(rough * rough, 0.002);
    float at = max(a * (1.0 + aniso * 4.0), 0.002), ab = max(a * (1.0 - aniso * 0.7), 0.002);
    float th = dot(h, tt), bh = dot(h, b), nh = dot(h, n);
    float den = th * th / (at * at) + bh * bh / (ab * ab) + nh * nh;
    float D = 1.0 / (3.14159265 * at * ab * den * den);
    float Vis = visibilitySmithGGX(NoV, NoL, sqrt(at * ab));
    vec3 F = fresnelSchlick(max(dot(v, h), 0.0), f0);
    return 3.14159265 * D * Vis * F * NoL;
}

float levelsMid;
float levelsKick;

// The glowing lines on the object, in its own frame q (size s)
float lineMask(vec3 q, vec3 nl, float s, float edge, vec3 pw) {
    float w = mix(0.01, 0.08, line_width);
    if (lines == 0) {
        float r = s * 0.16;
        float dev = shapeDistR(q, s, r) - shapeDistR(q, s, clamp(bevel, 0.0, 0.25) * s);
        float e0 = s * 0.004;
        float wd = s * mix(0.0006, 0.003, line_width);
        return smoothstep(wd, wd * 0.3, abs(dev - e0)) + 0.25 * smoothstep(0.5, 1.0, edge);
    }
    if (lines == 1) {
        // circuit traces, on each face plane (triplanar)
        vec3 an = pow(abs(nl), vec3(8.0));
        an /= an.x + an.y + an.z;
        float m = 0.0;
        for (int k = 0; k < 3; k++) {
            vec2 uv = k == 0 ? q.yz : (k == 1 ? q.zx : q.xy);
            vec2 g = uv / s * 3.0 + float(k) * 3.7;
            vec2 id = floor(g);
            vec2 f = fract(g) - 0.5;
            float h = hash12(id + float(k) * 17.0);
            float d = 1.0;
            if (h < 0.3)
                d = abs(f.y);
            else if (h < 0.6)
                d = abs(f.x);
            else if (h < 0.72)
                d = abs(length(f) - 0.2);
            else if (h < 0.85)
                d = min(max(abs(f.x), f.y), max(abs(f.y), f.x));
            m += an[k] * smoothstep(w * 1.5, w * 0.5, d);
        }
        return m;
    }
    if (lines == 2) {
        // a band that runs up the object on every beat, with thin lines behind it
        float yb = mix(-1.8, 1.8, fract(iTime)) * objScale;
        float band = exp(-pow((pw.y - bob - yb) / (0.04 + w), 2.0));
        float rows = smoothstep(w * 0.6, 0.0, abs(fract(pw.y / s * 6.0) - 0.5) - 0.45) * 0.15;
        return band + rows;
    }
    return 0.0;
}

// The lacquer, the clear coat and the brushed metal of the bevels, lit by the two lights and the environment;
// `refl` is what the clear coat mirrors (the environment, or the other objects)
vec3 shadeObject(vec3 p, vec3 n, vec3 v, float edge, vec3 q, vec3 nl, float s, vec3 refl, float shadow) {
    vec3 base = srgbToLinear(base_color);
    vec3 ca = srgbToLinear(neon_a), cb = srgbToLinear(neon_b);
    vec3 lk = keyDir(), lr = rimDir();
    float NoV = max(dot(n, v), 1e-4);
    // smudges: patches of a rougher clear coat
    float sm = smudges * smoothstep(0.1, 0.7, fbm(q / s * 2.3 + 3.0, 4, 2.0, 0.5) * 0.5 + 0.5);
    float ccRough = mix(0.03, 0.22, sm);
    // brushing direction on a bevel: along the axis the normal does not point to (the edge)
    vec3 an = abs(nl);
    vec3 tl = an.x < an.y && an.x < an.z ? vec3(1.0, 0.0, 0.0) : (an.y < an.z ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0));
    vec3 t = normalize(objRot * tl);
    t = normalize(t - n * dot(n, t) + 1e-4);
    float metal = edge;
    vec3 col = vec3(0.0);
    vec3 keyC = ca * light_intensity, rimC = cb * light_intensity * 1.3;
    // the lacquer
    // (its own highlight is soft and weak: the clear coat on top makes the sharp ones)
    vec3 lac = (base * max(dot(n, lk), 0.0) + 0.25 * specularGGX(n, v, lk, roughness, vec3(0.04))) * keyC * shadow
             + (base * max(dot(n, lr), 0.0) + 0.25 * specularGGX(n, v, lr, roughness, vec3(0.04))) * rimC;
    // the brushed metal
    vec3 met = specAniso(n, v, lk, t, 0.32, anisotropy, srgbToLinear(edge_color)) * keyC * shadow
             + specAniso(n, v, lr, t, 0.32, anisotropy, srgbToLinear(edge_color)) * rimC;
    vec3 envM = srgbToLinear(edge_color) * environmentColor(reflect(-v, normalize(n + t * 0.25 * anisotropy)), 0.18) * 0.6;
    col = mix(lac, met + envM, metal);
    // the clear coat: a sharp mirror on top of the lacquer (not on the metal)
    float Fc = fresnelSchlick(NoV, vec3(0.04)).x;
    float lr2 = max(ccRough, 0.12);
    vec3 cc = specularGGX(n, v, lk, lr2, vec3(0.04)) * keyC * shadow + specularGGX(n, v, lr, lr2, vec3(0.04)) * rimC;
    vec3 ccEnv = refl * envBRDFApprox(vec3(0.04), NoV, ccRough) * reflections;
    col = mix(col, col * (1.0 - Fc * clear_coat) + (cc + ccEnv) * clear_coat, 1.0 - metal);
    // without a clear coat the lacquer mirrors softly
    col += (1.0 - clear_coat) * (1.0 - metal) * environmentColor(reflect(-v, n), roughness * 0.6) * envBRDFApprox(vec3(0.04), NoV, roughness);
    // the glowing lines
    float li = line_intensity * lineNow * (0.3 + lines_react * (0.6 * levelsMid + 0.9 * levelsKick) + (1.0 - lines_react) * 0.5);
    col += lineCol * lineMask(q, nl, s, edge, p) * li;
    // veins of light on the faces: the object glows inside and the light leaks out through cracks
    if (face_glow > 0.0) {
        vec3 x = q / s * 1.1 + vec3(0.0, -iTime * 0.12, 0.0);
        float n = fbm(x, 3, 2.03, 0.45);
        float wv = 0.035 * (0.5 + line_width);
        float vein = smoothstep(wv, wv * 0.2, abs(n)) + 0.06 * smoothstep(wv * 5.0, 0.0, abs(n));
        float flow = pow(0.5 + 0.5 * sin(dot(q / s, vec3(2.1, 3.3, 1.7)) * 2.5 - iTime * LIB_TAU * 0.5), 2.0);
        col += mix(glowCol, lineCol, 0.5) * face_glow * glowNow * (1.0 - metal) * (vein * (0.25 + flow) * 6.0 + 0.004);
    }
    return col;
}

// What the floor and the clear coat see along a ray: another object (shaded simply) or the environment
vec3 traceReflection(vec3 ro, vec3 rd, float blur, int steps) {
    vec2 h = march(ro, rd, 0.02, 14.0, steps);
    if (h.x > 0.0) {
        vec3 p = ro + rd * h.x;
        vec4 nc = normalCurv(p, 0.002);
        vec3 q;
        float s;
        objects(p, q, s);
        vec3 nl = nc.xyz * objRot;
        float edge = clamp(nc.w * s * clamp(bevel, 0.01, 0.25) * 0.8, 0.0, 1.0);
        return shadeObject(p, nc.xyz, -rd, edge, q, nl, s, environmentColor(reflect(rd, nc.xyz), 0.05), 1.0);
    }
    return environmentColor(rd, blur);
}

float boundRadius() {
    float r = objScale * (arrangement == 0 ? 1.9 : (arrangement == 1 ? 2.3 : 2.6));
    if (shape == 4 && arrangement == 0)
        r = objScale * 1.75;
    return r + 0.05;
}

vec4 render(vec3 ro, vec3 rd, out float steps) {
    steps = 0.0;
    vec3 col;
    float cover = 0.0;
    vec3 bc = vec3(0.0, bob, 0.0);
    // the march also finds how near the ray passes the object (the halo), so it starts further out
    float wIn = objScale * (0.04 + 0.22 * glow_radius);
    float reach = glow > 0.0 ? 6.0 * wIn : 0.0;
    vec2 bs = iSphere(ro, rd, bc, boundRadius() + reach);
    vec2 hit = vec2(-1.0, 0.0);
    int maxSteps = quality == 1 ? 72 : 110;
    marchMin = 1e5;
    if (bs.y > 0.0) {
        hit = march(ro, rd, max(bs.x, 0.0), bs.y, maxSteps);
        steps = hit.y;
    }
    float nearest = marchMin;
    bool showFloor = floor_reflection > 0.0 && background_mode == 0;
    float tFloor = rd.y < 0.0 ? (floorY - ro.y) / rd.y : -1.0;
    if (hit.x > 0.0) {
        vec3 p = ro + rd * hit.x;
        float eps = 0.0007 * hit.x;
        vec4 nc = normalCurv(p, max(eps, 0.0015 * objScale));
        vec3 n = nc.xyz;
        vec3 q;
        float s;
        objects(p, q, s);
        vec3 nl = n * objRot;
        float bevelR = max(clamp(bevel, 0.0, 0.25) * s, 1e-3);
        float edge = clamp(nc.w * bevelR * 0.8, 0.0, 1.0);
        if (bevel < 0.005)
            edge = 0.0;
        vec3 v = -rd;
        vec3 r = reflect(rd, n);
        vec3 refl;
        float shadow = 1.0;
        if (quality >= 2) {
            refl = traceReflection(p + n * 0.004, r, 0.02, 48);
            // a soft shadow of the key light (the other objects)
            vec3 l = keyDir();
            float res = 1.0, t = 0.03;
            for (int i = 0; i < 24; i++) {
                float h = map(p + n * 0.004 + l * t);
                res = min(res, 10.0 * h / t);
                t += clamp(h, 0.02, 0.3);
                if (res < 0.01 || t > 6.0)
                    break;
            }
            shadow = clamp(res, 0.0, 1.0);
        } else {
            refl = environmentColor(r, 0.02);
        }
        // the floor in the reflection
        if (showFloor && r.y < 0.0) {
            float tf = (floorY - p.y) / r.y;
            vec3 fp = p + r * tf;
            float fade = exp(-0.04 * dot(fp.xz, fp.xz));
            refl = mix(refl, environmentColor(reflect(r, vec3(0.0, 1.0, 0.0)), 0.1) * 0.15 * floor_reflection, fade);
        }
        col = shadeObject(p, n, v, edge, q, nl, s, refl, shadow);
        cover = 1.0;
        if (debug_mode == 1)
            col = debugNormal(n);
        if (debug_mode == 3)
            col = vec3(edge);
    } else if (showFloor && tFloor > 0.0) {
        // the wet floor: puddles mirror sharply, the rest is rough asphalt
        vec3 fp = ro + rd * tFloor;
        float pd = smoothstep(-0.3, 0.4, fbm(fp.xz * 0.35 + 7.0, 4));
        float rough = mix(0.2, 0.03, pd);
        vec3 fn = normalize(vec3(gradientNoise(fp.xz * 2.0) * 0.015 * (1.0 - pd), 1.0, gradientNoise(fp.xz * 2.0 + 9.0) * 0.015 * (1.0 - pd)));
        vec3 r = reflect(rd, fn);
        int rsteps = quality == 1 ? 32 : 56;
        vec3 refl = traceReflection(fp + fn * 0.01, r, rough * 0.5 + background_blur * 0.08, rsteps);
        float F = fresnelSchlick(max(dot(-rd, fn), 0.0), vec3(0.03)).x;
        float reflAmt = mix(0.08, 1.0, F) * floor_reflection * mix(0.55, 1.0, pd);
        vec3 ca = srgbToLinear(neon_a), cb = srgbToLinear(neon_b);
        // the floor lit by the lights and by the glowing lines above it
        float dist = length(fp.xz);
        float under = exp(-dist * dist / (objScale * objScale * 3.0));
        vec3 diff = vec3(0.015) * (ca * light_intensity * 0.05 + cb * light_intensity * 0.04 + 0.02);
        vec3 lineGlow = srgbToLinear(line_color) * line_intensity * 0.012 * under * (lines == 3 ? 0.0 : 1.0)
                        * (0.4 + lines_react * levelsKick);
        // contact shadow under the object
        float occ = 1.0 - 0.6 * exp(-dist * dist / (objScale * objScale * 0.6));
        col = (refl * reflAmt + diff + lineGlow) * occ;
        // fade into the environment far away
        float fade = exp(-0.012 * tFloor * tFloor);
        col = mix(environmentColor(rd, 0.02 + background_blur * 0.12), col, fade);
    } else {
        col = environment == 3 ? vec3(0.0) : environmentColor(rd, background_blur * 0.12);
    }
    if (background_mode != 0) {
        // the object alone: nothing behind it
        col *= cover;
    } else if (environment != 3) {
        // haze: the air glows a little in the neon colours
        float tt = hit.x > 0.0 ? hit.x : (showFloor && tFloor > 0.0 ? tFloor : 30.0);
        float hz = haze * (1.0 - exp(-tt * 0.02));
        col = mix(col, (srgbToLinear(neon_a) * 0.6 + srgbToLinear(neon_b) * 0.4) * 0.08 * environment_brightness, hz);
    }
    // the glow: a hot halo that hugs the shape (how near the ray passed it) and a wide one that fills the space
    if (glow > 0.0) {
        vec3 oc = bc - ro;
        float dRay = length(oc - rd * max(dot(oc, rd), 0.0));
        float wOut = objScale * (0.35 + 3.2 * glow_radius * glow_radius + 0.6 * glow_radius);
        float x = dRay / wOut;
        float outer = 1.0 / (1.0 + x * x * (1.0 + 0.5 * x));
        float inner = hit.x > 0.0 ? 0.0 : exp(-max(nearest, 0.0) / wIn);
        if (environment == 3 && haze > 0.0) {
            // smoke that the glow lights: thicker and thinner patches drifting up slowly
            float n = fbm(rd * 3.2 + vec3(0.0, -iTime * 0.04, iTime * 0.015), 3, 2.1, 0.5);
            outer *= mix(1.0, 0.3 + 1.6 * smoothstep(-0.45, 0.55, n), haze);
        }
        vec3 halo = glowCol * outer * 1.1 + mix(glowCol, lineCol, 0.6) * inner * 2.5;
        // in front of the object only the thin air between glows
        halo *= hit.x > 0.0 ? 0.025 : 1.0;
        col += halo * glowNow;
    }
    return vec4(col, cover);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 lv = texelFetch(S, ivec2(ST_LEVELS, 0), 0);
    vec4 bt = texelFetch(S, ivec2(ST_BEAT, 0), 0);
    vec4 sd = texelFetch(S, ivec2(ST_SOUND, 0), 0);
    vec4 sp = texelFetch(S, ivec2(ST_SPRING, 0), 0);
    levelsMid = lv.y;
    levelsKick = sd.y;
    float g = glitchAmount(bt);
    shatter = (glitchKindFor(bt.z + floor(iTime * 2.0) * 0.37) == 4) ? g : 0.0;
    shatterSeed = fract(bt.z + floor(iTime * 4.0) * 0.1234567);

    float t = iTime;
    objScale = size * (1.0 + pulse * 0.18 * clamp(sp.x, -0.5, 2.0));
    bob = bobAt(t);
    // the glow and the lines: Color cycle turns the hue, the kicks pump the glow, Flicker drops it out now and then
    float hue = hueAngleAt(t);
    glowCol = hueRotate(srgbToLinear(glow_color), hue);
    lineCol = hueRotate(srgbToLinear(line_color), hue);
    lineNow = 1.0;
    if (flicker > 0.0) {
        float h = hash11(floor(t * 16.0) + 31.0);
        float h2 = hash11(floor(t * 64.0) + 7.0);
        lineNow = 1.0 - flicker * (h < 0.22 ? 0.92 : 0.3 * h2);
    }
    glowNow = glow * (1.0 - 0.45 * glow_beat + glow_beat * 1.8 * clamp(levelsKick, 0.0, 1.5)) * mix(1.0, lineNow, 0.8);
    floorY = -size * (shape == 4 && arrangement == 0 ? 1.62 : 1.75) - 0.25 * hover * size;
    float yaw = t * LIB_TAU / 16.0 * spin;
    float tl = radians(tilt);
    mat3 ry = mat3(cos(yaw), 0.0, -sin(yaw), 0.0, 1.0, 0.0, sin(yaw), 0.0, cos(yaw));
    mat3 rx = mat3(1.0, 0.0, 0.0, 0.0, cos(tl), sin(tl), 0.0, -sin(tl), cos(tl));
    mat3 rz = mat3(cos(tl * 0.75), sin(tl * 0.75), 0.0, -sin(tl * 0.75), cos(tl * 0.75), 0.0, 0.0, 0.0, 1.0);
    objRot = shape == 4 ? ry : ry * rx * rz;

    // the camera
    vec3 ro;
    mat3 cam;
    cameraSetup(t, ro, cam);

    pixelAngle = 2.0 / (iResolution.y * zoom);
    int aa = quality >= 3 ? 2 : 1;
    vec4 acc = vec4(0.0);
    float steps = 0.0;
    for (int j = 0; j < 2; j++) {
        for (int i = 0; i < 2; i++) {
            if (i >= aa || j >= aa)
                continue;
            vec2 o = aa > 1 ? (vec2(float(i), float(j)) - 0.5) * 0.5 + vec2(0.125, -0.125) * (float(j) * 2.0 - 1.0) : vec2(0.0);
            vec2 uv = (2.0 * (fragCoord + o) - iResolution.xy) / iResolution.y;
            vec3 rd = cameraRay(cam, uv, zoom);
            float st;
            acc += render(ro, rd, st);
            steps = max(steps, st);
        }
    }
    acc /= float(aa * aa);
    if (debug_mode == 2)
        acc = vec4(debugHeat(steps / 110.0), 1.0);
    fragColor = acc;
}
