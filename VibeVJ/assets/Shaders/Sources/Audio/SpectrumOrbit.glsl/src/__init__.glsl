//@settings dtype=float32 format=rgba

//@int min=8 max=64 value=32
uniform int bar_count;
//@slider min=0.0 max=4.0 value=0.6
uniform float orbit_speed;
//@slider min=0.0 max=2.0 value=0.6
uniform float bloom_intensity;
//@slider min=0.5 max=10.0 value=3.0
uniform float sensitivity;
//@rgb value=(0.35,0.75,1.0)
uniform vec3 core_glow;

// bloom pass C (auto-binds to the C.glsl vertical-blur pass)
uniform sampler2D C;

#define PI 3.1415926535897932384626433832795

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    // ---- Orbiting camera (iTime is in beats) ----
    float camAngle = orbit_speed * iTime;
    float eyeR = 3.5;
    float eyeH = 1.6;
    vec3 eye = vec3(cos(camAngle) * eyeR, eyeH, sin(camAngle) * eyeR);
    vec3 target = vec3(0.0);
    vec3 up = vec3(0.0, 1.0, 0.0);

    vec3 f = normalize(target - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);

    // ---- Audio energy (iChannel2 = spectrum, iChannel0 = waveform) ----
    float energy = texture(iChannel2, vec2(0.5, 0.0), 0.0).x * sensitivity;

    // ---- 3D spectrum bars arranged in a ring, perspective-projected ----
    float ringR = 1.0;
    float barW = 0.13;
    float barD = 0.13;
    float ringRot = iTime * 0.25;   // slow ring rotation for liveliness

    vec3 col = vec3(0.0);

    int n = bar_count;
    if (n < 8) n = 8;
    if (n > 64) n = 64;
    float nf = float(n);
    for (float i = 0.0; i < 64.0; i++)
    {
        float fi = i;
        float a = 2.0 * PI * fi / nf + ringRot;
        vec3 center = vec3(cos(a) * ringR, 0.0, sin(a) * ringR);

        // spectrum sample at this bar's frequency bin
        float spec = texture(iChannel2, vec2(fi / nf, 0.0), 0.0).x * sensitivity;

        // time-based base oscillation so it moves even without audio
        float osc = 0.18 + 0.14 * abs(sin(iTime * PI * 0.5 + fi * 0.6));
        float h = max(0.08, osc + spec + energy * 0.25);

        // Project the bar's base and tip onto the screen and draw a glowing band.
        vec3 bot = center + vec3(-barW * 0.5, 0.0, -barD * 0.5);
        vec3 tip = center + vec3(barW * 0.5, h, barD * 0.5);
        float focal = iResolution.y;
        vec3 relB = bot - eye;
        float depthB = max(dot(relB, f), 0.001);
        vec2 pbot = 0.5 * iResolution.xy + (focal / depthB) * vec2(dot(relB, s), dot(relB, u)) + vec2((iResolution.y - iResolution.x) * 0.5, 0.0);
        vec3 relT = tip - eye;
        float depthT = max(dot(relT, f), 0.001);
        vec2 ptop = 0.5 * iResolution.xy + (focal / depthT) * vec2(dot(relT, s), dot(relT, u)) + vec2((iResolution.y - iResolution.x) * 0.5, 0.0);

        // bar color: hue gradient by index, slowly drifting with iTime
        vec3 barCol = hsv2rgb(vec3(fi / nf + fract(iTime * 0.05), 0.75, 1.0));
        float rangeMask = 1.0 - smoothstep(nf - 0.5, nf - 0.4, i);

        // 2D glow band perpendicular to the projected bar axis.
        vec2 axis = ptop - pbot;
        float axisLen = max(length(axis), 0.001);
        vec2 axisNorm = axis / axisLen;
        vec2 perp = vec2(-axisNorm.y, axisNorm.x);
        vec2 rel2 = fragCoord - pbot;
        float along = dot(rel2, axisNorm);
        float across = dot(rel2, perp);
        float alongMask = smoothstep(0.0, axisLen, along) * (1.0 - smoothstep(axisLen, axisLen + 6.0, along));
        float halfW = 3.0 + 8.0 * max(0.0, h);
        float glow = smoothstep(halfW, 0.0, abs(across)) * alongMask;
        col += barCol * glow * rangeMask;
    }

    // ---- Central glowing core ----
    vec2 pc = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float coreR = 0.30 + 0.10 * energy;
    float core = 1.0 - smoothstep(coreR * 0.2, coreR, length(pc));
    col += core_glow * core * (1.0 + energy);

    // ---- Add bloom from C pass ----
    col += texture(C, uv, 0.0).rgb * bloom_intensity;

    fragColor = vec4(col, 1.0);
}
