// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: common ----
const float TAU = 6.28318530717959;

// ---- shader-skills library: noise ----
// Interleaved gradient noise: cheap per-pixel noise whose 3x3 neighborhoods are nearly stratified. Not a hash. pixel must be integer pixel coordinates (floor(fragCoord)). The frame overload animates it for accumulation and TAA.
float interleavedGradientNoise(vec2 pixel) {
    return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}
float interleavedGradientNoise(vec2 pixel, int frame) {
    return interleavedGradientNoise(pixel + 5.588238 * float(frame % 64));
}

// ---- shader-skills library: color ----
// Exact sRGB decode (EOTF): encoded [0,1] -> linear.
vec3 srgbToLinear(vec3 c) {
    c = max(c, 0.0);
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}
// Exact sRGB encode (OETF): linear -> display [0,1]. Apply exactly once, after tonemapping. pow(c, 1/2.2) is visibly wrong near black (0.001 encodes to 0.013 here vs 0.043 with 2.2).
vec3 linearToSrgb(vec3 c) {
    c = max(c, 0.0);
    return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}
// Relative luminance of linear Rec.709 / sRGB color.
float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// ---- shader ----
// --- LensBlur: what the passes share ---
// A lens blur (bokeh): every point spreads into a disc or a polygon of the blades, bright points into bright discs.
// P (a quarter of the size) holds the input in linear light and in alpha the size of the disc there (the circle of
// confusion, from the focus). H keeps the brightest highlight of each texel, Q grows them a little, so that the taps
// of B do not miss small lights. B gathers each
// pixel from the discs around it on a golden-angle spiral: a tap counts only when the disc of its own point reaches
// this pixel, so sharp parts do not bleed into blurred ones and the other way round (scatter as gather).
// __init__ scales B up with a B-spline and keeps the sharp parts sharp from the full-size input.

//@slider min=0.0 max=80.0 value=18.0
uniform float radius;               // the biggest disc, in pixels of a 1080p picture
//@enum options=(Everywhere, Depth map input, Brightness as depth, Around a point) value=0
uniform int focus_mode;             // what is sharp: nothing, a depth picture (port Depth map), the brightness, a point
//@slider min=0.0 max=1.0 value=0.5
uniform float focus_distance;       // the depth (0 = near, 1 = far) that is sharp
//@slider min=0.0 max=1.0 value=0.1
uniform float focus_range;          // how deep the sharp part is
//@slider min=0.01 max=1.0 value=0.3
uniform float focus_falloff;        // how fast it gets blurred beyond that
//@slidervec2 min=(0.0,0.0) max=(1.0,1.0) value=(0.5,0.5)
uniform vec2 focus_point;           // Around a point: the sharp spot
//@slider min=0.0 max=1.0 value=0.0
uniform float focus_sweep;          // the focus distance swings by this much, once every 4 beats
//@int min=0 max=8 value=0
uniform int blades;                 // 0 = round, 3 to 8 = a polygon
//@slider min=0.0 max=360.0 value=0.0
uniform float blade_rotation;
//@slider min=0.0 max=1.0 value=0.7
uniform float highlight_level;      // parts brighter than this make bright discs
//@slider min=0.0 max=4.0 value=1.5
uniform float highlight_gain;       // how bright the discs of the bright parts are
//@slider min=0.0 max=2.0 value=0.0
uniform float ring;                 // > 0: the discs are brighter at their edge (an old lens)
//@enum options=(Fast, Good, Best) value=1
uniform int quality;                // taps of a disc: 32, 64 or 128
//@slider min=0.0 max=2.0 value=0.0
uniform float beat_pump;            // the discs grow by this share at every beat and fall back
//@slider min=1.0 max=12.0 value=4.0
uniform float pump_decay;

// A picture whose brightness is the depth (Focus mode Depth map input)
uniform sampler2D depth_map;

const float GOLDEN_ANGLE = 2.39996323;

// Biggest disc in pixels of this pass
float maxRadiusPx() {
    float pump = beat_pump * pow(1.0 - fract(iTime), pump_decay);
    return radius / 1080.0 * iResolution.y * (1.0 + pump);
}

// Size of the disc at uv, 0 .. 1 of the biggest; lum: brightness of the input there
float circleOfConfusion(vec2 uv, float lum) {
    if (focus_mode == 0)
        return 1.0;
    float f;
    if (focus_mode == 3) {
        f = length((uv - focus_point) * vec2(iResolution.x / iResolution.y, 1.0));
    } else {
        float depth = focus_mode == 1 ? luminance(texture(depth_map, uv).rgb) : lum;
        float fd = clamp(focus_distance + focus_sweep * 0.5 * sin(iTime * TAU / 4.0), 0.0, 1.0);
        f = abs(depth - fd);
    }
    return smoothstep(focus_range, focus_range + focus_falloff, f);
}

// Radius of the blade polygon at angle a, 1 at its corners
float bladeShape(float a) {
    if (blades < 3)
        return 1.0;
    float seg = TAU / float(blades);
    float x = mod(a - radians(blade_rotation), seg) - 0.5 * seg;
    return cos(0.5 * seg) / cos(x);
}

int tapCount() { return quality == 0 ? 32 : (quality == 1 ? 64 : 128); }

// Distance between two taps of the spiral, in pixels of this pass
float tapSpacing() {
    float r = maxRadiusPx();
    return sqrt(3.14159 * r * r / float(tapCount()));
}

// The part of a (linear) colour above the highlight level
vec3 highlightPart(vec3 c) {
    return c * smoothstep(highlight_level, highlight_level + 0.2, luminance(linearToSrgb(c)));
}

// Bilinear sample of a pass (the textures of passes are not filtered)
vec4 sampleLinear(sampler2D t, vec2 uv) {
    ivec2 sz = textureSize(t, 0);
    vec2 p = uv * vec2(sz) - 0.5;
    ivec2 i0 = ivec2(floor(p));
    vec2 f = p - floor(p);
    ivec2 hi = sz - 1;
    vec4 a = texelFetch(t, clamp(i0, ivec2(0), hi), 0);
    vec4 b = texelFetch(t, clamp(i0 + ivec2(1, 0), ivec2(0), hi), 0);
    vec4 c = texelFetch(t, clamp(i0 + ivec2(0, 1), ivec2(0), hi), 0);
    vec4 d = texelFetch(t, clamp(i0 + ivec2(1, 1), ivec2(0), hi), 0);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
