// ---- Relief (#586): the 3D look of a simulation field. The same file is in MaskPhysarum and MaskReaction ----
// The asset's pass H (at the size of the simulation) gives r: height 0..1 (0 = bare ground), g (and b): the place
// between Colour A and Colour B, or what the asset's RL_ALBEDO makes of them, a: glow 0..1. Pass L blurs the height at
// a quarter of the size (occlusion, crevices, thickness) and keeps how long each place has been covered (rl_age_pass),
// pass R lights it at full size in linear light (rl_render) with a micro relief on top (grain, wrinkles along the
// shapes, glints, #892), B1..B3 blur its bright parts (bloom), the main pass adds them, tonemaps and encodes sRGB
// (rl_finish). The camera looks straight down by default, so the picture stays on the mask; Camera tilt marches over
// the height field for a view from the side.
// The asset's lib/common.glsl declares look, material, color_a, color_b and relief_height (their defaults differ),
// and may define RL_ALBEDO, a function vec3 (vec4 of pass H) -> sRGB colour.
// The PBR terms follow the shader-art-coding library (.claude/skills/shader-art-coding, MIT): GGX and Smith after
// Filament, Karis's environment BRDF, Khronos PBR Neutral, AgX after Troy Sobotka and Benjamin Wrensch.

//@slider min=0.0 max=2.0 value=1.0
uniform float gloss;           // 0 matt, 1 the material, 2 mirror smooth
//@slider min=0.0 max=2.0 value=1.0
uniform float subsurface;      // light that enters and comes out deeper coloured; thin parts glow in back light
//@slider min=0.0 max=1.0 value=0.15
uniform float breathe;         // the height swells in slow waves (one every 4 beats)
//@slider min=0.0 max=1.0 value=0.25
uniform float pulse_swell;     // the height swells at a pulse (Pulse every, Trigger)
//@slider min=0.0 max=2.0 value=0.4
uniform float pulse_glow;      // and lights up
//@slider min=0.0 max=2.0 value=0.0
uniform float glow;            // the parts the simulation marks glow by themselves
//@slider min=0.0 max=2.0 value=1.0
uniform float detail;          // the micro relief: grain, wrinkles along the shapes, many small glints
//@slider min=1.0 max=20.0 value=5.0
uniform float detail_size;     // pixels at 1080p: the size of the grain
//@slider min=0.0 max=1.0 value=0.6
uniform float aging;           // parts that stay get a deeper, darker colour; new growth stays light
//@slider min=0.0 max=2.0 value=0.7
uniform float tip_glow;        // new growth (tips, fronts) glows and lets light through
//@slider min=0.0 max=60.0 value=0.0
uniform float camera_tilt;     // degrees: 0 looks straight down (the picture stays on the mask), more shows the relief from the side
//@slider min=0.5 max=3.0 value=1.0
uniform float camera_zoom;
//@slider min=-180.0 max=180.0 value=125.0
uniform float light_angle;     // degrees: where the light comes from, 90 is the top of the picture
//@slider min=5.0 max=90.0 value=38.0
uniform float light_height;    // degrees above the ground: low light makes long shadows
//@rgb value=(1.0, 0.95, 0.88)
uniform vec3 light_color;
//@slider min=0.0 max=6.0 value=1.3
uniform float light_power;
//@slider min=0.0 max=3.0 value=1.0
uniform float environment;     // the reflections of the room (a studio with soft boxes)
//@slider min=0.0 max=3.0 value=0.8
uniform float rim_light;       // a light from behind: bright edges, thin parts shine through
//@rgb value=(0.55, 0.7, 1.0)
uniform vec3 rim_color;
//@slider min=0.0 max=1.0 value=0.85
uniform float shadows;
//@slider min=0.0 max=1.0 value=0.7
uniform float occlusion;       // darker in the creases and on the ground next to the shapes
//@enum options=(Black, Colour, Agar, Transparent) value=0
uniform int ground;            // under the shapes: Black for projection, Agar a lit dish of jelly, Transparent for layers
//@rgb value=(0.62, 0.55, 0.42)
uniform vec3 ground_color;
//@slider min=-4.0 max=4.0 value=0.0
uniform float exposure;        // stops
//@enum options=(Neutral, Filmic AgX) value=0
uniform int tonemap;           // Neutral keeps the colours saturated (Khronos PBR Neutral), AgX rolls bright parts off to white
//@slider min=0.0 max=3.0 value=0.2
uniform float bloom;
//@slider min=0.0 max=4.0 value=1.5
uniform float bloom_threshold;

