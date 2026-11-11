//@settings dtype=float32 format=rgba

// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: common ----
const float TAU = 6.28318530717959;

// ---- shader-skills library: color ----
// Relative luminance of linear Rec.709 / sRGB color.
float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
// Cosine palette a + b * cos(2 pi (c t + d)). Output is display-like (sRGB-ish), so decode it for albedo. Integer c values loop seamlessly over t in [0,1].
vec3 cosinePalette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(TAU * (c * t + d));
}

// ---- shader ----
// --- GradientMap: colours the input with a colour ramp (the Lookup + Ramp TOPs of TouchDesigner) ---
// The brightness (or another value of the pixel, see Source) picks a colour on the ramp: dark pixels the left end,
// bright ones the right end. Palette Four colours uses Colour 1 to 4 as the stops; the other palettes are made of
// cosine waves. Offset and Cycle speed slide the ramp (it wraps around), Repeat lays it several times over the range,
// so black-and-white pictures turn into bands of colour.

// The picture to colour
uniform sampler2D input;

//@enum options=(Four colours, Rainbow, Fire, Ice, Neon, Sunset, Acid, Mono) value=0
uniform int palette;
//@rgb value=(0.03, 0.02, 0.12)
uniform vec3 color_1;               // the darkest stop
//@rgb value=(0.55, 0.05, 0.55)
uniform vec3 color_2;
//@rgb value=(1.0, 0.45, 0.1)
uniform vec3 color_3;
//@rgb value=(1.0, 0.95, 0.7)
uniform vec3 color_4;               // the brightest stop
//@enum options=(Luma, Red, Green, Blue, Saturation, Hue) value=0
uniform int source;                 // what of the pixel picks the colour
//@slider min=0.0 max=1.0 value=0.0
uniform float offset;               // slides the ramp; it wraps around
//@slider min=-1.0 max=1.0 value=0.0
uniform float cycle_speed;          // ramps per 4 beats: the colours run through the picture
//@slider min=1.0 max=8.0 value=1.0
uniform float repeat;               // the ramp several times over dark to bright
//@button
uniform bool mirror;                // every second repeat backwards, so the bands have no hard edge
//@slider min=0.2 max=4.0 value=1.0
uniform float contrast;             // of the source value, around the middle
//@slider min=0.0 max=1.0 value=1.0
uniform float amount;               // 0 = the input unchanged

vec3 rgbToHsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 ramp(float t) {
    if (palette == 1) return cosinePalette(t, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
    if (palette == 2) return clamp(cosinePalette(t * 0.5, vec3(0.5, 0.25, 0.08), vec3(0.6, 0.35, 0.1), vec3(1.0), vec3(0.5, 0.55, 0.6)), 0.0, 1.0);
    if (palette == 3) return cosinePalette(t, vec3(0.45, 0.6, 0.75), vec3(0.4, 0.4, 0.3), vec3(0.6, 0.6, 0.5), vec3(0.5, 0.45, 0.4));
    if (palette == 4) return cosinePalette(t, vec3(0.5), vec3(0.5), vec3(1.0, 1.0, 0.5), vec3(0.8, 0.9, 0.3));
    if (palette == 5) return cosinePalette(t, vec3(0.5, 0.35, 0.4), vec3(0.5, 0.35, 0.3), vec3(1.0, 0.7, 0.4), vec3(0.0, 0.15, 0.2));
    if (palette == 6) return cosinePalette(t, vec3(0.5), vec3(0.5), vec3(2.0, 1.0, 0.0), vec3(0.5, 0.2, 0.25));
    if (palette == 7) return vec3(t);
    // Four colours: three equal segments
    float s = t * 3.0;
    if (s < 1.0) return mix(color_1, color_2, s);
    if (s < 2.0) return mix(color_2, color_3, s - 1.0);
    return mix(color_3, color_4, s - 2.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 c = texture(input, uv);
    vec3 rgb = clamp(c.rgb, 0.0, 1.0);

    float v;
    if (source == 1) v = rgb.r;
    else if (source == 2) v = rgb.g;
    else if (source == 3) v = rgb.b;
    else if (source == 4) v = rgbToHsv(rgb).y;
    else if (source == 5) v = rgbToHsv(rgb).x;
    else v = luminance(rgb);

    // Just below 1, so white stays at the right end of a single ramp instead of wrapping to the left
    v = clamp((v - 0.5) * contrast + 0.5, 0.0, 0.99999);
    float t = v * repeat + offset + iTime * cycle_speed * 0.25;
    float band = floor(t);
    float f = t - band;
    if (mirror && mod(band, 2.0) > 0.5)
        f = 1.0 - f;

    fragColor = vec4(mix(c.rgb, ramp(clamp(f, 0.0, 1.0)), amount), c.a);
}
