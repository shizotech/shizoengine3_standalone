//@settings dtype=float16 format=rgba
// --- pass A: the glass, ray traced. A camera ray marches to the nearest copy (signed distance functions, the grid of
// copies in cells), reflects there (Fresnel, Schlick) and goes in for several wavelengths, each with its own index of
// refraction: it bends, marches through the glass, leaves (bent again) or reflects inside (Fresnel, total internal
// reflection) up to Bounces times, and the glass swallows light on the way (Beer-Lambert). What a ray sees outside
// is the backdrop (the picture of Background, or a pattern) or the studio. The beam and its rainbow fan (pass L) glow
// in the haze ---
#include lib/common.glsl

uniform sampler2D S;
uniform sampler2D L;
uniform sampler2D M;                // pass M: whether a picture is linked into Background (one pixel)
uniform sampler2D background;       // the picture behind the glass (optional); read only when pass M says it is linked

//@int min=1 max=6 value=3
uniform int bounces;                // how often light may reflect inside the glass (the sparkle of total internal reflection)
//@int min=1 max=8 value=6
uniform int spectral_samples;       // wavelengths traced through the glass, each bent its own way: 1 no rainbow (Quality 1: at most 3)
//@slider min=0.0 max=2.0 value=0.8
uniform float haze;                 // how much the air shows the beams
//@enum options=(Studio, Black, Neon, Soft boxes) value=3
uniform int environment;            // what the glass mirrors (and shows where it does not look at the backdrop). Studio: dark, for the beam; Soft boxes: a bright photo studio
//@slider min=0.0 max=4.0 value=1.0
uniform float environment_brightness;
//@rgb value=(1.0, 0.25, 0.7)
uniform vec3 neon_a;                // Environment Neon
//@rgb value=(0.15, 0.6, 1.0)
uniform vec3 neon_b;
//@slider min=0.0 max=1.0 value=0.7
uniform float floor_amount;         // Backdrop None: a black glossy floor that catches the rainbow; 0: no floor
//@enum options=(Auto, None, Picture, Stripes, Lines, Grid, Checker, Gradient, Bokeh) value=0
uniform int backdrop;               // what stands behind the glass and is bent by it: Auto the picture of Background when one is linked, else Lines
//@slider min=0.5 max=10.0 value=3.0
uniform float backdrop_distance;    // how far behind the objects, in sizes: farther away it is bent more
//@slider min=0.2 max=4.0 value=1.0
uniform float backdrop_scale;       // the size of the pattern
//@slider min=-90.0 max=90.0 value=20.0
uniform float backdrop_angle;       // degrees the pattern is turned
//@slider min=-2.0 max=2.0 value=0.0
uniform float backdrop_scroll;      // pattern repeats it moves per 16 beats
//@rgb value=(1.0, 0.42, 0.1)
uniform vec3 backdrop_color_a;
//@rgb value=(0.1, 0.45, 1.0)
uniform vec3 backdrop_color_b;
//@slider min=0.0 max=4.0 value=1.0
uniform float backdrop_brightness;
//@slider min=0.0 max=1.0 value=0.6
uniform float caustics;             // the shadow and the focused light the glass throws on the backdrop
//@slider min=0.0 max=4.0 value=1.0
uniform float sparkle;              // a small bright lamp: glints on the glass and coloured sparks inside

//@slider min=2.0 max=14.0 value=2.7
uniform float camera_distance;
//@slider min=-30.0 max=80.0 value=12.0
uniform float camera_height;        // degrees above the floor
//@slider min=0.0 max=360.0 value=72.0
uniform float camera_angle;         // degrees around the glass (90: along the axis of the prism, the album cover)
//@slider min=-1.0 max=1.0 value=0.0
uniform float camera_orbit;         // turns per 16 beats
//@slider min=0.0 max=60.0 value=18.0
uniform float camera_swing;         // degrees the camera swings to and fro over 16 beats
//@slider min=0.8 max=5.0 value=1.9
uniform float zoom;
//@slider min=0.0 max=1.0 value=0.2
uniform float camera_shake;
//@enum options=(Final, Normals, Bounces, Beams only) value=0
uniform int debug_mode;

