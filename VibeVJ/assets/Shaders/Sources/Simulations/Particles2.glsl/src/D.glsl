//@settings draw=points count=particles blend=add dtype=float16 format=rgba
// --- Particles 2, pass D: draws every particle as a GL point (SHADER_GUIDE.MD, Point passes) ---
// mainPoint runs once a particle (in the vertex shader): it reads the particle from S, puts it through the camera and
// gives its size and colour; pointPixel gives the shape. The points add up in a float picture, __init__ tonemaps it.
#include lib/common.glsl

uniform sampler2D S;

//@enum options=(Orbit 3D, Flat) value=0
uniform int view;                   // Flat: the picture plane, x and y as they are, no depth
//@slider min=1.0 max=10.0 value=3.2
uniform float camera_distance;
//@slider min=-89.0 max=89.0 value=18.0
uniform float camera_height;        // degrees above the horizon
//@slider min=0.0 max=360.0 value=0.0
uniform float camera_angle;         // degrees around the upright axis
//@slider min=-30.0 max=30.0 value=3.0
uniform float camera_spin;          // degrees a beat
//@slider min=0.2 max=4.0 value=1.0
uniform float zoom;
//@slider min=0.5 max=16.0 value=1.3
uniform float point_size;           // pixels of a 1080p picture, at the distance of the camera
//@slider min=0.0 max=1.0 value=0.5
uniform float size_random;
//@enum options=(Soft dot, Hard dot, Glow, Square, Spark) value=0
uniform int point_shape;            // shows on points bigger than 3 pixels
//@slider min=0.0 max=2.0 value=0.4
uniform float brightness;           // the light of one particle: many add up, so less is more
//@enum options=(By age, By speed, Random, From field, By height, Single color) value=0
uniform int color_mode;             // from Color A to Color B; From field: the colour of the port Field
//@rgb value=(1.0, 0.55, 0.2)
uniform vec3 color_a;
//@rgb value=(0.25, 0.45, 1.0)
uniform vec3 color_b;
//@slider min=0.0 max=2.0 value=0.4
uniform float depth_fade;           // particles behind the middle get darker

void mainPoint(int id, inout vec4 position, inout float size, inout vec4 color, inout vec4 data) {
    if (id >= particles)
        return;                     // the default position is outside of the picture: not drawn
    ivec2 c = ivec2(id % SIM_W, id / SIM_W);
    vec4 A = texelFetch(S, c, 0);
    vec4 B = texelFetch(S, c + ivec2(0, SIM_H), 0);
    float life = B.w;
    if (!(life > 0.0) || A.w >= life)
        return;
    float t = clamp(A.w / life, 0.0, 1.0);
    float aspect = iResolution.z;
    vec4 rnd = rand4(id, 5);

    float scale = 1.0;
    float fog = 1.0;
    vec2 ndc;
    if (view == 1) {
        ndc = vec2(A.x / aspect, A.y) * zoom;
        scale = zoom;
    } else {
        float yaw = radians(camera_angle + camera_spin * iTime);
        float pitch = radians(camera_height);
        vec3 q = A.xyz;
        q.xz = vec2(cos(yaw) * q.x - sin(yaw) * q.z, sin(yaw) * q.x + cos(yaw) * q.z);
        q.yz = vec2(cos(pitch) * q.y - sin(pitch) * q.z, sin(pitch) * q.y + cos(pitch) * q.z);
        float z = camera_distance - q.z;            // the camera looks along -z from (0, 0, distance)
        if (z < 0.05)
            return;
        float focal = 1.8 * zoom;
        ndc = q.xy * focal / z;
        ndc.x /= aspect;
        scale = camera_distance / z * zoom;
        fog = exp(-max(z - camera_distance, 0.0) * depth_fade);
    }
    position = vec4(ndc, 0.0, 1.0);
    size = point_size * iResolution.y / 1080.0 * scale * (1.0 + size_random * (rnd.x * 1.6 - 0.8));

    vec3 tint;
    if (color_mode == 0)
        tint = mix(color_a, color_b, t);
    else if (color_mode == 1)
        tint = mix(color_b, color_a, clamp(length(B.xyz) / max(start_speed + burst_speed * 0.5, 0.2), 0.0, 1.0));
    else if (color_mode == 2)
        tint = mix(color_a, color_b, rnd.y);
    else if (color_mode == 3)
        tint = textureLod(field, worldToUv(A.xy, aspect), 0.0).rgb;
    else if (color_mode == 4)
        tint = mix(color_b, color_a, clamp(A.y * 0.5 + 0.5, 0.0, 1.0));
    else
        tint = color_a;
    float fade = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.7, 1.0, t));
    float light = brightness * fade * fog;
    color = vec4(tint * light, light);
}

vec4 pointPixel(vec4 color, vec4 data, vec2 coord) {
    vec2 d = coord * 2.0 - 1.0;
    float r2 = dot(d, d);
    float a;
    if (point_shape == 0)
        a = 1.0 - smoothstep(0.2, 1.0, r2);
    else if (point_shape == 1)
        a = r2 <= 1.0 ? 1.0 : 0.0;
    else if (point_shape == 2)
        a = exp(-5.0 * r2);
    else if (point_shape == 3)
        a = 1.0;
    else
        a = max(1.0 - abs(d.x) * 5.0, 0.0) * (1.0 - abs(d.y)) + max(1.0 - abs(d.y) * 5.0, 0.0) * (1.0 - abs(d.x));
    return color * a;
}
