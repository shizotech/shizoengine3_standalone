//@settings dtype=float32 format=rgba

// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: color ----
// Relative luminance of linear Rec.709 / sRGB color.
float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// ---- shader ----
// --- Levels: black point, white point, gamma, posterize and threshold (the Level TOP of TouchDesigner) ---
// In black / In white pick the part of the input range that is stretched to the full range (what is darker than In
// black becomes black). Gamma bends the middle tones, Out black / Out white set the range of the result. Posterize
// cuts it into steps, Threshold turns it into black and white. Channel limits the change to one colour channel.

// The picture to change
uniform sampler2D input;

//@slider min=0.0 max=1.0 value=0.0
uniform float in_black;
//@slider min=0.0 max=1.0 value=1.0
uniform float in_white;
//@slider min=0.1 max=4.0 value=1.0
uniform float gamma;                // > 1 brightens the middle tones, < 1 darkens them
//@slider min=0.0 max=1.0 value=0.0
uniform float out_black;
//@slider min=0.0 max=1.0 value=1.0
uniform float out_white;
//@int min=0 max=32 value=0
uniform int posterize;              // number of steps per channel, 0 = off
//@slider min=0.0 max=1.0 value=0.0
uniform float threshold;            // 0 = off; else the brightness where black turns to white
//@slider min=0.0 max=0.5 value=0.02
uniform float threshold_softness;
//@button
uniform bool invert;
//@enum options=(RGB, Red, Green, Blue, Luma) value=0
uniform int channel;                // Luma: changes the brightness and keeps the colour
//@slider min=0.0 max=1.0 value=1.0
uniform float amount;               // 0 = the input unchanged

vec3 levels(vec3 c) {
    c = clamp((c - in_black) / max(in_white - in_black, 1e-4), 0.0, 1.0);
    c = pow(c, vec3(1.0 / max(gamma, 0.01)));
    if (posterize > 1) {
        float n = float(posterize);
        c = min(floor(c * n) / (n - 1.0), 1.0);
    }
    if (threshold > 0.0)
        c = smoothstep(vec3(threshold - threshold_softness), vec3(threshold + threshold_softness + 1e-4), c);
    if (invert)
        c = 1.0 - c;
    return mix(vec3(out_black), vec3(out_white), c);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 c = texture(input, uv);
    vec3 src = c.rgb;
    vec3 res;

    if (channel == 4) {
        float y = luminance(clamp(src, 0.0, 1.0));
        float ny = levels(vec3(y)).r;
        res = clamp(src * (ny / max(y, 1e-4)), 0.0, 1.0);
        if (y < 1e-4)
            res = vec3(ny);
    }
    else {
        res = levels(src);
        if (channel == 1) res = vec3(res.r, src.gb);
        else if (channel == 2) res = vec3(src.r, res.g, src.b);
        else if (channel == 3) res = vec3(src.rg, res.b);
    }

    fragColor = vec4(mix(src, res, amount), c.a);
}