vec3 beamTint;                      // Beam color, linear
float envLights = 1.0;              // the lights of the studio seen straight (dimmed) or in the glass (full)
float beamPower;                    // the intensity of the beam now (with the music)
vec3 whiteSum;
int fanStep;                        // 1: every ray of the fan, 2: every second one (Quality 1)
bool beamOn;
vec3 cu, cv, cw, camPos;            // the camera: right, up, forward, position
float aspect;
int bdMode;                         // the backdrop: 1 none, 2 the picture, 3 .. 8 the patterns
float bdDist;                       // the backdrop: the plane dot(x, cw) = bdDist
vec3 lampDir;                       // the direction the light of the lamp travels
int NW;                             // wavelengths
float ETA[8];
vec3 WGT[8];
float dispExtra;
float gBlur = 0.0;                  // how blurred the backdrop is seen (screen units): see pattern()

// A soft box: a bright rectangle in direction c (half its size in tan units)
float softBox(vec3 d, vec3 c, vec2 hs) {
    float k = dot(d, c);
    if (k <= 0.0)
        return 0.0;
    vec3 r = normalize(cross(vec3(0.0, 1.0, 0.0), c));
    vec3 u = cross(c, r);
    vec2 q = vec2(dot(d, r), dot(d, u)) / k;
    vec2 e = abs(q) - hs;
    return smoothstep(0.04, -0.02, max(e.x, e.y));
}

vec3 environmentColor(vec3 d) {
    float y = d.y;
    float az = length(d.xz) > 1e-5 ? atan(d.z, d.x) : 0.0;
    vec3 col;
    if (environment == 1) {
        col = vec3(0.0015) + vec3(0.6) * smoothstep(0.93, 0.97, y);
    } else if (environment == 2) {
        vec3 ca = srgbToLinear(neon_a), cb = srgbToLinear(neon_b);
        col = vec3(0.004, 0.003, 0.008);
        for (int i = 0; i < 5; i++) {
            float a = float(i) * 1.2566 + 0.4;
            float da = abs(mod(az - a + 3.14159265, 6.2831853) - 3.14159265);
            col += ((i % 2 == 0) ? ca : cb) * 6.0 * smoothstep(0.03, 0.02, da) * smoothstep(-0.3, -0.25, y) * smoothstep(0.6, 0.55, y);
        }
        col += cb * 0.6 * smoothstep(0.85, 0.95, y);
    } else if (environment == 3) {
        // a photo studio: grey walls, a big soft box at the front left, a strip light at the back right, one above
        col = mix(vec3(0.025, 0.026, 0.03), vec3(0.11, 0.115, 0.125), smoothstep(-0.5, 0.7, y));
        col += vec3(1.0, 0.97, 0.93) * 5.0 * softBox(d, normalize(vec3(-0.76, 0.35, 0.88)), vec2(0.45, 0.6)) * envLights;
        col += vec3(0.9, 0.95, 1.0) * 3.5 * softBox(d, normalize(vec3(0.95, 0.15, -0.31)), vec2(0.12, 0.8)) * envLights;
        col += vec3(1.0) * 2.5 * smoothstep(0.86, 0.93, y) * envLights;
    } else {
        // a dark studio: a soft box above, a long strip on each side, a faint wall
        col = mix(vec3(0.006, 0.0065, 0.008), vec3(0.0015), smoothstep(-0.1, 0.7, y));
        col += vec3(0.035, 0.038, 0.045) * exp(-y * y * 40.0) * (0.6 + 0.4 * cos(az * 2.0));
        col += vec3(1.0, 0.98, 0.95) * 3.0 * smoothstep(0.82, 0.9, y) * envLights;
        float da = abs(mod(az - 0.5 + 3.14159265, 6.2831853) - 3.14159265);
        col += vec3(0.85, 0.9, 1.0) * 2.0 * smoothstep(0.12, 0.08, da) * smoothstep(-0.05, 0.05, y) * smoothstep(0.5, 0.4, y) * envLights;
        float db = abs(mod(az - 3.6 + 3.14159265, 6.2831853) - 3.14159265);
        col += vec3(1.0, 0.95, 0.9) * 1.2 * smoothstep(0.05, 0.03, db) * smoothstep(-0.2, -0.1, y) * smoothstep(0.7, 0.6, y) * envLights;
    }
    // the lamp: a small, very bright light behind the camera (glints, and the sparks inside the glass)
    float l = max(dot(d, -lampDir), 0.0);
    col += vec3(1.0, 0.97, 0.92) * sparkle * (40.0 * pow(l, 3000.0) + 0.6 * pow(l, 40.0)) * envLights;
    return col * environment_brightness;
}

