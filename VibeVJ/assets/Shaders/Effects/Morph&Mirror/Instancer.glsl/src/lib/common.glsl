// --- Instancer: what both passes share ---
// Instancing as in TouchDesigner: one shape copied over a grid (or a circle, a sphere, a cylinder, a scatter), and
// every copy takes its size, colour, turn and depth from the pixel of the input picture under it. Pass I draws the
// copies as quads (//@settings draw=quads: one quad a copy, drawn by the GPU, so 100 000 copies cost no more per
// pixel than ten), __init__ puts them over the background. The copies of the far side are drawn first, so the near
// ones cover them (no depth buffer: on a sphere the back is hidden instead).

// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: common ----
const float PI  = 3.14159265358979;

// ---- shader-skills library: hash ----
// PCG-style 1D integer hash.
uint pcgHash(uint v) {
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}
// Map a uint to [0,1) using the top 24 bits, so the result can never round up to 1.0.
float uintToUnit(uint h) { return float(h >> 8u) * (1.0 / 16777216.0); }
vec2 uintToUnit(uvec2 h) { return vec2(h >> 8u) * (1.0 / 16777216.0); }
vec3 uintToUnit(uvec3 h) { return vec3(h >> 8u) * (1.0 / 16777216.0); }
vec4 uintToUnit(uvec4 h) { return vec4(h >> 8u) * (1.0 / 16777216.0); }
// Random float in [0,1) for an integer-valued 2D input.
float hash12(vec2 p) {
    uvec2 q = uvec2(ivec2(floor(p)));
    return uintToUnit(pcgHash(q.x + pcgHash(q.y)));
}

// ---- shader-skills library: sdf3d ----
// Axis-aligned box with half-extents b.
float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// ---- shader-skills library: sdf2d ----
// Circle of radius r.
float sdCircle(vec2 p, float r) { return length(p) - r; }
// Axis-aligned rectangle with half-extents b.
float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
// Rectangle with half-extents b and per-corner radii r = (top-right, bottom-right, top-left, bottom-left).
float sdRoundedBox(vec2 p, vec2 b, vec4 r) {
    r.xy = (p.x > 0.0) ? r.xy : r.zw;
    r.x = (p.y > 0.0) ? r.x : r.y;
    vec2 q = abs(p) - b + r.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}
// Equilateral triangle with circumradius-like size r, pointing up.
float sdEquilateralTriangle(vec2 p, float r) {
    const float k = 1.7320508;
    p.x = abs(p.x) - r;
    p.y = p.y + r / k;
    if (p.x + k * p.y > 0.0) p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
    p.x -= clamp(p.x, -2.0 * r, 0.0);
    return -length(p) * sign(p.y);
}
// Regular n-gon with circumradius r, one vertex pointing up.
float sdRegularPolygon(vec2 p, float r, int n) {
    float an = PI / float(n);
    vec2 acs = vec2(cos(an), sin(an));
    float len = length(p);
    if (len < 1e-12) return -r * acs.x;
    float bn = mod(atan(p.x, p.y), 2.0 * an) - an;
    p = len * vec2(cos(bn), abs(sin(bn)));
    p -= r * acs;
    p.y += clamp(-p.y, 0.0, r * acs.y);
    return length(p) * sign(p.x);
}
// Star with n points and outer radius r. m in [2, n] sets the inner angle: m = 2 is the spikiest and m = n is a regular n-gon.
float sdStar(vec2 p, float r, int n, float m) {
    float an = PI / float(n);
    float en = PI / m;
    vec2 acs = vec2(cos(an), sin(an));
    vec2 ecs = vec2(cos(en), sin(en));
    float len = length(p);
    if (len < 1e-12) return -r * acs.x;
    float bn = mod(atan(p.x, p.y), 2.0 * an) - an;
    p = len * vec2(cos(bn), abs(sin(bn)));
    p -= r * acs;
    p += ecs * clamp(-dot(p, ecs), 0.0, r * acs.y / ecs.y);
    return length(p) * sign(p.x);
}
// Rhombus with half-diagonals b.
float sdRhombus(vec2 p, vec2 b) {
    p = abs(p);
    vec2 t = b - 2.0 * p;
    float h = clamp((t.x * b.x - t.y * b.y) / dot(b, b), -1.0, 1.0);
    float d = length(p - 0.5 * b * vec2(1.0 - h, 1.0 + h));
    return d * sign(p.x * b.y + p.y * b.x - b.x * b.y);
}

