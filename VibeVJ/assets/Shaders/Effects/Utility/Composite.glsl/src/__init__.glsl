//@settings dtype=float32 format=rgba

// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: common ----
// 2D rotation matrix. `rot2(a) * v` rotates v counter-clockwise by a radians. (cos, sin) is renormalized because GLSL ES leaves trig precision undefined: on SwiftShader and some mobile GPUs a raw cos/sin pair is far enough from unit length that rotations stop preserving distances.
mat2 rot2(float a) {
    vec2 cs = normalize(vec2(cos(a), sin(a)));
    return mat2(cs.x, cs.y, -cs.y, cs.x);
}

// ---- shader-skills library: color ----
// Relative luminance of linear Rec.709 / sRGB color.
float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// ---- shader ----
// --- Composite: two pictures in one, with a blend mode (the Composite TOP of TouchDesigner) ---
// Input is the base (the bottom picture, the one before in a chain), Layer goes on top of it. The layer can be moved,
// scaled and turned first. Over uses the alpha of the layer; Luma key cuts out its dark parts; Mask shows the base
// only where the layer is bright. Opacity fades the result back to the base.

// The base picture (bottom)
uniform sampler2D input;
// The picture that goes on top
uniform sampler2D layer;

//@enum options=(Over, Add, Subtract, Multiply, Screen, Overlay, Soft light, Hard light, Difference, Lighten, Darken, Color dodge, Luma key, Mask) value=4
uniform int blend_mode;
//@slider min=0.0 max=1.0 value=1.0
uniform float opacity;
//@slider min=0.0 max=1.0 value=0.15
uniform float key_level;            // Luma key / Mask: the brightness where the layer starts to show
//@slider min=0.0 max=0.5 value=0.1
uniform float key_softness;
//@slidervec2 min=(-1.0,-1.0) max=(1.0,1.0) value=(0.0,0.0)
uniform vec2 layer_offset;          // moves the layer, in parts of the picture
//@slider min=0.1 max=4.0 value=1.0
uniform float layer_scale;
//@slider min=-180.0 max=180.0 value=0.0
uniform float layer_rotate;         // degrees
//@enum options=(Transparent, Repeat) value=0
uniform int layer_edge;             // what the layer shows outside of itself when it is made smaller
//@button
uniform bool swap_inputs;           // the layer under the base

// The layer at uv after its transform; inside is 0 where a smaller layer does not reach
vec4 layerAt(vec2 uv, out float inside) {
    inside = 1.0;
    vec2 aspect = vec2(iResolution.z, 1.0);
    vec2 p = (uv - 0.5 - layer_offset) * aspect;
    p = rot2(-radians(layer_rotate)) * p / max(layer_scale, 0.01);
    vec2 q = p / aspect + 0.5;
    if (layer_edge == 1)
        return texture(layer, fract(q));
    if (q.x < 0.0 || q.y < 0.0 || q.x > 1.0 || q.y > 1.0) {
        inside = 0.0;
        return vec4(0.0);
    }
    return texture(layer, q);
}

float overlayCh(float b, float l) {
    return b < 0.5 ? 2.0 * b * l : 1.0 - 2.0 * (1.0 - b) * (1.0 - l);
}

vec3 overlay(vec3 b, vec3 l) {
    return vec3(overlayCh(b.r, l.r), overlayCh(b.g, l.g), overlayCh(b.b, l.b));
}

// Soft light after the W3C compositing spec
float softCh(float b, float l) {
    float d = b <= 0.25 ? ((16.0 * b - 12.0) * b + 4.0) * b : sqrt(b);
    return l <= 0.5 ? b - (1.0 - 2.0 * l) * b * (1.0 - b) : b + (2.0 * l - 1.0) * (d - b);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(input, uv);
    float inside;
    vec4 top = layerAt(uv, inside);
    if (swap_inputs) {
        vec4 t = base;
        base = top;
        top = t;
    }
    vec3 b = clamp(base.rgb, 0.0, 1.0);
    vec3 l = clamp(top.rgb, 0.0, 1.0);
    // Outside of a smaller layer nothing is blended. The modes other than Over ignore the alpha: many
    // sources write 1 there, some 0
    float cover = inside;

    vec3 col;
    if (blend_mode == 0)
        col = mix(b, l, top.a);
    else if (blend_mode == 1)
        col = b + l;
    else if (blend_mode == 2)
        col = b - l;
    else if (blend_mode == 3)
        col = b * l;
    else if (blend_mode == 4)
        col = 1.0 - (1.0 - b) * (1.0 - l);
    else if (blend_mode == 5)
        col = overlay(b, l);
    else if (blend_mode == 6)
        col = vec3(softCh(b.r, l.r), softCh(b.g, l.g), softCh(b.b, l.b));
    else if (blend_mode == 7)
        col = overlay(l, b);
    else if (blend_mode == 8)
        col = abs(b - l);
    else if (blend_mode == 9)
        col = max(b, l);
    else if (blend_mode == 10)
        col = min(b, l);
    else if (blend_mode == 11)
        col = min(b / max(1.0 - l, 1e-3), 1.0);
    else if (blend_mode == 12)
        col = mix(b, l, smoothstep(key_level, key_level + key_softness + 1e-3, luminance(l)) * inside);
    else {
        col = b * smoothstep(key_level, key_level + key_softness + 1e-3, luminance(l));
        cover = 1.0;
    }

    col = mix(b, clamp(col, 0.0, 1.0), opacity * (blend_mode == 0 || blend_mode == 12 ? 1.0 : cover));
    fragColor = vec4(col, max(base.a, top.a * opacity));
}
