// ---- PointCloud: what the passes share ----
// The picture as a cloud of dots in 3D: Columns x Rows points, one for each cell of the picture, each pushed towards
// the camera by the brightness (or a channel) under it, seen through an orbiting camera. Pass P draws them as real
// points (draw=points: the graphics card puts each dot where it belongs, so the cost is the number of points, not
// where they are), adding up like light. On the beat they burst apart and spring back. B and B2 are the dots at 1/4
// and 1/16 of the size for the glow; __init__ adds it all up over the background. S keeps the music.
#include music.glsl

//@int min=8 max=1920 value=320
uniform int columns;                // points across the picture
//@int min=8 max=1080 value=180
uniform int rows;                   // points down the picture (Columns x Rows points in all)
//@slider min=0.5 max=24.0 value=3.6
uniform float point_size;           // pixels at 1080p, for a point in the middle of the cloud
//@slider min=0.0 max=1.0 value=0.5
uniform float size_by_brightness;   // bright points bigger, dark ones smaller
//@enum options=(Soft dot, Disc, Square, Ring) value=0
uniform int point_shape;
//@slider min=0.0 max=1.0 value=0.45
uniform float jitter;               // moves each point at random inside its cell: a cloud instead of a grid
//@slider min=0.0 max=1.0 value=0.04
uniform float threshold;            // points on parts darker than this are left out

//@slider min=-2.0 max=2.0 value=0.8
uniform float depth;                // how far the bright parts come towards the camera
//@enum options=(Brightness, Darkness, Red, Green, Blue, Saturation) value=0
uniform int depth_by;               // what of the picture sets the depth
//@slider min=0.0 max=1.0 value=0.12
uniform float turbulence;           // the points drift in a slow flow

//@slider min=0.0 max=3.0 value=0.7
uniform float explode;              // how far the points burst apart on the beat (every Beat every-th), then spring back
//@enum options=(Random, Outwards, Towards camera, Swirl) value=0
uniform int explode_mode;           // the direction they fly
//@slider min=0.0 max=1.0 value=0.35
uniform float explode_spread;       // the burst starts in the middle and runs outwards (0: all at once)
//@slider min=0.5 max=6.0 value=1.8
uniform float spring;               // how fast they swing back (swings a second)
//@slider min=0.0 max=2.0 value=0.6
uniform float bass_depth;           // the bass (or the kick of the beat) pushes the depth further
//@slider min=0.0 max=2.0 value=0.5
uniform float beat_flash;           // the points flash on the beat

//@enum options=(Picture, Gradient, Single colour, Picture x colour) value=0
uniform int color_mode;             // Gradient: Color A far / dark to Color B near / bright
//@rgb value=(0.1, 0.45, 1.0)
uniform vec3 color_a;
//@rgb value=(1.0, 0.3, 0.65)
uniform vec3 color_b;
//@slider min=0.0 max=3.0 value=1.3
uniform float saturation_boost;     // more colour from the picture (1 = as it is)
//@slider min=0.0 max=4.0 value=1.2
uniform float brightness;
//@slider min=0.0 max=1.0 value=0.6
uniform float brightness_by_picture; // 0: every point equally bright; 1: dark parts of the picture dim the point
//@slider min=0.0 max=3.0 value=0.6
uniform float glow;
//@slider min=0.0 max=1.0 value=0.4
uniform float glow_size;            // 0 a tight halo, 1 a wide haze
//@slider min=0.0 max=1.0 value=0.5
uniform float depth_fade;           // far points get darker

//@slider min=-80.0 max=80.0 value=18.0
uniform float camera_tilt;          // degrees: looks down onto the cloud
//@slider min=-180.0 max=180.0 value=-24.0
uniform float camera_turn;          // degrees around the cloud
//@slider min=0.0 max=60.0 value=18.0
uniform float camera_sway;          // degrees the camera rocks to and fro over 16 beats
//@slider min=-2.0 max=2.0 value=0.0
uniform float camera_orbit;         // turns around the cloud per 16 beats
//@slider min=1.2 max=12.0 value=3.0
uniform float camera_distance;      // small: strong perspective; the size stays the same
//@slider min=0.2 max=4.0 value=0.9
uniform float zoom;

//@enum options=(Colour, Transparent, Picture) value=0
uniform int background_mode;        // Transparent: alpha 0 where no point is, for Add or Over; Picture: the input behind
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background_color;
//@slider min=0.0 max=1.0 value=0.2
uniform float picture_behind;       // Background mode Picture: how bright the input shows behind the points
//@slider min=0.2 max=4.0 value=1.3
uniform float exposure;

float lumaOf(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// The value of a colour that sets the depth (Depth by)
float depthOf(vec3 c) {
    if (depth_by == 1) return 1.0 - lumaOf(c);
    if (depth_by == 2) return c.r;
    if (depth_by == 3) return c.g;
    if (depth_by == 4) return c.b;
    if (depth_by == 5) {
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
