//@settings dtype=float16 format=rgba
// --- pass A: the wax and the liquid in linear light, over the whole picture. The drops are metaballs (a field that
// is 1 on the skin of a drop and adds up where drops meet, so they melt together and tear apart smoothly); the field
// also gives each blob a rounded height, its normal and its thickness. The wax is lit from below and from inside
// (subsurface scattering from the thickness: thin rims glow, thick cores are deep), hot wax glows by itself, the skin
// is glossy. A second, darker layer swims behind. Alpha is the cover of the wax. ---
#include lib/common.glsl

uniform sampler2D S;
uniform sampler2D L;

//@enum options=(Colours, Magma, Ocean, Toxic, Ultraviolet, Rainbow) value=0
uniform int palette;                // Colours: Wax color, Hot color and Liquid color below; the others are ready sets
//@rgb value=(1.0, 0.28, 0.06)
uniform vec3 wax_color;
//@rgb value=(1.0, 0.75, 0.2)
uniform vec3 hot_color;             // the colour of the hottest wax near the lamp
//@slider min=0.0 max=4.0 value=1.0
uniform float glow;                 // how much the wax lights up from inside
//@slider min=0.0 max=12.0 value=4.0
uniform float wax_density;          // high: only the thin rims let the light through, the cores are deep
//@rgb value=(0.35, 0.12, 0.55)
uniform vec3 liquid_color;
//@slider min=0.0 max=2.0 value=0.9
uniform float liquid_glow;          // the liquid catches the light of the lamp and of the wax
//@slider min=0.0 max=10.0 value=3.0
uniform float lamp_power;           // the lamp under the picture: lights the wax from below
//@slider min=0.0 max=1.0 value=0.35
uniform float pool;                 // the molten wax lying on the bottom, the drops rise out of it (0: none)
//@slider min=0.0 max=1.0 value=0.35
uniform float surface_wobble;       // the drops ripple (more with the highs)
//@slider min=0.0 max=4.0 value=1.0
uniform float environment_brightness;   // the glossy highlights on the wax
//@rgb value=(0.55, 0.65, 1.0)
uniform vec3 room_light;            // the colour of the light the glossy skin mirrors
//@slider min=0.0 max=1.0 value=0.5
uniform float depth;                // how much the back layer of drops shows
//@enum options=(Final, Normals, Thickness, Temperature) value=0
uniform int debug_mode;

vec4 BP[MAXBLOBS];      // the drops: x, y, -, temperature (x already stretched to the picture)
vec2 BV[MAXBLOBS];      // velocity
int nBlobs;
float wobbleNow;
float pulseNow;
float tNow;
float poolTop;          // the height of the pool's surface
bool rainbow;
vec3 haloColor;         // the colour of the wax nearest to the pixel (Rainbow), for its glow in the liquid

// One drop at p: the field (1 on its skin) and its weight for the colour; stretched along its velocity
float dropField(vec2 p, int i, float support) {
    vec2 c = BP[i].xy;
    vec2 v = BV[i];
    float r = blobRadius(i);
    float sp = length(v);
    float st = 1.0 + clamp(sp * 2.0, 0.0, 0.5);
    vec2 ax = sp > 1e-4 ? v / sp : vec2(0.0, 1.0);
    vec2 q = p - c;
    float along = dot(q, ax);
    vec2 perp = q - ax * along;
    vec2 sq = perp * sqrt(st) + ax * along / st;
    float R = r * support;
    float k = 1.0 - dot(sq, sq) / (R * R);
    if (k <= 0.0)
        return 0.0;
    float k0 = 1.0 - 1.0 / (support * support);
    return k * k * k / (k0 * k0 * k0);
}