// ---- PBR terms (shader-art-coding library) ----
vec3 srgbToLinear(vec3 c) {
    c = max(c, 0.0);
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}
vec3 linearToSrgb(vec3 c) {
    c = max(c, 0.0);
    return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}
vec3 tonemapAgX(vec3 c) {
    const mat3 inset = mat3(0.842479062253094, 0.0423282422610123, 0.0423756549057051,
                            0.0784335999999992, 0.878468636469772, 0.0784336,
                            0.0792237451477643, 0.0791661274605434, 0.879142973793104);
    const mat3 outset = mat3(1.19687900512017, -0.0528968517574562, -0.0529716355144438,
                             -0.0980208811401368, 1.15190312990417, -0.0980434501171241,
                             -0.0990297440797205, -0.0989611768448433, 1.15107367264116);
    const float minEv = -12.47393;
    const float maxEv = 4.026069;
    c = inset * max(c, 0.0);
    c = clamp((log2(max(c, 1e-10)) - minEv) / (maxEv - minEv), 0.0, 1.0);
    vec3 x2 = c * c;
    vec3 x4 = x2 * x2;
    c = 15.5 * x4 * x2 - 40.14 * x4 * c + 31.96 * x4 - 6.868 * x2 * c + 0.4298 * x2 + 0.1191 * c - 0.00232;
    c = outset * c;
    return pow(max(c, 0.0), vec3(2.2));
}
vec3 tonemapNeutral(vec3 c) {
    const float startCompression = 0.76;
    const float desaturation = 0.15;
    c = max(c, 0.0);
    float x = min(c.r, min(c.g, c.b));
    float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
    c -= offset;
    float peak = max(c.r, max(c.g, c.b));
    if (peak < startCompression) return c;
    const float d = 1.0 - startCompression;
    float newPeak = 1.0 - d * d / (peak + d - startCompression);
    c *= newPeak / peak;
    float g = 1.0 - 1.0 / (desaturation * (peak - newPeak) + 1.0);
    return mix(c, vec3(newPeak), g);
}
vec3 fresnelSchlick(float u, vec3 f0) {
    float m = clamp(1.0 - u, 0.0, 1.0);
    float m2 = m * m;
    return f0 + (1.0 - f0) * (m2 * m2 * m);
}
float distributionGGX(float NoH, float alpha) {
    float a2 = alpha * alpha;
    float d = NoH * NoH * (a2 - 1.0) + 1.0;
    return a2 / (MP_PI * d * d);
}
float visibilitySmithGGX(float NoV, float NoL, float alpha) {
    float a2 = alpha * alpha;
    float gv = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
    float gl = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
    return 0.5 / max(gv + gl, 1e-6);
}
vec3 specularGGX(vec3 n, vec3 v, vec3 l, float roughness, vec3 f0) {
    vec3 h = normalize(v + l);
    float NoL = clamp(dot(n, l), 0.0, 1.0);
    float NoV = max(dot(n, v), 1e-4);
    float NoH = clamp(dot(n, h), 0.0, 1.0);
    float VoH = clamp(dot(v, h), 0.0, 1.0);
    float alpha = max(roughness, 0.045);
    alpha *= alpha;
    return MP_PI * distributionGGX(NoH, alpha) * visibilitySmithGGX(NoV, NoL, alpha) * fresnelSchlick(VoH, f0) * NoL;
}
vec3 envBRDFApprox(vec3 f0, float NoV, float roughness) {
    vec4 r = roughness * vec4(-1.0, -0.0275, -0.572, 0.022) + vec4(1.0, 0.0425, 1.04, -0.04);
    float a = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
    vec2 ab = vec2(-1.04, 1.04) * a + r.zw;
    return f0 * ab.x + ab.y;
}

// ---- the field ----
float rl_swell = 1.0;    // set by rl_render: the pulse and the breathing