vec4 fanPoint(int j, int r) {
    return texelFetch(L, ivec2(j, r), 0);
}
// The glow of the rays of the fan along a ray (o + u s, s up to smax), already in colour. The incoming white beam
// (segment 0) is beamGlow
vec3 fanGlow(vec3 o, vec3 u, float smax) {
    vec3 acc = vec3(0.0);
    for (int j = 0; j < FAN; j += fanStep) {
        vec4 info = fanPoint(j, 7);
        int count = int(info.y);
        float g = 0.0;
        for (int r = 1; r < 6; r++) {
            if (r + 1 >= count)
                break;
            vec4 a = fanPoint(j, r), b = fanPoint(j, r + 1);
            vec3 v = b.xyz - a.xyz;
            float len = length(v);
            if (len < 1e-4)
                continue;
            bool last = r + 2 >= count;
            g += a.w * segmentGlow(o, u, smax, a.xyz, v / len, len, beam_width, last ? spread : 0.0);
        }
        acc += spectralRGB(info.x) * g;
    }
    return acc / whiteSum * float(fanStep) * beamTint * beamPower * haze;
}
float beamGlow(vec3 o, vec3 u, float smax) {
    vec4 a = fanPoint(0, 0), b = fanPoint(0, 1);
    vec3 v = b.xyz - a.xyz;
    float len = length(v);
    return segmentGlow(o, u, smax, a.xyz, v / max(len, 1e-4), len, beam_width, 0.0) * beamPower * haze;
}
// Light of the fan that lands on the floor around point p: the last part of each path, where it hits the floor
vec3 fanOnFloor(vec3 p) {
    vec3 acc = vec3(0.0);
    for (int j = 0; j < FAN; j += fanStep) {
        vec4 info = fanPoint(j, 7);
        int count = int(info.y);
        if (count < 2)
            continue;
        vec4 a = fanPoint(j, count - 2), b = fanPoint(j, count - 1);
        if (b.y > floorY + 0.01)
            continue;
        vec3 v = b.xyz - a.xyz;
        float len = length(v);
        vec3 dir = v / max(len, 1e-4);
        float t = clamp(dot(p - a.xyz, dir), 0.0, len);
        vec3 q = p - (a.xyz + dir * t);
        float width = beam_width + spread * t;
        acc += spectralRGB(info.x) * a.w * exp(-dot(q, q) / (width * width * 4.0)) / (width * 30.0);
    }
    return acc / whiteSum * float(fanStep) * beamTint * beamPower;
}

