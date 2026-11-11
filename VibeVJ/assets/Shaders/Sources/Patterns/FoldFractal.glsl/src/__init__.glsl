//@settings dtype=float32 format=rgba

// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: common ----
const float TAU = 6.28318530717959;
// 2D rotation matrix. `rot2(a) * v` rotates v counter-clockwise by a radians. (cos, sin) is renormalized because GLSL ES leaves trig precision undefined: on SwiftShader and some mobile GPUs a raw cos/sin pair is far enough from unit length that rotations stop preserving distances.
mat2 rot2(float a) {
    vec2 cs = normalize(vec2(cos(a), sin(a)));
    return mat2(cs.x, cs.y, -cs.y, cs.x);
}

// ---- shader-skills library: sdf2d ----
// Unsigned distance to segment a-b. Subtract a width to get a stroke.
float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}
// Vesica (lens): intersection of two circles of radius r whose centers sit at (+-d, 0). Points along Y. Needs d < r.
float sdVesica(vec2 p, float r, float d) {
    p = abs(p);
    float b = sqrt(r * r - d * d);
    return ((p.y - b) * d > p.x * b) ? length(p - vec2(0.0, b))
                                     : length(p - vec2(-d, 0.0)) - r;
}

// ---- shader-skills library: color ----
// Cosine palette a + b * cos(2 pi (c t + d)). Output is display-like (sRGB-ish), so decode it for albedo. Integer c values loop seamlessly over t in [0,1].
vec3 cosinePalette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(TAU * (c * t + d));
}

// ---- shader ----
// --- FoldFractal: a recursive shape made by folding space again and again (2D KIFS, like an L-system tree) ---
// Every iteration draws a branch, then mirrors the plane at the branch, turns it by Angle and makes it smaller by
// Scale: one line becomes a tree with 2^n tips (an L-system tree, made by folding space instead of recursion).
// Symmetry Tree grows one tree from the bottom; Mirror and 3-fold .. 8-fold put 2 .. 8 trees around the middle,
// starting at Inner radius: snowflakes and mandalas. Angle sway swings the angle with the beat, so the figure
// breathes. The colour follows the iteration: the trunk Colour A, the tips Colour B.
// Cost: one shape per iteration (Iterations 14 is still cheap).

//@enum options=(Tree, Mirror, 3-fold, 4-fold, 5-fold, 6-fold, 8-fold) value=0
uniform int symmetry;
//@slider min=0.0 max=0.8 value=0.15
uniform float inner_radius;         // Mirror .. 8-fold: where the trunks start, from the middle
//@int min=1 max=14 value=9
uniform int iterations;
//@slider min=-180.0 max=180.0 value=28.0
uniform float angle;                // degrees between a branch and the one before
//@slider min=0.0 max=45.0 value=6.0
uniform float angle_sway;           // degrees the angle swings
//@slider min=0.0 max=2.0 value=0.25
uniform float sway_speed;           // swings per beat
//@slider min=1.05 max=3.0 value=1.35
uniform float scale;                // how much shorter every branch is than the one before
//@slider min=0.05 max=1.0 value=0.5
uniform float branch_length;        // the length of the trunk; every branch is Scale times shorter
//@slider min=-1.0 max=1.0 value=0.0
uniform float branch_shift;         // moves the branches sideways: crooked, spiralling trees
//@enum options=(Lines, Dots, Rings, Leaves) value=0
uniform int shape;
//@slider min=0.001 max=0.1 value=0.02
uniform float line_width;
//@slider min=0.0 max=1.0 value=0.35
uniform float glow;
//@slider min=0.2 max=4.0 value=1.0
uniform float zoom;
//@slider min=-1.0 max=1.0 value=0.0
uniform float rotate_speed;         // turns of the whole figure per 16 beats
//@slider min=0.0 max=1.0 value=0.0
uniform float beat_pulse;           // the lines get brighter at every beat
//@enum options=(Gradient, Rainbow) value=0
uniform int color_mode;
//@rgb value=(1.0, 0.55, 0.15)
uniform vec3 color_a;               // the first iteration
//@rgb value=(0.2, 0.9, 1.0)
uniform vec3 color_b;               // the last iteration
//@slider min=0.0 max=1.0 value=0.0
uniform float color_cycle;          // Rainbow: colours running through the iterations, per beat
//@rgb value=(0.0, 0.0, 0.02)
uniform vec3 background;

float shapeDist(vec2 p, float len) {
    if (shape == 1) return length(p - vec2(0.0, len)) - line_width * 2.0;
    if (shape == 2) return abs(length(p - vec2(0.0, len)) - len * 0.3) - line_width * 0.5;
    if (shape == 3) return sdVesica(p - vec2(0.0, len * 0.5), len * 0.6, len * 0.42);
    return sdSegment(p, vec2(0.0), vec2(0.0, len)) - line_width * 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (2.0 * fragCoord - iResolution.xy) / iResolution.y / max(zoom, 0.05);
    float pxw = 2.0 / iResolution.y / max(zoom, 0.05);
    p = rot2(iTime * rotate_speed * TAU / 16.0) * p;

    if (symmetry == 0) {
        p.y += 0.95;            // the trunk starts at the bottom
    }
    else {
        // 2 .. 8 trees around the middle, the trunks pointing outwards
        float copies = symmetry == 1 ? 2.0 : symmetry == 2 ? 3.0 : symmetry == 3 ? 4.0 : symmetry == 4 ? 5.0 : symmetry == 5 ? 6.0 : 8.0;
        float sector = TAU / copies;
        float id = floor(atan(p.x, p.y) / sector + 0.5);
        p = rot2(id * sector) * p;
        p.y -= inner_radius;
    }

    float a = radians(angle + angle_sway * sin(iTime * sway_speed * TAU));
    float len = branch_length;
    float k = 1.0;              // the accumulated scale: distances are divided by it
    float best = 1e9;
    float bestIter = 0.0;
    int n = clamp(iterations, 1, 14);
    for (int i = 0; i < 14; i++) {
        if (i >= n)
            break;
        float d = shapeDist(p, len) / k;
        if (d < best) {
            best = d;
            bestIter = float(i);
        }
        p.y -= len;
        p.x = abs(p.x - branch_shift * len);
        p = rot2(a) * p * scale;
        k *= scale;
    }

    float t = bestIter / max(float(n - 1), 1.0);
    vec3 c = color_mode == 1
        ? cosinePalette(t * 0.8 + iTime * color_cycle, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67))
        : mix(color_a, color_b, t);
    float pulse = 1.0 + beat_pulse * 1.5 * pow(1.0 - fract(iTime), 3.0);

    float fill = 1.0 - smoothstep(-pxw, pxw, best);
    float halo = glow * exp(-max(best, 0.0) * 18.0) * 0.6;
    vec3 col = background + c * (fill + halo) * pulse;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
