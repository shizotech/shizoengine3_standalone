//@settings dtype=float32 format=rgba rendersize=(1280,720)

// ===== User-controllable parameters (all annotated) =====
//@int min=2 max=32 value=8
uniform int sphere_count;
//@slider min=0.9 max=0.999 value=0.96
uniform float trail_decay;
//@slider min=0.0 max=1.5 value=0.6
uniform float orbit_tilt;
//@slider min=0.0 max=4.0 value=0.35
uniform float orbit_speed;
//@rgb value=(0.35,0.75,1.0)
uniform vec3 glow_color;
//@slider min=0.0 max=3.0 value=1.2
uniform float glow_intensity;
//@slider min=0.5 max=6.0 value=2.0
uniform float sensitivity;

// motion trails (binds to this pass's previous frame)
uniform sampler2D feedback;
// bloom pass C (auto-binds to the C.glsl vertical-blur pass)
uniform sampler2D C;

#define PI 3.1415926535897932384626433832795

// ---- value noise + FBM helpers (drift so the visual never freezes) ----
float vhash(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}
float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(vhash(i),                 vhash(i + vec2(1.0, 0.0)), u.x),
        mix(vhash(i + vec2(0.0, 1.0)), vhash(i + vec2(1.0, 1.0)), u.x),
        u.y);
}
float fbm(vec2 p) {
    float a = 0.5;
    float sum = 0.0;
    for (int k = 0; k < 4; k++) {
        sum += a * vnoise(p);
        p = p * 2.0 + vec2(17.3, 9.1);
        a *= 0.5;
    }
    return sum;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    // ---- Orbiting camera (iTime is in beats, rotates smoothly) ----
    float camAngle = orbit_speed * iTime;
    float eyeR = 3.2;
    float eyeH = 1.2;
    vec3 eye = vec3(cos(camAngle) * eyeR, eyeH, sin(camAngle) * eyeR);
    vec3 target = vec3(0.0);
    vec3 up = vec3(0.0, 1.0, 0.0);

    vec3 f = normalize(target - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    float focal = iResolution.y;

    // ---- Audio energy: waveform (iChannel0) + spectrum (iChannel2) ----
    float energy = 0.0;
    {
        float w = texture(iChannel0, vec2(0.5, 0.0), 0.0).x;
        float sp = texture(iChannel2, vec2(0.5, 0.0), 0.0).x;
        energy = (w * 0.5 + sp * 0.5) * sensitivity;
    }

    // ---- Projected center + radius for an arbitrary 3D point ----
    // (defined inline via macro-free helper function below)
    vec3 lightDir = normalize(vec3(0.4, 0.8, 0.3));

    vec3 col = vec3(0.0);

    int n = sphere_count;
    if (n < 2) n = 2;
    if (n > 32) n = 32;
    float nf = float(n);

    // Elliptical 3D orbit: semi-axes a (x) and b (z), tilted around X by orbit_tilt
    float a = 1.6;
    float b = 0.9;
    float ct = cos(orbit_tilt);
    float st = sin(orbit_tilt);

    for (int i = 0; i < 32; i++)
    {
        if (i >= n) break;
        float fi = float(i);
        float phase = 2.0 * PI * fi / nf;
        float t = phase + orbit_speed * iTime;   // orbit rotates with beats

        // point on ellipse in XZ plane
        vec3 p = vec3(a * cos(t), 0.0, b * sin(t));
        // tilt the orbit plane around the X axis
        p = vec3(p.x, p.y * ct - p.z * st, p.y * st + p.z * ct);

        // per-sphere drift (value-noise so it never freezes)
        float shimmer = fbm(vec2(fi * 0.7 + iTime * 0.15, fi));
        float sphereR = 0.16 + 0.06 * shimmer + 0.12 * energy;

        // project sphere center
        vec3 rel = p - eye;
        float depth = max(dot(rel, f), 0.001);
        vec2 c = 0.5 * iResolution.xy + (focal / depth) * vec2(dot(rel, s), dot(rel, u));
        // projected radius (world radius scaled by perspective)
        float r_px = (sphereR * focal) / depth;
        // depth cue: closer spheres (small depth) appear larger
        float depthFade = clamp(1.8 / depth, 0.35, 1.0);

        // sphere body: shaded gradient disc
        vec2 d = fragCoord - c;
        float dist = length(d);
        float disc = smoothstep(r_px, r_px * 0.2, dist);

        // simple Lambertian shading + specular toward light
        float ndl = clamp(dot(normalize(p - eye), lightDir), 0.0, 1.0);
        vec3 shaded = glow_color * (0.35 + 0.65 * ndl);
        // specular highlight offset toward upper-left
        float spec = clamp(dot(-normalize(d + vec2(-r_px * 0.35, -r_px * 0.4)), normalize(lightDir.xy), 0.0, 1.0);
        spec = pow(spec, 24.0);
        shaded += vec3(1.0) * spec * 0.7;

        col += shaded * disc * depthFade;

        // emissive halo (bloom-like radial falloff)
        float haloR = r_px * 2.6;
        float halo = exp(-(dist * dist) / (2.0 * haloR * haloR));
        col += glow_color * halo * (0.5 + energy) * depthFade;
    }

    // ---- Add bloom from C pass ----
    col += texture(C, uv, 0.0).rgb * glow_intensity;

    // ---- Motion trails: keep previous frame fading by trail_decay ----
    vec3 prev = texture(feedback, uv, 0.0).rgb;
    col = max(col, prev * trail_decay);

    fragColor = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