float rl_zscale() { return relief_height / 1080.0; }   // world units (the picture is 1 high) of height 1

// The breathing: slow waves that run over the picture, one every 4 beats
float rl_breath(vec2 uv) {
    if (breathe <= 0.0) return rl_swell;
    float ph = MP_TAU * (iTime * 0.25 - dot(uv, vec2(0.8, 0.5)) * 1.3) + 4.0 * mp_vnoise(uv * 3.0 + 7.0);
    return rl_swell * (1.0 + breathe * 0.45 * sin(ph));
}

// Height 0..1 (bilinear) at a uv of the picture; outside the picture the bare ground
float rl_h(sampler2D H, vec2 uv) {
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 0.0;
    return mp_bilinear_uv(H, uv).r * rl_breath(uv);
}

// Height and its slope (per texel of H) with a cubic B-spline: smooth, without the facets of a bilinear read
vec3 rl_height_grad(sampler2D H, vec2 uv) {
    ivec2 size = textureSize(H, 0);
    vec2 p = uv * vec2(size) - 0.5;
    vec2 f = fract(p);
    ivec2 i0 = ivec2(floor(p)) - 1;
    ivec2 hi = size - 1;
    vec2 f2 = f * f;
    vec2 f3 = f2 * f;
    vec2 g = 1.0 - f;
    vec4 wx = vec4(g.x * g.x * g.x, 3.0 * f3.x - 6.0 * f2.x + 4.0, -3.0 * f3.x + 3.0 * f2.x + 3.0 * f.x + 1.0, f3.x) / 6.0;
    vec4 wy = vec4(g.y * g.y * g.y, 3.0 * f3.y - 6.0 * f2.y + 4.0, -3.0 * f3.y + 3.0 * f2.y + 3.0 * f.y + 1.0, f3.y) / 6.0;
    vec4 dx = vec4(-3.0 * g.x * g.x, 9.0 * f2.x - 12.0 * f.x, -9.0 * f2.x + 6.0 * f.x + 3.0, 3.0 * f2.x) / 6.0;
    vec4 dy = vec4(-3.0 * g.y * g.y, 9.0 * f2.y - 12.0 * f.y, -9.0 * f2.y + 6.0 * f.y + 3.0, 3.0 * f2.y) / 6.0;
    vec3 r = vec3(0.0);
    for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
            float v = texelFetch(H, clamp(i0 + ivec2(x, y), ivec2(0), hi), 0).r;
            r += v * vec3(wx[x] * wy[y], dx[x] * wy[y], wx[x] * dy[y]);
        }
    }
    float b = rl_breath(uv);
    return r * b;
}

// All channels of a pass with a cubic B-spline: smooth edges when a small pass (a mask) is shown at full size
vec4 rl_smooth(sampler2D S, vec2 uv) {
    ivec2 size = textureSize(S, 0);
    vec2 p = uv * vec2(size) - 0.5;
    vec2 f = fract(p);
    ivec2 i0 = ivec2(floor(p)) - 1;
    ivec2 hi = size - 1;
    vec2 f2 = f * f;
    vec2 f3 = f2 * f;
    vec2 g = 1.0 - f;
    vec4 wx = vec4(g.x * g.x * g.x, 3.0 * f3.x - 6.0 * f2.x + 4.0, -3.0 * f3.x + 3.0 * f2.x + 3.0 * f.x + 1.0, f3.x) / 6.0;
    vec4 wy = vec4(g.y * g.y * g.y, 3.0 * f3.y - 6.0 * f2.y + 4.0, -3.0 * f3.y + 3.0 * f2.y + 3.0 * f.y + 1.0, f3.y) / 6.0;
    vec4 r = vec4(0.0);
    for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
            r += texelFetch(S, clamp(i0 + ivec2(x, y), ivec2(0), hi), 0) * (wx[x] * wy[y]);
        }
    }
    return r;
}

// ---- the micro relief (#892) ----
// Value noise and its slope (quintic, after Inigo Quilez): x value 0..1, yz d/dp
vec3 rl_noised(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
    ivec2 c = ivec2(i);
    float a = mp_rand2(c);
    float b = mp_rand2(c + ivec2(1, 0));
    float d = mp_rand2(c + ivec2(0, 1));
    float e = mp_rand2(c + ivec2(1, 1));
    float k = a - b - d + e;
    return vec3(a + (b - a) * u.x + (d - a) * u.y + k * u.x * u.y, du * (vec2(b - a, d - a) + k * u.yx));
}

