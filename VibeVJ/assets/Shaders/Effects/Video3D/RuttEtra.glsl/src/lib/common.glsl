// ---- RuttEtra: what the passes share ----
// The Rutt/Etra video synthesizer (1972) bent the scanlines of a video picture up by the brightness of the picture,
// so a face or a skyline turns into a landscape of glowing lines. Here every line is a row of the input, cut into
// Detail segments; each segment is a quad of the point pass L (draw=quads), lifted by the brightness under it and
// seen through a 3D camera. pointPixel draws the segment as a soft line (a Gaussian across, the integral of one along
// the segment), so the segments of a line add up without bright dots at the joints. B and B2 are the line picture at
// 1/4 and 1/16 of the size for the glow; __init__ adds it all up over the background. S keeps the music.
#include music.glsl

//@int min=8 max=600 value=110
uniform int lines;                  // how many scanlines (Grid: as many columns again)
//@int min=8 max=1024 value=300
uniform int detail;                 // segments a line is cut into: more follow the picture closer
//@enum options=(Horizontal, Vertical, Grid) value=0
uniform int line_mode;              // rows of the picture, columns, or both
//@slider min=0.0 max=2.0 value=0.55
uniform float displacement;         // how far the bright parts lift a line
//@enum options=(Up, Towards camera, Both) value=0
uniform int displace_direction;     // Up: the classic Rutt/Etra look, bent in the picture plane; Towards camera: a relief
//@enum options=(Brightness, Darkness, Red, Green, Blue, Saturation) value=0
uniform int displace_by;            // what of the picture lifts the line
//@slider min=0.0 max=1.0 value=0.0
uniform float cutoff;               // lines are blanked where the picture is darker than this (a key)
//@slider min=0.0 max=0.02 value=0.006
uniform float smoothing;            // blurs the picture along the line (parts of the picture), against jitter
//@slider min=-2.0 max=2.0 value=0.0
uniform float scroll;               // the lines roll through the picture, in line spacings per beat

//@slider min=0.3 max=8.0 value=1.6
uniform float thickness;            // line width in pixels at 1080p
//@slider min=0.0 max=4.0 value=1.0
uniform float brightness;
//@slider min=0.0 max=1.0 value=0.65
uniform float brightness_by_picture; // 0: every line equally bright; 1: dark parts of the picture dim the line
//@slider min=0.0 max=3.0 value=0.8
uniform float glow;                 // the soft light around the lines
//@slider min=0.0 max=1.0 value=0.5
uniform float glow_size;            // 0 a tight halo, 1 a wide haze
//@enum options=(Picture, Gradient, Single colour, Picture x colour) value=0
uniform int color_mode;             // Gradient: Color A on dark parts to Color B on bright ones
//@rgb value=(0.05, 0.35, 1.0)
uniform vec3 color_a;
//@rgb value=(1.0, 0.25, 0.75)
uniform vec3 color_b;
//@slider min=0.0 max=3.0 value=1.35
uniform float saturation_boost;     // more colour from the picture (1 = as it is)
//@slider min=0.0 max=1.0 value=0.55
uniform float depth_fade;           // far lines get darker

//@slider min=-80.0 max=80.0 value=24.0
uniform float camera_tilt;          // degrees: looks down onto the picture
//@slider min=-180.0 max=180.0 value=-16.0
uniform float camera_turn;          // degrees around the picture
//@slider min=0.0 max=45.0 value=10.0
uniform float camera_sway;          // degrees the camera rocks to and fro over 16 beats
//@slider min=-2.0 max=2.0 value=0.0
uniform float camera_orbit;         // turns around the picture per 16 beats
//@slider min=1.2 max=12.0 value=3.0
uniform float camera_distance;      // small: strong perspective; the size stays the same
//@slider min=0.2 max=4.0 value=0.85
uniform float zoom;

