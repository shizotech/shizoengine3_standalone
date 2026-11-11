//@settings dtype=float32 format=rgba

// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: common ----
const float TAU = 6.28318530717959;
// 2D rotation matrix. `rot2(a) * v` rotates v counter-clockwise by a radians. (cos, sin) is renormalized because GLSL ES leaves trig precision undefined: on SwiftShader and some mobile GPUs a raw cos/sin pair is far enough from unit length that rotations stop preserving distances.
mat2 rot2(float a) {
    vec2 cs = normalize(vec2(cos(a), sin(a)));
    return mat2(cs.x, cs.y, -cs.y, cs.x);
}

// ---- shader-skills library: color ----
// Relative luminance of linear Rec.709 / sRGB color.
float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// ---- shader ----
// --- FeedbackTransform: a feedback loop with a transform in it (the Feedback + Transform TOPs of TouchDesigner) ---
// Every frame the last output is zoomed, turned, moved, blurred, hue shifted and faded, then the input is put on
// top with the Blend mode. Small values (a zoom of 1.01, a turn of half a degree) add up to tunnels, spirals and
// trails. The values are per frame: at 60 fps a zoom of 1.01 grows the picture 1.8 times a second.
// Beat punch zooms in a bit more at the start of every beat (iTime counts beats in Sync).

// The picture that is fed into the loop
uniform sampler2D input;
// The last frame of this shader
uniform sampler2D feedback;

//@slider min=0.0 max=1.0 value=0.92
uniform float feedback_amount;      // how much of the last frame stays: 0 = no trails, 1 = nothing fades
//@slider min=0.9 max=1.1 value=1.01
uniform float zoom;                 // scale per frame: > 1 flies in, < 1 flies out
//@slider min=-10.0 max=10.0 value=0.5
uniform float rotate;               // degrees per frame
//@slidervec2 min=(-0.02,-0.02) max=(0.02,0.02) value=(0.0,0.0)
uniform vec2 move;                  // shift per frame, in parts of the picture
//@slidervec2 min=(0.0,0.0) max=(1.0,1.0) value=(0.5,0.5)
uniform vec2 center;                // the point zoom and rotate turn around
//@slider min=0.0 max=0.1 value=0.0
uniform float hue_shift;            // turns of the colour wheel per frame: rainbow trails
//@slider min=0.0 max=1.0 value=0.0
uniform float blur;                 // softens the trails a bit more every frame
//@slider min=0.0 max=1.0 value=0.0
uniform float beat_punch;           // extra zoom at every beat
//@enum options=(Lighten, Add, Screen, Key over, Mix) value=0
uniform int blend_mode;             // how the input goes on top of the trails
//@slider min=0.0 max=2.0 value=1.0
uniform float input_gain;
//@slider min=0.0 max=1.0 value=0.1
uniform float key_level;            // Key over: darker input pixels than this let the trails through
//@enum options=(Black, Repeat, Mirror, Clamp) value=0
uniform int edge_mode;              // what the zoom out shows beyond the border of the last frame
//@button
uniform bool reset;                 // clears the trails while it is on

// Hue rotation in YIQ space: keeps the brightness, turns the colour
vec3 hueRotate(vec3 c, float turns) {
    const mat3 toYIQ = mat3(0.299, 0.596, 0.211, 0.587, -0.274, -0.523, 0.114, -0.322, 0.312);
    const mat3 toRGB = mat3(1.0, 1.0, 1.0, 0.956, -0.272, -1.106, 0.621, -0.647, 1.703);
    vec3 yiq = toYIQ * c;
    yiq.yz = rot2(turns * TAU) * yiq.yz;
    return toRGB * yiq;
}

// The last frame at uv, with the edge mode for points outside of it
vec4 lastFrame(vec2 uv) {
    if (edge_mode == 1)
        uv = fract(uv);
    else if (edge_mode == 2)
        uv = 1.0 - abs(1.0 - mod(uv, 2.0));
    else if (edge_mode == 3)
        uv = clamp(uv, 0.0, 1.0);
    else if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0)
        return vec4(0.0);
    return texture(feedback, uv);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 src = texture(input, uv) * vec4(vec3(input_gain), 1.0);

    if (reset || iFrame < 2) {
        fragColor = vec4(src.rgb, 1.0);
        return;
    }

    // Where this pixel was in the last frame: the inverse of the transform, in square units around the center
    float punch = beat_punch * 0.06 * pow(1.0 - fract(iTime), 4.0);
    float z = max(zoom + punch, 0.01);
    vec2 aspect = vec2(iResolution.z, 1.0);
    vec2 p = (uv - center) * aspect;
    p = rot2(-radians(rotate)) * p / z;
    vec2 prev = p / aspect + center - move;

    vec4 fb = lastFrame(prev);
    if (blur > 0.0) {
        vec2 px = (0.5 + 2.0 * blur) / iResolution.xy;
        vec4 sum = lastFrame(prev + vec2(px.x, 0.0)) + lastFrame(prev - vec2(px.x, 0.0))
                 + lastFrame(prev + vec2(0.0, px.y)) + lastFrame(prev - vec2(0.0, px.y));
        fb = mix(fb, sum * 0.25, blur);
    }
    vec3 last = fb.rgb;
    if (hue_shift > 0.0)
        last = max(hueRotate(last, hue_shift), 0.0);
    vec3 trail = last * feedback_amount;

    vec3 col;
    if (blend_mode == 1)
        col = trail + src.rgb;
    else if (blend_mode == 2)
        col = 1.0 - (1.0 - clamp(trail, 0.0, 1.0)) * (1.0 - clamp(src.rgb, 0.0, 1.0));
    else if (blend_mode == 3)
        col = mix(trail, src.rgb, smoothstep(key_level, key_level + 0.05, luminance(src.rgb)) * src.a);
    else if (blend_mode == 4)
        col = mix(src.rgb, last, feedback_amount);
    else
        col = max(trail, src.rgb);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
