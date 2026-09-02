// SFX1 FlyingForms - Pass 1 (LAYER 0)
// Shadertoy format
// Draws the first layer of flying forms.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Number of forms in this layer
//@int min=1 max=32 value=12
uniform int form_count;

// Number of orbiting groups (FireCircles-style)
//@int min=1 max=16 value=4
uniform int group_count;

// Forms per group (FireCircles-style)
//@int min=1 max=8 value=3
uniform int group_size;

// Distance of forms around the group center (FireCircles-style)
//@slider min=0.0 max=1.0 value=0.08
uniform float group_radius;

// Randomness of inter-group orbital radius (FireCircles-style)
//@slider min=0.0 max=1.0 value=0.4
uniform float group_random;

// Base orbital radius of groups around screen center (FireCircles-style)
//@slider min=0.0 max=1.0 value=0.3
uniform float orbit_radius;

// Angular offset of the group ring (FireCircles-style)
//@slider min=0.0 max=6.28 value=0.0
uniform float group_offset_angle;

// Rotation speed of the group ring (FireCircles-style)
//@slider min=0.0 max=6.28 value=0.4
uniform float group_speed;

// Angular offset of forms within a group (FireCircles-style)
//@slider min=0.0 max=6.28 value=0.0
uniform float object_offset_angle;

// Smallest symbol size in this layer
//@slider min=0.02 max=0.5 value=0.05
uniform float size_min;

// Largest symbol size in this layer
//@slider min=0.05 max=0.6 value=0.2
uniform float size_max;

// Shape of the flying symbols
//@enum options=(Circle, Square, Diamond, Triangle) value=0
uniform int form_type;

// Edge smoothness
//@slider min=0.01 max=0.5 value=0.05
uniform float smoothness;

// Static rotation offset (0..1 = 0..360deg)
//@slider min=0.0 max=1.0 value=0.0
uniform float rotation;

// Rotation speed
//@slider min=-3.0 max=3.0 value=0.4
uniform float rot_speed;

// Foreground colour of the forms
//@rgb value=(0.3,0.7,1.0)
uniform vec3 fore_color;

// Background colour
//@rgb value=(0.02,0.02,0.05)
uniform vec3 background;

#include helper.glsl

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv = uv * 2.0 - 1.0;

    vec3 col = draw_flying_forms(
        uv, form_count, size_min, size_max,
        group_count, group_size, group_radius, group_random, orbit_radius,
        group_offset_angle, group_speed, object_offset_angle,
        form_type, smoothness, rotation, rot_speed, 0.0, fore_color
    );

    vec3 bg = background;
    vec3 outcol = max(bg, col);
    fragColor = vec4(outcol, 1.0);
}