// ---- the backdrop: a wall behind the objects that faces the camera. A ray that goes straight past the glass sees
// it exactly like the picture fills the screen, so the glass bends the picture in place ----
vec3 pattern(vec2 c) {
    vec3 A = srgbToLinear(backdrop_color_a), B = srgbToLinear(backdrop_color_b);
    float an = radians(backdrop_angle);
    vec2 q = mat2(cos(an), sin(an), -sin(an), cos(an)) * c / max(backdrop_scale, 0.05);
    q.x += gTime / 16.0 * backdrop_scroll * 0.5;
    // how blurred the ray sees it (in pattern units): rays that reflected inside the glass are spread wider, and a
    // sharp line would fall between the pixels as sparse dots
    float fw = gBlur / max(backdrop_scale, 0.05);
    if (bdMode == 3) {
        // bold stripes
        float e = 0.02 + fw * 2.0;
        return mix(B, A, smoothstep(-e, e, 0.25 - abs(fract(q.x * 2.0) - 0.5))) * 0.8;
    }
    if (bdMode == 5) {
        // a grid of thin lines on light paper
        vec2 g = abs(fract(q * 4.0 + 0.5) - 0.5);
        float l = min(g.x, g.y);
        vec3 paper = mix(vec3(0.62), A, 0.12);
        float e = 0.012 + fw * 4.0;
        return mix(mix(B * 0.5, paper, clamp(fw * 12.0, 0.0, 0.8)), paper, smoothstep(0.02 - e, 0.02 + e, l));
    }
    if (bdMode == 6) {
        float e = 0.02 + fw * 1.5;
        vec2 sq = smoothstep(-e, e, 0.25 - abs(fract(q * 1.5) - 0.5)) * 2.0 - 1.0;
        float k = 0.5 + 0.5 * sq.x * sq.y;
        return mix(A, B, k) * 0.7;
    }
    if (bdMode == 7) {
        // a studio sweep: dark below, a soft light above
        float y = c.y;
        vec3 col = mix(B * 0.05, A * 0.7 + 0.08, smoothstep(-1.1, 1.0, y));
        col += vec3(0.9) * exp(-dot(c - vec2(0.35, 0.45), c - vec2(0.35, 0.45)) * 1.5) * 0.6;
        return col;
    }
    if (bdMode == 8) {
        // out of focus lights at night
        vec3 col = mix(vec3(0.004, 0.004, 0.01), B * 0.03, smoothstep(-1.0, 1.0, c.y));
        for (int l = 0; l < 3; l++) {
            float sc = 2.0 + float(l) * 1.3;
            vec2 p = q * sc + float(l) * 7.31;
            vec2 id = floor(p);
            vec3 h = hash33(vec3(id, float(l) * 13.0));
            vec2 ctr = id + 0.5 + (h.xy - 0.5) * 0.3;
            float r = 0.14 + 0.18 * h.z;
            float dd = length(p - ctr);
            float e = r * 0.08 + fw * sc;
            float disc = smoothstep(r + e, r - e, dd) * (0.75 + 0.25 * smoothstep(r * 0.5, r * 0.95, dd));
            vec3 lc = h.z < 0.33 ? A : (h.z < 0.66 ? B : vec3(1.0, 0.85, 0.6));
            col += lc * disc * (1.6 - 0.35 * float(l)) * step(0.35, fract(h.x * 7.13 + h.y));
        }
        return col;
    }
    // Lines: thin bright lines on black, they split into rainbows in the glass
    float x = q.x * 1.8;
    float i = floor(x + 0.5);
    float dd = abs(x - i);
    vec3 lc = mod(i, 2.0) < 0.5 ? A : B;
    if (mod(i, 3.0) < 0.5)
        lc = vec3(1.0, 0.95, 0.9);
    vec3 bg = mix(vec3(0.004, 0.004, 0.006), vec3(0.03, 0.032, 0.04), smoothstep(-1.2, 1.2, c.y));
    float w = sqrt(0.022 * 0.022 + 3.24 * fw * fw);
    return bg + lc * (exp(-pow(dd / w, 2.0)) * 1.6 * 0.022 / w + exp(-dd * 18.0) * 0.06);
}

// The shadow and the focused light the glass throws on the backdrop at x: the light of the lamp that lands on x
// crossed the plane of the grid at y; where it went through the shape (looked at in five places along the light:
// about its outline) it was focused, bright in the middle with a rainbow at the rim; next to it a thin shadow
vec3 causticAt(vec3 x) {
    if (caustics <= 0.0 || abs(lampDir.z) < 0.05)
        return vec3(1.0);
    float s = x.z / lampDir.z;
    if (s < 0.0)
        return vec3(1.0);
    vec3 y = x - lampDir * s;
    vec3 c;
    mat3 R;
    int k;
    cellSetup(cellOf(y), c, R, k);
    float d = 1e9;
    for (int i = -2; i <= 2; i++)
        d = min(d, objDist((y + lampDir * (0.2 * gS * float(i)) - c) * R, k));
    d /= gS;
    vec3 f;
    if (d < 0.0) {
        float u = clamp(-d / 0.4, 0.0, 1.0);
        f = vec3(0.3 + 2.6 * smoothstep(0.5, 1.0, u) * smoothstep(1.0, 0.7, u * 0.8));
        vec3 rb = spectralRGB(420.0 + 280.0 * smoothstep(0.02, 0.4, u)) * 2.2;
        f = mix(f, rb, 0.7 * exp(-pow((u - 0.18) / 0.12, 2.0)));
    } else {
        f = vec3(1.0 - 0.45 * exp(-d / 0.05));
    }
    return mix(vec3(1.0), f, caustics);
}
vec3 backdropAt(vec3 x) {
    vec3 rel = x - camPos;
    vec2 c = vec2(dot(rel, cu), dot(rel, cv)) * zoom / max(dot(rel, cw), 1e-3);
    vec3 col;
    if (bdMode == 2) {
        vec2 uv = 0.5 + 0.5 * vec2(c.x / aspect, c.y);
        uv = 1.0 - abs(1.0 - mod(uv, 2.0));   // mirrored outside the picture
        col = srgbToLinear(passBilinear(background, uv).rgb);
    } else {
        col = pattern(c);
    }
    return col * backdrop_brightness * causticAt(x);
}