// Round grains on a jittered grid: x height 0..1, yz d/dp
vec3 rl_grain(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec3 r = vec3(0.0);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 o = vec2(float(x), float(y));
            ivec2 c = ivec2(i + o);
            vec2 d = o + 0.15 + 0.7 * vec2(mp_rand2(c), mp_rand2(c + ivec2(101, 37))) - f;
            float rad = 0.32 + 0.3 * mp_rand2(c + ivec2(7, 91));
            float q = dot(d, d) / (rad * rad);
            if (q < 1.0) {
                float w = 1.0 - q;
                r += vec3(w * w, 4.0 * w * d / (rad * rad));
            }
        }
    }
    return r;
}

// Pass L (a quarter of the size): x the height blurred about 25 pixels wide at 1080p (occlusion, thickness), y about
// 6 pixels wide (crevices, contact shadows), z age * cover (z / w is how long the place has been covered: 0 new growth,
// 1 after about Aging time), w cover. last: the pass's own last frame
vec4 rl_age_pass(sampler2D H, sampler2D last, vec2 fragCoord) {
    vec2 hp = fragCoord / iResolution.xy * vec2(textureSize(H, 0));
    float s = float(textureSize(H, 0).y) / 540.0;
    float sum = 0.0;
    float ws = 0.0;
    float near = 0.0;
    float wn = 0.0;
    for (int y = -3; y <= 3; y++) {
        for (int x = -3; x <= 3; x++) {
            vec2 o = vec2(float(x), float(y)) * 2.0 * s;
            float hv = mp_bilinear(H, hp + o).r;
            float w = exp(-dot(o, o) / (36.0 * s * s));
            sum += hv * w;
            ws += w;
            if (abs(x) <= 1 && abs(y) <= 1) {
                float w2 = exp(-dot(o, o) / (4.0 * s * s));
                near += hv * w2;
                wn += w2;
            }
        }
    }
    near /= wn;
    float cover = smoothstep(0.06, 0.3, near);
    ivec2 p = ivec2(fragCoord);
    bool fresh = iFrame < 2 || textureSize(last, 0) != ivec2(iResolution.xy);
    vec4 l = fresh ? vec4(0.0) : texelFetch(last, p, 0);
    float age = l.w > 0.01 ? l.z / l.w : 0.0;
    age = cover > l.w + 0.02 && l.w < 0.3 ? 0.0 : age;   // newly covered: young
    age += (1.0 - age) * (1.0 - exp(-max(iTimeDelta, 0.0) / 6.0));
    return vec4(sum / ws, near, age * cover, cover);
}

// ---- the room ----
vec3 rl_light_dir() {
    float az = radians(light_angle);
    float el = radians(light_height);
    return vec3(cos(el) * cos(az), cos(el) * sin(az), sin(el));
}
vec3 rl_rim_dir() {
    float az = radians(light_angle + 180.0);
    return normalize(vec3(cos(az), sin(az), 0.35));
}

// The studio the shapes reflect: dark floor, a grey ceiling, a soft box where the key light is, a strip for the rim
vec3 rl_env(vec3 d) {
    vec3 c = mix(vec3(0.015, 0.015, 0.018), vec3(0.22, 0.23, 0.25), smoothstep(-0.2, 0.9, d.z));
    vec3 ld = rl_light_dir();
    c += srgbToLinear(light_color) * light_power * 22.0 * smoothstep(0.955, 0.985, dot(d, ld));   // small and bright: wet highlights
    c += srgbToLinear(light_color) * 0.35 * smoothstep(0.55, 0.75, dot(d, normalize(vec3(-ld.y, ld.x, 1.2))));
    c += srgbToLinear(rim_color) * rim_light * 0.5 * smoothstep(0.86, 0.95, dot(d, rl_rim_dir()));
    // a ring light above the camera: a bright line along the crest of every round shape (#892)
    c += srgbToLinear(light_color) * light_power * 1.6 * smoothstep(0.972, 0.99, d.z) * (1.0 - smoothstep(0.996, 0.9995, d.z));
    return c;
}
vec3 rl_env_diffuse(vec3 n) {
    return mix(vec3(0.01), vec3(0.12, 0.125, 0.135), 0.5 + 0.5 * n.z) + srgbToLinear(light_color) * 0.04 * light_power;
}

