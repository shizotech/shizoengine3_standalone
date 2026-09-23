//@settings dtype=float32 format=rgba
// ---------------------------------------------------------------------------
// BassMetaball
// Raymarched metaball blob: several soft spheres whose radii and positions
// react to bass / low-mid spectrum energy and merge via smooth-min SDF.
// The whole blob inflates on the beat and morphs per bar. Fresnel rim glow +
// spectral shading + volumetric fog. iTime is measured in BEATS (1.0=one beat).
// ---------------------------------------------------------------------------

uniform sampler2D AUDIO;   // spectrum row (y=0.0)

//@slider min=0.5 max=8.0 value=3.0
uniform float sensitivity;       // bass energy gain

//@slider min=0.0 max=1.0 value=0.6
uniform float bass_react;        // how much bass inflates the blob

//@slider min=0.05 max=0.6 value=0.35
uniform float smooth_k;          // metaball blend smoothness

//@slider min=0.1 max=0.7 value=0.4
uniform float orbit;             // satellite ball orbit radius

//@slider min=0.0 max=3.0 value=1.0
uniform float spin_speed;        // blob rotation per beat

//@slider min=0.05 max=0.6 value=0.22
uniform float surface_glow;      // fresnel rim intensity

//@slider min=0.2 max=4.0 value=1.6
uniform float fog_density;       // volumetric glow density

//@rgb value=(0.2,0.5,1.0)
uniform vec3 base_color;

//@rgb value=(1.0,0.3,0.6)
uniform vec3 hot_color;          // hue pushed by treble energy

//@slider min=0.0 max=1.0 value=0.0
uniform float background_mix;    // faint beat-reactive background wash

const int MAX_STEPS = 72;

float clamp01(float v){ return clamp(v, 0.0, 1.0); }

// smooth minimum for metaball union
float smin(float a, float b, float k){
    float h = clamp(0.5 + 0.5*(b-a)/max(k,1e-4), 0.0, 1.0);
    return mix(b, a, h) - k*h*(1.0-h);
}

// Metaball field built in a rotated space. Returns combined SDF distance.
float map(vec3 p, float bass, float lowmid, float mid, float inflate, float spin, float k){
    float coreR = 0.75 + inflate * 0.9 + 0.15 * sin(spin);
    float d = length(p) - coreR;

    // four orbiting satellites, radii driven by bands
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float a = spin + fi * 1.5707963;
        float band = mix(bass, mid, fi / 3.0);
        float rr = 0.22 + 0.45 * band + 0.1 * bass_react;
        float hgt = 0.25 * sin(spin * 1.5 + fi);
        vec3 c = vec3(cos(a) * orbit, hgt, sin(a) * orbit);
        float ds = length(p - c) - rr;
        d = smin(d, ds, k);
    }
    // subtle surface ripple from low-mids
    d -= 0.06 * lowmid * sin(p.x * 6.0 + spin) * sin(p.y * 6.0 - spin) * sin(p.z * 6.0 + spin * 0.5);
    return d;
}

vec3 calcNormal(vec3 p, float bass, float lowmid, float mid, float inflate, float spin, float k){
    float e = 0.005;
    return normalize(vec3(
        map(p + vec3(e,0,0), bass, lowmid, mid, inflate, spin, k) - map(p - vec3(e,0,0), bass, lowmid, mid, inflate, spin, k),
        map(p + vec3(0,e,0), bass, lowmid, mid, inflate, spin, k) - map(p - vec3(0,e,0), bass, lowmid, mid, inflate, spin, k),
        map(p + vec3(0,0,e), bass, lowmid, mid, inflate, spin, k) - map(p - vec3(0,0,e), bass, lowmid, mid, inflate, spin, k)
    ));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // ---- beat machinery (iTime in beats) ----
    float inBeat = fract(iTime);
    float beatHit = exp(-inBeat * 4.0);

    float bass  = clamp01(texture(AUDIO, vec2(0.05, 0.0)).x * sensitivity);
    float lowmid= clamp01(texture(AUDIO, vec2(0.25, 0.0)).x * sensitivity);
    float mid   = clamp01(texture(AUDIO, vec2(0.5, 0.0)).x  * sensitivity);
    float treble= clamp01(texture(AUDIO, vec2(0.9, 0.0)).x  * sensitivity);
    float fb = 0.35 + 0.4 * beatHit;
    if (bass < 0.03) bass = fb;
    if (lowmid < 0.03) lowmid = fb * 0.7;
    if (mid < 0.03) mid = fb * 0.5;

    float inflate = bass_react * (bass * 0.8 + 0.35 * beatHit);
    float spin = iTime * spin_speed * 1.5707963;
    float k = smooth_k * (1.0 + 0.5 * bass);

    // ---- camera ----
    float camA = iTime * spin_speed * 0.25;
    vec3 ro = vec3(sin(camA) * 3.4, 0.6 + 0.3 * sin(iTime * 0.5), cos(camA) * 3.4);
    vec3 fw = normalize(vec3(0.0) - ro);
    vec3 rt = normalize(cross(fw, vec3(0.0,1.0,0.0)));
    vec3 up = cross(rt, fw);
    vec3 rd = normalize(uv.x * rt + uv.y * up + 1.6 * fw);

    // ---- raymarch ----
    float t = 0.0;
    float d = 0.0;
    bool hit = false;
    float glowAcc = 0.0;
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 pos = ro + rd * t;
        d = map(pos, bass, lowmid, mid, inflate, spin, k);
        // volumetric glow accumulation (inverse distance)
        glowAcc += exp(-abs(d) * 3.5) * 0.02;
        if (d < 0.002) { hit = true; break; }
        t += max(d, 0.015);
        if (t > 12.0) break;
    }

    vec3 col = vec3(0.01, 0.012, 0.02);

    if (hit) {
        vec3 pos = ro + rd * t;
        vec3 n = calcNormal(pos, bass, lowmid, mid, inflate, spin, k);

        // spectral hue: base -> hot as treble rises, brightness by bass
        vec3 albedo = mix(base_color, hot_color, clamp01(treble + 0.3 * beatHit));
        albedo = mix(albedo, albedo * vec3(1.2, 0.9, 0.7), clamp01(lowmid));

        // two-light shading
        vec3 l1 = normalize(vec3(0.6, 0.8, 0.4));
        vec3 l2 = normalize(vec3(-0.5, -0.2, 0.7));
        float dif = clamp01(dot(n, l1));
        float dif2 = clamp01(dot(n, l2)) * 0.4;
        float amb = 0.25 + 0.25 * bass;

        // fresnel rim glow, boosted by beat
        float fres = pow(1.0 - clamp01(dot(n, -rd)), 3.0);

        // spec
        vec3 hx = normalize(l1 - rd);
        float spec = pow(clamp01(dot(n, hx)), 24.0) * (0.5 + bass);

        col = albedo * (amb + dif + dif2)
            + hot_color * fres * surface_glow * (1.0 + beatHit)
            + vec3(1.0) * spec;
    }

    // ---- volumetric glow behind/around the blob ----
    col += mix(base_color, hot_color, 0.4) * glowAcc * fog_density * (0.6 + bass);

    // ---- faint beat-reactive background wash ----
    if (background_mix > 0.0) {
        float bg = 0.5 + 0.5 * sin(uv.x * 3.0 + spin) * sin(uv.y * 3.0 - spin);
        col += base_color * bg * background_mix * (0.3 + 0.4 * beatHit);
    }

    // tone
    col = clamp(col, 0.0, 1.6);
    col = pow(col, vec3(0.85));
    fragColor = vec4(col, 1.0);
}