// What a ray sees outside the glass: the backdrop, else the room with the floor (the rainbow on it and the beams
// mirrored in it). glowToo: also the glow of the beams in the floor (only for the rays that count most)
vec3 outsideLight(vec3 p, vec3 d, bool glowToo, out vec3 glow) {
    glow = vec3(0.0);
    if (bdMode != 1) {
        float dn = dot(d, cw);
        if (dn > 0.03) {
            float tt = (bdDist - dot(p, cw)) / dn;
            if (tt > 0.0) {
                // a ray that runs almost along the backdrop sweeps over it fast: blur it more, and let the room
                // take over before it would only be noise
                float keep = gBlur;
                gBlur = min(gBlur / (dn * sqrt(dn)), 0.5);
                vec3 b = backdropAt(p + d * tt);
                gBlur = keep;
                return mix(environmentColor(d), b, smoothstep(0.03, 0.2, dn));
            }
        }
        return environmentColor(d);
    }
    bool fl = floor_amount > 0.0 && background_mode == 0;
    if (fl && d.y < -1e-4) {
        float tf = (floorY - p.y) / d.y;
        vec3 fp = p + d * tf;
        vec3 rd = reflect(d, vec3(0.0, 1.0, 0.0));
        float F = fresnelSchlick(max(-d.y, 0.0), vec3(0.04)).x;
        float fade = exp(-0.01 * dot(fp.xz, fp.xz));
        vec3 refl = environmentColor(rd) * F * 2.0;
        if (beamOn && glowToo)
            glow = (fanGlow(fp, rd, 30.0) * F * 1.5 + fanOnFloor(fp) * 0.5) * floor_amount * fade;
        return mix(environmentColor(d), refl * floor_amount + vec3(0.002), fade);
    }
    return environmentColor(d);
}
vec3 outside(vec3 p, vec3 d) {
    vec3 g;
    return outsideLight(p, d, false, g);
}