vec3 rl_ground_albedo(vec2 uv, float aspect) {
    if (ground == 0 || ground == 3) return vec3(0.0);
    vec3 g = srgbToLinear(ground_color);
    if (ground == 2) {
        // agar: a gel with soft clouds in it and a few bubbles
        vec2 q = uv * vec2(aspect, 1.0);
        float n = mp_vnoise(q * 9.0) * 0.6 + mp_vnoise(q * 31.0) * 0.3 + mp_vnoise(q * 90.0) * 0.1;
        g *= 0.78 + 0.4 * n;
        vec2 d = (uv - 0.5) * vec2(aspect, 1.0);
        g *= 1.0 - 0.35 * smoothstep(0.35, 0.95, length(d));
    }
    return g;
}

// ---- the materials ----
struct RlMat {
    float rough;
    float metal;
    float coat;     // a wet clear layer on top
    float sss;
    float glass;
};

RlMat rl_material() {
    RlMat m;
    m.rough = 0.4;
    m.metal = 0.0;
    m.coat = 0.0;
    m.sss = 0.0;
    m.glass = 0.0;
    if (material == 0) { m.rough = 0.38; m.coat = 1.0; m.sss = 1.0; }          // wet slime
    else if (material == 1) { m.rough = 0.5; m.coat = 0.15; m.sss = 0.85; }    // wax
    else if (material == 2) { m.rough = 0.28; m.metal = 1.0; }                 // gold (the colours are the metal)
    else if (material == 3) { m.rough = 0.08; m.metal = 1.0; }                 // chrome
    else if (material == 4) { m.rough = 0.04; m.coat = 1.0; m.sss = 0.4; m.glass = 1.0; }   // glass jelly
    else { m.rough = 0.25; m.coat = 0.6; }                                     // ceramic
    m.rough = clamp(m.rough * (2.0 - gloss), 0.03, 1.0);
    m.sss *= subsurface;
    return m;
}

// The camera: the uv of the picture where the ray of this pixel meets the relief, and the direction to the eye
vec2 rl_view(sampler2D H, vec2 uv, float aspect, out vec3 V) {
    float th = radians(clamp(camera_tilt, 0.0, 80.0));
    vec3 d = vec3(0.0, sin(th), -cos(th));
    V = -d;
    vec2 s = (uv - 0.5) * vec2(aspect, 1.0) / max(camera_zoom, 0.05);
    if (th < 1e-3) return vec2(s.x / aspect, s.y) + 0.5;
    vec3 up = vec3(0.0, cos(th), sin(th));
    vec3 o = vec3(aspect * 0.5 + s.x, 0.5, 0.0) + up * s.y;
    float zs = rl_zscale();
    float zmax = zs * (1.0 + pulse_swell + breathe * 0.5) * 1.05 + 1e-5;
    float ct = cos(th);
    float t0 = (o.z - zmax) / ct;
    float t1 = o.z / ct;
    float tp = t0;
    float t = t1;
    for (int i = 1; i <= 40; i++) {
        float tc = mix(t0, t1, float(i) / 40.0);
        vec3 p = o + d * tc;
        if (p.z <= rl_h(H, vec2(p.x / aspect, p.y)) * zs) {
            // between tp (above) and tc (below): halve the interval
            float a = tp;
            float b = tc;
            for (int k = 0; k < 6; k++) {
                float m = 0.5 * (a + b);
                vec3 q = o + d * m;
                if (q.z <= rl_h(H, vec2(q.x / aspect, q.y)) * zs) b = m;
                else a = m;
            }
            t = b;
            break;
        }
        tp = tc;
    }
    vec3 p = o + d * t;
    return vec2(p.x / aspect, p.y);
}