vec3 hueColor(float h) {
    return clamp(abs(fract(h + vec3(0.0, 2.0, 1.0) / 3.0) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

// The field of one layer at p: x the field, y the temperature, and the Rainbow colour in rgb of col
vec2 field(vec2 p, bool back, out vec3 col) {
    float support = 1.45 + 1.1 * merge;
    float F = 0.0, Tw = 0.0, cw = 0.0;
    col = vec3(0.0);
    for (int i = 0; i < MAXBLOBS; i++) {
        if (i >= nBlobs)
            break;
        if (isBack(i) != back)
            continue;
        float k = dropField(p, i, support);
        if (k <= 0.0)
            continue;
        F += k;
        Tw += k * BP[i].w;
        if (rainbow) {
            // the colours of drops that melt together blend over a wide band
            float kc = sqrt(k);
            col += kc * hueColor(fract(float(i) * 0.618034 + tNow / 64.0));
            cw += kc;
        }
    }
    // the pool: a long drop lying on the bottom, its surface waving slowly
    if (!back && pool > 0.0) {
        float rp = 0.3;
        float wave = 0.035 * sin(p.x * 3.1 + tNow * 0.35) + 0.025 * sin(p.x * 7.3 - tNow * 0.6);
        float d = max(p.y - (poolTop + wave - rp), 0.0);
        float R = rp * support;
        float k = 1.0 - d * d / (R * R);
        if (k > 0.0) {
            float k0 = 1.0 - 1.0 / (support * support);
            k = k * k * k / (k0 * k0 * k0);
            F += k;
            Tw += k * 0.72;
            if (rainbow) {
                col += sqrt(k) * hueColor(fract(tNow / 64.0 + 0.5));
                cw += sqrt(k);
            }
        }
    }
    float T = F > 0.0 ? Tw / F : 0.0;
    if (rainbow && cw > 0.0)
        col /= cw;
    // ripples on the skin
    F += wobbleNow * 0.18 * gradientNoise(vec3(p * 5.0, tNow * 0.5)) * smoothstep(0.2, 0.9, F);
    return vec2(F, T);
}

// The height of the wax over the field: a round dome, steep at the skin
float heightOf(float F) {
    return sqrt(1.0 - exp(-max(F - 1.0, 0.0) * 1.6));
}

// The light of the lamp under the picture at the height y
float lampLight(float y) {
    float h = (y + 1.15) * 0.8;
    return lamp_power * pulseNow * (0.12 + 0.88 / (1.0 + 2.5 * h * h));
}

void palettes(out vec3 wc, out vec3 hc, out vec3 lc) {
    wc = wax_color;
    hc = hot_color;
    lc = liquid_color;
    if (palette == 1) {
        wc = vec3(0.85, 0.1, 0.02);
        hc = vec3(1.0, 0.55, 0.08);
        lc = vec3(0.12, 0.02, 0.01);
    } else if (palette == 2) {
        wc = vec3(0.05, 0.5, 1.0);
        hc = vec3(0.55, 1.0, 0.95);
        lc = vec3(0.02, 0.06, 0.28);
    } else if (palette == 3) {
        wc = vec3(0.35, 1.0, 0.05);
        hc = vec3(0.95, 1.0, 0.35);
        lc = vec3(0.16, 0.03, 0.3);
    } else if (palette == 4) {
        wc = vec3(0.7, 0.12, 1.0);
        hc = vec3(1.0, 0.45, 0.85);
        lc = vec3(0.03, 0.03, 0.22);
    } else if (palette == 5) {
        hc = vec3(1.0, 0.95, 0.85);
        lc = vec3(0.05, 0.04, 0.08);
    }
    wc = srgbToLinear(wc);
    hc = srgbToLinear(hc);
    lc = srgbToLinear(lc);
}

// One layer of wax at p: rgb the lit wax, a its cover; px the size of a pixel. info: thickness, temperature, field
vec4 shadeLayer(vec2 p, float px, bool back, vec3 wc, vec3 hc, out vec3 info, out vec3 nOut) {
    vec3 rc;
    vec2 f = field(p, back, rc);
    float e = px * 1.5;
    vec3 dummy;
    float fx = field(p + vec2(e, 0.0), back, dummy).x;
    float fy = field(p + vec2(0.0, e), back, dummy).x;
    vec2 g = vec2(fx - f.x, fy - f.x) / e;
    // the skin, antialiased over a pixel (wider for the blurred back layer)
    float soft = back ? 6.0 : 1.0;
    float cover = clamp((f.x - 1.0) / max(length(g) * px * soft, 1e-4) + 0.5, 0.0, 1.0);
    info = vec3(0.0, f.y, f.x);
    nOut = vec3(0.0, 0.0, 1.0);
    if (rainbow) {
        wc = srgbToLinear(mix(rc, vec3(1.0), 0.08));
        if (!back && f.x > 0.0)
            haloColor = wc;
    }
    if (cover <= 0.0)
        return vec4(0.0);
    float h = heightOf(f.x);
    float hx = heightOf(fx), hy = heightOf(fy);
    float slope = 0.16 * blob_size;
    vec3 n = normalize(vec3(-(hx - h) / e * slope, -(hy - h) / e * slope, 1.0));
    nOut = n;
    float thick = h;
    info.x = thick;
    float T = f.y;
    float lamp = lampLight(p.y);
    // light through the wax: from the lamp below and from inside; red passes further than blue (the colour deepens)
    vec3 ext = (1.15 - wc * 0.85) * wax_density;
    vec3 trans = exp(-ext * (0.03 + thick * 0.45));
    vec3 lb = normalize(vec3(0.0, -0.8, 0.6));
    float under = wrapDiffuse(n, lb, 0.7);
    vec3 col = wc * lamp * glow * (trans * (0.35 + 1.0 * under) + 0.03);
    // the thin rim lets the most light through: it glows warmer
    float rim = pow(1.0 - h, 3.0);
    col += mix(wc, hc, 0.35) * lamp * glow * rim * 0.35 * (0.4 + under);
    // hot wax glows by itself, from its whole depth
    col += hc * smoothstep(0.45, 1.1, T) * glow * pulseNow * (1.0 - exp(-thick * 3.0)) * 0.8 * (0.45 + 0.55 * under);
    // the glossy skin: a soft light from the top left and the rim
    vec3 v = vec3(0.0, 0.0, 1.0);
    vec3 lk = normalize(vec3(-0.5, 0.7, 0.55));
    vec3 rl = srgbToLinear(room_light) * environment_brightness;
    col += rl * (specularGGX(n, v, lk, 0.3, vec3(0.03)) * 0.9 + fresnelSchlick(max(n.z, 0.0), vec3(0.03)) * 0.12);
    col += wc * lamp * 0.25 * specularGGX(n, v, lb, 0.35, vec3(0.03));
    if (back)
        col *= 0.45;
    return vec4(col, cover);
}

vec4 render(vec2 p, float px) {
    vec3 wc, hc, lc;
    palettes(wc, hc, lc);
    vec3 info, infoB;
    vec3 n, nB;
    haloColor = wc;
    vec4 f = shadeLayer(p, px, false, wc, hc, info, n);
    // the liquid: tinted, lit by the lamp from below and by the glowing wax in it
    float lamp = lampLight(p.y);
    vec3 col = lc * liquid_glow * (0.03 + 0.12 * lamp);
    col += mix(haloColor, lc, 0.4) * liquid_glow * glow * lamp * 0.12 * smoothstep(0.1, 1.0, info.z);
    vec4 b = vec4(0.0);
    if (depth > 0.0 && quality >= 2 && f.a < 1.0) {
        b = shadeLayer(p * 1.08 + vec2(0.0, 0.03), px * 1.08, true, wc, hc, infoB, nB);
        // the back layer is seen through more of the liquid
        b.rgb = mix(b.rgb, lc * lamp * 0.2, 0.2);
        col = mix(col, b.rgb, b.a * depth);
    }
    col = mix(col, f.rgb, f.a);
    float cover = max(f.a, b.a * depth);
    if (debug_mode == 1)
        col = f.a > 0.0 ? debugNormal(n) : vec3(0.0);
    if (debug_mode == 2)
        col = vec3(info.x * f.a);
    if (debug_mode == 3)
        col = debugHeat(clamp(max(info.y, 0.0), 0.0, 1.0)) * max(f.a, 0.15);
    if (background_mode != 0)
        col = mix(vec3(0.0), col, cover);
    return vec4(col, cover);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 lv = texelFetch(S, ivec2(ST_LEVELS, 0), 0);
    vec4 bt = texelFetch(S, ivec2(ST_BEAT, 0), 0);
    vec4 sp = texelFetch(S, ivec2(ST_SPRING, 0), 0);
    float aspect = iResolution.x / iResolution.y;
    nBlobs = clamp(blobs, 1, MAXBLOBS);
    for (int i = 0; i < MAXBLOBS; i++) {
        BP[i] = texelFetch(L, ivec2(i, 0), 0);
        BV[i] = texelFetch(L, ivec2(i, 1), 0).xy;
        BP[i].x *= aspect / SIM_ASPECT;
        BV[i].x *= aspect / SIM_ASPECT;
    }
    tNow = iTime;
    rainbow = palette == 5;
    wobbleNow = surface_wobble * (0.3 + 2.0 * lv.z * react);
    pulseNow = 1.0 + 0.5 * react * clamp(sp.x, 0.0, 1.5);
    poolTop = -1.0 + pool * 0.32;
    float g = glitchAmount(bt);
    float shatter = (glitchKindFor(bt.z + floor(iTime * 2.0) * 0.37) == 4) ? g : 0.0;
    float shatterSeed = fract(bt.z + floor(iTime * 4.0) * 0.1234567);

    float px = 2.0 / iResolution.y;
    int aa = quality >= 3 ? 2 : 1;
    vec4 acc = vec4(0.0);
    for (int j = 0; j < 2; j++) {
        for (int i = 0; i < 2; i++) {
            if (i >= aa || j >= aa)
                continue;
            vec2 o = aa > 1 ? (vec2(float(i), float(j)) - 0.5) * 0.5 + vec2(0.125, -0.125) * (float(j) * 2.0 - 1.0) : vec2(0.0);
            vec2 p = (2.0 * (fragCoord + o) - iResolution.xy) / iResolution.y;
            if (shatter > 0.001) {
                // the wax cut into blocks that jump apart
                vec2 id = floor(p / 0.22);
                vec2 h = hash22(id + floor(shatterSeed * 97.0));
                p += (h - 0.5) * 0.12 * shatter;
            }
            acc += render(p, px);
        }
    }
    fragColor = acc / float(aa * aa);
}