// The light that comes out of the glass along the rays of the wavelengths, seen from the entry point p (normal n,
// the camera ray rd, transmitted share thr0). Quality 1: one path at the middle index for all wavelengths, each
// leaves with its own bend; else one path per wavelength. glow: the beams inside and behind the glass
vec3 throughGlass(vec3 p, vec3 rd, vec3 n, vec3 thr0, out vec3 glow, out float nbMax) {
    glow = vec3(0.0);
    nbMax = 0.0;
    vec3 tintL = srgbToLinear(glass_tint);
    vec3 sigma = absorption * (3.0 * (1.0 - tintL) + 0.05);
    bool onePath = quality == 1;
    int maxB = quality == 1 ? min(bounces, 2) : bounces;
    int isteps = quality == 1 ? 32 : 56;
    float off = 0.003 * gS;
    vec3 total = vec3(0.0);
    int paths = onePath ? 1 : NW;
    for (int w = 0; w < 8; w++) {
        if (w >= paths)
            break;
        float eta = onePath ? iorAt(550.0, dispExtra) : ETA[w];
        bool mid = onePath || w == NW / 2;
        vec3 d = refract(rd, n, 1.0 / eta);
        vec3 q = p - n * off;
        vec3 thr = thr0;
        vec3 Li = vec3(0.0);
        float nb = 0.0;
        for (int b = 0; b < 6; b++) {
            if (b >= maxB)
                break;
            float tt = marchInside(q, d, isteps);
            if (tt < 0.0)
                break;
            if (beamOn && mid && b == 0)
                glow += thr * fanGlow(q, d, tt);
            q += d * tt;
            thr *= exp(-sigma * tt);
            vec3 m = localNormal(q);
            float c = max(dot(d, m), 0.0);
            nb += 1.0;
            vec3 rr = refract(d, -m, eta);
            if (dot(rr, rr) < 1e-6) {
                // total internal reflection: all of it stays inside
                d = reflect(d, m);
                q -= m * off;
                continue;
            }
            float F2 = fresnelDielectric(c, eta, 1.0);
            vec3 qo = q + m * off;
            gBlur = (0.003 + 0.006 * float(b)) / max(dot(rr, m), 0.2);   // a grazing exit spreads the rays
            if (onePath) {
                // each wavelength leaves with its own bend (one that is reflected completely adds nothing here)
                vec3 acc = vec3(0.0);
                for (int i = 0; i < 8; i++) {
                    if (i >= NW)
                        break;
                    vec3 ri = refract(d, -m, ETA[i]);
                    if (dot(ri, ri) > 1e-6)
                        acc += WGT[i] * outside(qo, ri);
                }
                Li += thr * (1.0 - F2) * acc;
            } else {
                Li += thr * (1.0 - F2) * outside(qo, rr);
            }
            if (beamOn && mid && b == 0) {
                vec3 g;
                outsideLight(qo, rr, true, g);
                glow += thr * (1.0 - F2) * (g + fanGlow(qo, rr, 40.0));
            }
            thr *= F2;
            d = reflect(d, m);
            q -= m * off;
        }
        // what is left after the last bounce: about what the last direction sees
        gBlur = 0.003 + 0.006 * float(maxB);
        Li += thr * outside(q, d) * 0.5;
        total += onePath ? Li : WGT[w] * Li;
        nbMax = max(nbMax, nb);
    }
    return total;
}