// The uv of the picture on the ground (height 0) under this pixel: where the camera puts the mask
vec2 rl_ground_uv(vec2 uv) {
    float aspect = iResolution.x / iResolution.y;
    float th = radians(clamp(camera_tilt, 0.0, 80.0));
    vec2 s = (uv - 0.5) * vec2(aspect, 1.0) / max(camera_zoom, 0.05);
    vec3 up = vec3(0.0, cos(th), sin(th));
    vec3 o = vec3(aspect * 0.5 + s.x, 0.5, 0.0) + up * s.y;
    vec3 p = o + vec3(0.0, sin(th), -cos(th)) * (o.z / cos(th));
    return vec2(p.x / aspect, p.y);
}

// Soft shadow: march from p (world) towards the light over the height field
float rl_shadow(sampler2D H, vec3 p, vec3 ld, float aspect) {
    float zs = rl_zscale();
    if (zs <= 0.0 || shadows <= 0.0) return 1.0;
    float top = zs * (1.0 + pulse_swell + breathe * 0.5);
    float dist = max(top - p.z, 0.0) / max(ld.z, 0.06);
    float res = 1.0;
    for (int i = 1; i <= 16; i++) {
        float t = dist * (float(i) - 0.5) / 16.0;
        vec3 q = p + ld * t;
        float hz = rl_h(H, vec2(q.x / aspect, q.y)) * zs;
        res = min(res, clamp(6.0 * (q.z - hz) / max(t, 1e-5) + 0.5, 0.0, 1.0));
    }
    res = res * res * (3.0 - 2.0 * res);
    return mix(1.0, res, shadows);
}

vec2 rl_hit = vec2(0.0);   // set by rl_render: the uv of the picture this pixel shows (where the view meets the relief)