// ---- shader-skills library: color ----
// Relative luminance of linear Rec.709 / sRGB color.
float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// ---- shader ----
uniform sampler2D input;

//@enum options=(Grid, Hex grid, Circle, Sphere, Cylinder, Scatter) value=0
uniform int layout_mode;            // where the copies sit
//@int min=2 max=400 value=64
uniform int columns;
//@int min=1 max=400 value=36
uniform int rows;                   // 64 x 36 keeps the cells square in 16:9
//@enum options=(Circle, Square, Rounded square, Ring, Triangle, Diamond, Star, Cross, Line, Hexagon) value=0
uniform int shape;
//@slider min=0.0 max=3.0 value=0.95
uniform float size;                 // of a copy, 1 = the cell
//@enum options=(Brightness, Darkness, Red, Green, Blue, Same for all) value=0
uniform int size_by;                // what of the pixel sets the size
//@slider min=0.0 max=4.0 value=1.6
uniform float value_gain;           // multiplies the picture value: higher = dark pictures still give big copies
//@slider min=0.0 max=1.0 value=0.15
uniform float min_size;             // the size where the value is 0
//@slider min=0.0 max=1.0 value=0.04
uniform float threshold;            // copies whose pixel is darker are left out
//@slider min=-180.0 max=180.0 value=0.0
uniform float rotate;               // degrees, every copy
//@slider min=-360.0 max=360.0 value=0.0
uniform float rotate_by;            // extra degrees at full brightness
//@slider min=-90.0 max=90.0 value=0.0
uniform float spin;                 // degrees a beat
//@slider min=-2.0 max=2.0 value=0.35
uniform float depth;                // how far bright pixels come out (3D)
//@enum options=(From picture, Gradient by brightness, Single color, Picture x color) value=0
uniform int color_mode;
//@rgb value=(0.1, 0.3, 1.0)
uniform vec3 color_a;               // Gradient: the colour of dark pixels; Single / Picture x color: the colour
//@rgb value=(1.0, 0.45, 0.15)
uniform vec3 color_b;               // Gradient: the colour of bright pixels
//@slider min=0.0 max=1.0 value=1.0
uniform float opacity;
//@enum options=(Over, Add) value=0
uniform int blend;                  // Add: copies add up like light
//@slider min=0.0 max=0.5 value=0.0
uniform float outline;              // 0: filled shapes, else the width of the line
//@slider min=0.0 max=1.0 value=0.25
uniform float beat_pulse;           // the copies grow at every beat
//@enum options=(3D, Flat) value=0
uniform int view;
//@slider min=-89.0 max=89.0 value=30.0
uniform float camera_tilt;          // degrees: the grid leans back
//@slider min=-180.0 max=180.0 value=-20.0
uniform float camera_turn;          // degrees around the upright axis
//@slider min=-30.0 max=30.0 value=0.0
uniform float camera_spin;          // degrees a beat
//@slider min=0.3 max=3.0 value=0.7
uniform float zoom;
//@slider min=1.0 max=10.0 value=3.0
uniform float camera_distance;      // smaller: stronger perspective

// The picture value that drives a copy, from its pixel
float driveValue(vec3 c, int mode) {
    if (mode == 0) return luminance(c);
    if (mode == 1) return 1.0 - luminance(c);
    if (mode == 2) return c.r;
    if (mode == 3) return c.g;
    if (mode == 4) return c.b;
    return 1.0;
}

// The shape of a copy at p (-1..1, the quad), as a signed distance
float shapeDistance(vec2 p) {
    if (shape == 0) return sdCircle(p, 0.9);
    if (shape == 1) return sdBox(p, vec2(0.68));
    if (shape == 2) return sdRoundedBox(p, vec2(0.68), vec4(0.25));
    if (shape == 3) return abs(sdCircle(p, 0.7)) - 0.2;
    if (shape == 4) return sdEquilateralTriangle(p + vec2(0.0, 0.15), 0.85);
    if (shape == 5) return sdRhombus(p, vec2(0.95, 0.95));
    if (shape == 6) return sdStar(p, 0.95, 5, 3.0);
    if (shape == 7) return min(sdBox(p, vec2(0.95, 0.22)), sdBox(p, vec2(0.22, 0.95)));
    if (shape == 8) return sdBox(p, vec2(0.98, 0.1));
    return sdRegularPolygon(p, 0.92, 6);
}