vec4 render(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.0), glow = vec3(0.0);
    float tHit;
    bool hit = marchScene(ro, rd, 80.0, quality == 1 ? 72 : 110, tHit);
    if (beamOn) {
        float smax = hit ? tHit : 40.0;
        glow += fanGlow(ro, rd, smax) + beamGlow(ro, rd, smax) * beamTint;
    }
    if (!hit) {
        if (background_mode == 0) {
            vec3 g;
            // seen straight from the camera the lights of the studio are dim (they are for the glass)
            envLights = 0.1;
            col = outsideLight(ro, rd, true, g);
            envLights = 1.0;
            glow += g;
        }
        if (debug_mode == 1 || debug_mode == 2)
            col = vec3(0.0);
        if (debug_mode == 3)
            col = vec3(0.0);
        vec3 c = col + glow;
        return vec4(c, background_mode == 2 ? clamp(max(max(c.r, c.g), c.b), 0.0, 1.0) : 0.0);
    }
    vec3 p = ro + rd * tHit;
    vec3 n = localNormal(p);
    if (debug_mode == 1)
        return vec4(debugNormal(n), 1.0);
    float cosi = max(-dot(rd, n), 0.0);
    float eta = iorAt(550.0, dispExtra);
    float f0 = pow((eta - 1.0) / (eta + 1.0), 2.0);
    float F = fresnelSchlick(cosi, vec3(f0)).x;
    vec3 rdir = reflect(rd, n);
    gBlur = 0.003;
    col += F * outside(p + n * 0.003 * gS, rdir);
    vec3 g;
    float nb;
    col += throughGlass(p, rd, n, vec3(1.0 - F) * srgbToLinear(glass_tint), g, nb);
    glow += g;
    if (debug_mode == 2)
        col = debugHeat(nb / float(max(bounces, 1)));
    if (debug_mode == 3)
        col = vec3(0.0);
    col += glow;
    float alpha = background_mode == 2 ? clamp(max(max(col.r, col.g), col.b), 0.0, 1.0) : 1.0;
    return vec4(col, alpha);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 lv = texelFetch(S, ivec2(ST_LEVELS, 0), 0);
    vec4 sp = texelFetch(S, ivec2(ST_SPRING, 0), 0);
    float t = iTime;
    setupScene(t, lv.y * react * 4.0, sp.x);
    whiteSum = fanWhite();
    beamTint = srgbToLinear(beam_color);
    fanStep = quality == 1 ? 2 : 1;
    beamOn = beam_intensity > 0.0;
    beamPower = beam_intensity * (1.0 - beat_flash + beat_flash * clamp(0.35 + 1.1 * sp.x, 0.0, 2.5));
    aspect = iResolution.x / iResolution.y;
    dispExtra = 1.0 + lv.z * react * 0.6;

    // the wavelengths: each with its index of refraction and its share of white (the shares add up to white)
    NW = clamp(quality == 1 ? min(spectral_samples, 3) : spectral_samples, 1, 8);
    // each pixel takes its wavelengths a little shifted (and every frame others), so the few wavelengths blend
    // into a smooth rainbow instead of a few coloured copies
    float jit = fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715))) + 0.61803399 * float(iFrame % 64));
    vec3 wsum = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        if (i >= NW)
            break;
        float lnm = NW == 1 ? 550.0 : 400.0 + (float(i) + jit) / float(NW) * 300.0;
        ETA[i] = iorAt(lnm, dispExtra);
        WGT[i] = NW == 1 ? vec3(1.0) : spectralRGB(lnm);
        wsum += WGT[i];
    }
    for (int i = 0; i < 8; i++) {
        if (i >= NW)
            break;
        WGT[i] /= max(wsum, vec3(1e-4));
    }

    // the backdrop
    bool linked = texelFetch(M, ivec2(0, 0), 0).r > 0.5;
    // Auto: the picture, else Lines; with the beam on (the album cover) the dark studio of the beam
    bdMode = backdrop == 0 ? (linked ? 2 : (beamOn ? 1 : 4)) : backdrop;
    if (bdMode == 2 && !linked)
        bdMode = 4;

    // the camera: far enough back for all copies of the grid
    float e0 = 0.95 * size;
    float ext = max((0.5 * float(gN.x - 1) * gCell + e0) / max(aspect / 1.7778, 0.3), (0.5 * float(gN.y - 1) * gCell + e0) * 1.05);
    float fit = max(1.0, ext / e0);
    float ca = radians(camera_angle + camera_swing * sin(t * 6.2831853 / 16.0)) + t * 6.2831853 / 16.0 * camera_orbit;
    float ch = radians(camera_height);
    float shake = camera_shake * 0.04;
    ca += shake * gradientNoise(vec2(t * 0.11, 1.7)) * 2.0;
    ch += shake * gradientNoise(vec2(t * 0.13, 5.3));
    vec3 ro = camera_distance * size * fit * vec3(cos(ch) * cos(ca), sin(ch), cos(ch) * sin(ca));
    vec3 ta = beamOn ? vec3(0.35 * size, -0.1 * size, 0.0) : vec3(0.0);
    mat3 cam = cameraMatrix(ro, ta, shake * gradientNoise(vec2(t * 0.09, 3.1)) * 0.5);
    cu = cam[0];
    cv = cam[1];
    cw = cam[2];
    camPos = ro;
    bdDist = dot(ta, cw) + backdrop_distance * size * fit;
    lampDir = normalize(cw * 1.0 + cu * 0.45 - cv * 0.6);

    int aa = quality >= 3 ? 2 : 1;
    vec4 acc = vec4(0.0);
    for (int j = 0; j < 2; j++) {
        for (int i = 0; i < 2; i++) {
            if (i >= aa || j >= aa)
                continue;
            vec2 o = aa > 1 ? (vec2(float(i), float(j)) - 0.5) * 0.5 + vec2(0.125, -0.125) * (float(j) * 2.0 - 1.0) : vec2(0.0);
            vec2 uv = (2.0 * (fragCoord + o) - iResolution.xy) / iResolution.y;
            acc += render(ro, cameraRay(cam, uv, zoom));
        }
    }
    fragColor = acc / float(aa * aa);
}