// The lit picture in linear light (rgb) and how much of it is shape (a). pulse: mp_pulse(T)
vec4 rl_render(sampler2D H, sampler2D L, vec3 pulse, vec2 fragCoord) {
    vec2 uv0 = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    rl_swell = 1.0 + pulse.x * pulse_swell;
    vec3 V;
    vec2 uv = rl_view(H, uv0, aspect, V);
    rl_hit = uv;
    bool inside = uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
    vec4 hf = inside ? mp_bilinear_uv(H, uv) : vec4(0.0);
    vec3 hg = inside ? rl_height_grad(H, uv) : vec3(0.0);
    float h = max(hg.x, 0.0);
    vec4 lf = inside ? mp_bilinear_uv(L, uv) : vec4(0.0);
    float hb = lf.x * rl_breath(uv);
    float hn = lf.y * rl_breath(uv);
#ifdef RL_ALBEDO
    vec3 alb = srgbToLinear(RL_ALBEDO(hf));
#else
    vec3 alb = srgbToLinear(mix(color_a, color_b, clamp(hf.g, 0.0, 1.0)));
#endif
    vec3 galb = rl_ground_albedo(uv, aspect);
    float cov = smoothstep(0.015, 0.09, h);
    float pg = pulse.x * pulse_glow;
    // age: new growth is light and glows (Tip glow), what stays gets a deeper, darker colour (Aging)
    float age = lf.w > 0.02 ? clamp(lf.z / lf.w, 0.0, 1.0) : 0.0;
    float young = (1.0 - age) * cov;
    alb = mix(alb, mix(mix(alb, vec3(1.0), 0.12), pow(max(alb, vec3(1e-4)), vec3(1.45)) * 0.78, age), aging);

    if (look == 1) {
        // Classic flat: the colours as they are, brighter where it is thick
        vec3 c = mix(galb, alb, smoothstep(0.0, 0.3, h));
        c = mix(c, alb * 1.6 + 0.08, smoothstep(0.55, 1.0, h) * 0.5);
        c *= 1.0 + pg;
        c += alb * (hf.a * glow * 2.0 + young * tip_glow * 0.5);
        return vec4(c, max(cov, ground == 3 ? 0.0 : 1.0));
    }
    if (look == 2) {
        // Glow: the field lights up, the thick parts most
        vec3 c = galb * 0.3 + alb * pow(h, 1.3) * 2.5 * (1.0 + pg) + alb * (hf.a * glow * 3.0 + young * tip_glow);
        return vec4(c, max(cov, ground == 3 ? 0.0 : 1.0));
    }

    // Photoreal
    ivec2 hs = textureSize(H, 0);
    float zs = rl_zscale();
    vec2 slope = hg.yz * vec2(float(hs.x) / aspect, float(hs.y)) * zs;
    vec3 n = normalize(vec3(-slope, 1.0));
    // the micro relief (#892), on the shape only: wrinkles along it (rings of the height, spaced evenly across a
    // round vein), noise and grains. It bends the normal of the glints and reflections (nm) and a little of the light
    vec3 nm = n;
    if (detail > 0.0 && cov > 0.0) {
        vec2 wp = vec2(uv.x * aspect, uv.y) * 1080.0 / max(detail_size, 1.0);
        vec3 n1 = rl_noised(wp * 0.45);
        vec3 n2 = rl_noised(wp * 1.7 + 31.0);
        vec3 gr = rl_grain(wp * 0.9 + 5.3);
        float on = smoothstep(0.04, 0.3, h) * detail;
        float xr = sqrt(max(1.0 - h * h, 0.0));
        float wr = 1.0 - 0.3 * detail * cos(xr * 11.0 + 3.0 * n1.x) * min(h / max(xr, 0.3), 2.5);
        vec2 ms = on * (0.1 * n1.yz + 0.09 * n2.yz + 0.06 * gr.yz);
        nm = normalize(vec3(-(slope * wr + ms), 1.0));
        n = normalize(mix(n, nm, 0.35));
        alb *= 1.0 + on * (0.12 * (n1.x - 0.5) + 0.06 * gr.x);   // mottled
    }
    vec3 p = vec3(uv.x * aspect, uv.y, h * zs);
    vec3 ld = rl_light_dir();
    vec3 lr = rl_rim_dir();
    vec3 lc = srgbToLinear(light_color) * light_power;
    vec3 rc = srgbToLinear(rim_color) * rim_light;
    float sh = rl_shadow(H, p + vec3(0.0, 0.0, zs * 0.02), ld, aspect);

    // the ground: lit, in the shadow of the shapes, darker next to them (wide) and right at their foot (narrow)
    float gao = (1.0 - occlusion * clamp(hb * 1.6, 0.0, 0.85)) * (1.0 - occlusion * clamp(hn * 2.5, 0.0, 0.7));
    vec3 gcol = galb * (lc * max(ld.z, 0.0) * sh + rl_env_diffuse(vec3(0.0, 0.0, 1.0))) * gao;

    // the shape
    RlMat m = rl_material();
    float thick = clamp(mix(h, hb, 0.4) * 1.3, 0.0, 1.0);
    float NoV = max(dot(n, V), 1e-3);
    // occlusion: wide (between the veins) and the crevices (lower than its close surroundings: forks, the foot)
    float cav = clamp((hn - h) * 3.0, 0.0, 1.0);
    float ao = (1.0 - occlusion * clamp((hb - h) * 2.2, 0.0, 0.8)) * (1.0 - occlusion * 0.85 * cav);
    vec3 f0 = mix(vec3(0.04), alb, m.metal);
    // light that went in deep comes out in a deeper colour
    vec3 deep = pow(max(alb, vec3(1e-4)), vec3(1.0 + 0.7 * thick * min(m.sss, 1.5)));
    vec3 dalb = mix(alb, deep, clamp(m.sss, 0.0, 1.0)) * (1.0 - m.metal);
    float w = 0.35 * m.sss;
    float diff = max((dot(n, ld) + w) / (1.0 + w), 0.0);
    vec3 c = vec3(0.0);
    float NoVm = max(dot(nm, V), 1e-3);
    vec3 fr = fresnelSchlick(NoVm, f0);
    if (m.glass > 0.5) {
        // jelly: the ground seen through it (bent by the surface), tinted by the thickness, plus a little scattering
        vec2 bent = uv - nm.xy * zs * 6.0 * (0.5 + thick);
        vec3 seen = rl_ground_albedo(bent, aspect) * (lc * max(ld.z, 0.0) + rl_env_diffuse(vec3(0.0, 0.0, 1.0)));
        vec3 tint = exp(-(1.0 - alb) * thick * 5.0);
        c += seen * tint * (1.0 - fr);
        c += alb * thick * 0.25 * (lc * diff * sh + rl_env_diffuse(n)) * m.sss;
    } else {
        c += dalb * diff * lc * sh * mix(1.0, ao, 0.6);
        c += dalb * rl_env_diffuse(n) * ao * environment;
    }
    c += specularGGX(nm, V, ld, m.rough, f0) * lc * sh * mix(1.0, ao, 0.5);
    vec3 rr = reflect(-V, nm);
    c += rl_env(rr) * envBRDFApprox(f0, NoVm, m.rough) * environment * ao;
    if (m.coat > 0.0) {
        float fc = fresnelSchlick(NoVm, vec3(0.04)).x * m.coat;
        c = c * (1.0 - fc) + rl_env(rr) * fc * environment * ao;
        c += specularGGX(nm, V, ld, 0.045, vec3(0.04)) * lc * sh * m.coat * ao;
    }
    // the light from behind: shines through thin parts and new growth, lines the edges
    vec3 th = normalize(lr + n * 0.45);
    float trans = pow(clamp(dot(V, -th), 0.0, 1.0), 3.0) + 0.25 * pow(1.0 - NoV, 2.0);
    c += rc * alb * trans * exp(-thick * 3.0) * m.sss * 1.6 * (1.0 + 2.0 * young * tip_glow);
    c += rc * pow(1.0 - NoV, 4.0) * mix(0.25, 1.0, m.metal) * (0.3 + 0.7 * m.coat + m.metal);
    // scattering that lights the shape from inside where it is thin and the ground is lit
    c += alb * m.sss * 0.12 * exp(-thick * 2.0) * lc * max(ld.z, 0.0) * sh;
    // glow: the simulation's, new growth, the pulse
    c += alb * (hf.a * glow * 2.0 + young * tip_glow * (0.25 + 0.5 * exp(-thick * 2.0)) + pg * (0.4 + h));

    vec3 rgb = mix(gcol, c, cov);
    float a = ground == 3 ? cov : 1.0;
    return vec4(rgb, a);
}

