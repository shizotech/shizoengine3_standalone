// FX1 NoiseWash - Pass 2 (CLEAN CENTER SHAPE)
// Shadertoy format
// Takes the noise wash output (layer1) and cuts a clean, low-noise
// central shape (selectable form) whose noise amount is reduced.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Cascaded output of the noise-wash pass, auto-bound by name
uniform sampler2D layer1;

// Central form to cut out
//@enum options=(Circle, Square, Diamond, Triangle, Star) value=0
uniform int shape_type;

// Size of the central shape (fraction of the frame)
//@slider min=0.05 max=0.6 value=0.2
uniform float shape_size;

// How strongly the shape reduces the noise (1.0 = fully clean)
//@slider min=0.0 max=1.0 value=1.0
uniform float shape_clean;

// Shape rotation offset
//@slider min=0.0 max=1.0 value=0.0
uniform float shape_rotation;

// Shape rotation speed
//@slider min=-3.0 max=3.0 value=0.3
uniform float shape_rot_speed;

// Edge smoothness of the shape
//@slider min=0.01 max=0.4 value=0.05
uniform float shape_smoothness;

// Background colour
//@rgb value=(0.05,0.04,0.08)
uniform vec3 background;

// ---- SDF helpers ----
float sd_shape(vec2 p, int type, float size) {
    vec2 q = p / size;
    float d;
    if (type == 0) {
        d = length(q) - 1.0; // circle
    } else if (type == 1) {
        vec2 a = abs(q) - 1.0; // square
        d = length(max(a, 0.0)) + min(max(a.x, a.y), 0.0) - 1.0;
    } else if (type == 2) {
        vec2 a = abs(q); // diamond
        d = (a.x + a.y) - 1.0;
    } else if (type == 3) {
        d = (abs(q.x) + q.y) - 1.0; // triangle
    } else {
        float ang = atan(p.y, p.x);
        float star_r = size * mix(0.55, 1.0, 0.5 + 0.5 * cos(5.0 * ang));
        d = length(p) - star_r; // star
    }
    return d * size;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 uv_a = uv;
    uv_a.x *= iResolution.x / iResolution.y; // aspect-correct for shape space

    // Rotate the shape space
    float ang = shape_rotation * 6.2831853 + iTime * shape_rot_speed;
    float ca = cos(ang);
    float sa = sin(ang);
    vec2 c = uv_a - 0.5;
    vec2 rc = vec2(c.x * ca - c.y * sa, c.x * sa + c.y * ca);

    float d = sd_shape(rc, shape_type, shape_size);
    // Coverage inside the shape (1 inside, 0 outside)
    float cover = 1.0 - smoothstep(-shape_smoothness, shape_smoothness, d);

    // Blend the noise wash down to background inside the clean shape
    vec3 wash = texture(layer1, uv).rgb;
    vec3 bg = background;
    vec3 outcol = mix(wash, bg, cover * shape_clean);
    outcol = max(bg, outcol);

    fragColor = vec4(outcol, 1.0);
}