//@slider min=0.0 max=2.0 value=0.8
uniform float bass_displace;        // the bass (or the kick of the beat) lifts the lines further
//@slider min=0.0 max=2.0 value=0.6
uniform float beat_flash;           // lines flash on the beat (every Beat every-th)
//@slider min=0.0 max=1.0 value=0.05
uniform float wave;                 // the waveform of the sound wobbles the lines like an oscilloscope

//@enum options=(Colour, Transparent, Picture) value=0
uniform int background_mode;        // Transparent: alpha 0 where no line is, for Add or Over; Picture: the input behind
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background_color;
//@slider min=0.0 max=1.0 value=0.25
uniform float picture_behind;       // Background mode Picture: how bright the input shows behind the lines
//@slider min=0.2 max=4.0 value=1.4
uniform float exposure;

float lumaOf(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// The value of a colour that lifts the line (Displace by)
float liftOf(vec3 c) {
    if (displace_by == 1) return 1.0 - lumaOf(c);
    if (displace_by == 2) return c.r;
    if (displace_by == 3) return c.g;
    if (displace_by == 4) return c.b;
    if (displace_by == 5) {
        float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b));
        return mx > 1e-4 ? (mx - mn) / mx : 0.0;
    }
    return lumaOf(c);
}

// The camera: a world point to normalised device coordinates (x, y), and its distance in front of the camera (z)
vec3 project(vec3 p, float aspect) {
    float t = iTime / 16.0;
    float yaw = radians(camera_turn + camera_sway * sin(MUSIC_TAU * t)) + MUSIC_TAU * camera_orbit * t;
    float pitch = -radians(camera_tilt);
    p.xz = vec2(cos(yaw) * p.x + sin(yaw) * p.z, -sin(yaw) * p.x + cos(yaw) * p.z);
    p.yz = vec2(cos(pitch) * p.y - sin(pitch) * p.z, sin(pitch) * p.y + cos(pitch) * p.z);
    float zc = camera_distance - p.z;
    float f = zoom * camera_distance * 0.92;
    return vec3(p.x * f / max(zc, 1e-3) / aspect, p.y * f / max(zc, 1e-3), zc);
}

// A texture of a pass at uv, bilinear (the textures of passes are nearest)
vec4 passBilinear(sampler2D s, vec2 uv) {
    ivec2 sz = textureSize(s, 0);
    vec2 p = uv * vec2(sz) - 0.5;
    vec2 i = floor(p);
    vec2 f = p - i;
    ivec2 a = ivec2(i);
    ivec2 mx = sz - 1;
    vec4 c00 = texelFetch(s, clamp(a, ivec2(0), mx), 0);
    vec4 c10 = texelFetch(s, clamp(a + ivec2(1, 0), ivec2(0), mx), 0);
    vec4 c01 = texelFetch(s, clamp(a + ivec2(0, 1), ivec2(0), mx), 0);
    vec4 c11 = texelFetch(s, clamp(a + ivec2(1, 1), ivec2(0), mx), 0);
    return mix(mix(c00, c10, f.x), mix(c01, c11, f.x), f.y);
}
// A soft blur of a pass around uv: 4 bilinear taps, about 3 x 3 texels
vec4 passSoft(sampler2D s, vec2 uv) {
    vec2 px = 1.0 / vec2(textureSize(s, 0));
    return 0.25 * (passBilinear(s, uv + vec2(-0.75, -0.75) * px) + passBilinear(s, uv + vec2(0.75, -0.75) * px)
                 + passBilinear(s, uv + vec2(-0.75, 0.75) * px) + passBilinear(s, uv + vec2(0.75, 0.75) * px));
}
// The mean of the 4 x 4 texels of s that this texel of a pass 4 times smaller covers
vec4 box4(sampler2D s, vec2 fragCoord) {
    ivec2 base = ivec2(floor(fragCoord)) * 4;
    ivec2 mx = textureSize(s, 0) - 1;
    vec4 sum = vec4(0.0);
    for (int y = 0; y < 4; y++)
        for (int x = 0; x < 4; x++)
            sum += texelFetch(s, min(base + ivec2(x, y), mx), 0);
    return sum / 16.0;
}