// ---- bloom (passes B1, B2, B3) ----
// B1: a quarter of R, only what is brighter than the threshold
vec4 rl_bloom_down(sampler2D R, ivec2 p) {
    ivec2 rs = textureSize(R, 0);
    ivec2 hi = rs - 1;
    vec2 scale = vec2(rs) / iResolution.xy;
    ivec2 base = ivec2(vec2(p) * scale);
    vec3 sum = vec3(0.0);
    for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
            sum += texelFetch(R, clamp(base + ivec2(x, y), ivec2(0), hi), 0).rgb;
        }
    }
    vec3 c = sum / 16.0 * exp2(exposure);
    float l = max(c.r, max(c.g, c.b));
    float k = max(l - bloom_threshold, 0.0);
    k = k * k / (k + 0.5 + 1e-4);
    return vec4(c * k / max(l, 1e-4), 1.0);
}

// B2 / B3: a Gaussian along dir (texels)
vec4 rl_blur(sampler2D S, ivec2 p, ivec2 dir) {
    ivec2 hi = textureSize(S, 0) - 1;
    vec3 sum = vec3(0.0);
    float ws = 0.0;
    for (int i = -8; i <= 8; i++) {
        float w = exp(-float(i * i) / 18.0);
        sum += texelFetch(S, clamp(p + dir * i, ivec2(0), hi), 0).rgb * w;
        ws += w;
    }
    return vec4(sum / ws, 1.0);
}

// The main pass: exposure, bloom, tonemap, sRGB, a dither against bands
vec3 rl_finish(vec3 lin, vec3 bl, vec2 fragCoord) {
    vec3 c = lin * exp2(exposure) + bl * bloom;
    if (look == 0) c = tonemap == 1 ? tonemapAgX(c * 1.2) : tonemapNeutral(c);
    else c = c / (1.0 + max(c - 1.0, 0.0));
    c = linearToSrgb(c);
    float d = mp_rand(mp_hash(uint(fragCoord.x) * 1973u + uint(fragCoord.y) * 9277u + uint(iFrame) * 26699u));
    return c + (d - 0.5) / 255.0;
}
