// SFX1 FlyingForms - Pass 2 (LAYER 1 + blur/composite over layer1)
// Shadertoy format
// Draws a second offset layer of flying forms on top of the first layer,
// then softens the whole thing with a small blur and composites over the background.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Cascaded output of pass 1, auto-bound by name
uniform sampler2D layer1;

// Number of forms in the second layer
//@int min=1 max=32 value=6
uniform int form_count_2;

// Number of orbiting groups for layer 1 (FireCircles-style)
//@int min=1 max=16 value=3
uniform int group_count_2;

// Forms per group for layer 1 (FireCircles-style)
//@int min=1 max=8 value=2
uniform int group_size_2;

// Distance of forms around the group center for layer 1 (FireCircles-style)
//@slider min=0.0 max=1.0 value=0.12
uniform float group_radius_2;

// Randomness of inter-group orbital radius for layer 1 (FireCircles-style)
//@slider min=0.0 max=1.0 value=0.5
uniform float group_random_2;

// Base orbital radius of groups for layer 1 (FireCircles-style)
//@slider min=0.0 max=1.0 value=0.5
uniform float orbit_radius_2;

// Angular offset of the group ring for layer 1 (FireCircles-style)
//@slider min=0.0 max=6.28 value=1.5
uniform float group_offset_angle_2;

// Rotation speed of the group ring for layer 1 (FireCircles-style)
//@slider min=0.0 max=6.28 value=0.3
uniform float group_speed_2;

// Angular offset of forms within a group for layer 1 (FireCircles-style)
//@slider min=0.0 max=6.28 value=0.8
uniform float object_offset_angle_2;

// Smallest / largest size for layer 1
//@slider min=0.02 max=0.5 value=0.08
uniform float size_min_2;
//@slider min=0.05 max=0.6 value=0.35
uniform float size_max_2;

// Shape for layer 1 (can differ from layer 0)
//@enum options=(Circle, Square, Diamond, Triangle) value=1
uniform int form_type_2;

// Edge smoothness for layer 1
//@slider min=0.01 max=0.5 value=0.08
uniform float smoothness_2;

// Static rotation offset for layer 1
//@slider min=0.0 max=1.0 value=0.25
uniform float rotation_2;

// Rotation speed for layer 1
//@slider min=-3.0 max=3.0 value=0.7
uniform float rot_speed_2;

// Foreground colour of layer 1
//@rgb value=(1.0,0.85,0.2)
uniform vec3 fore_color_2;

// Background colour
//@rgb value=(0.02,0.02,0.05)
uniform vec3 background;

// Layer blur amount (0 = sharp)
//@slider min=0.0 max=1.0 value=0.2
uniform float layer_blur;

// Number of blur taps
//@int min=2 max=8 value=4
uniform int blur_taps;

#include helper.glsl

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 wuv = uv * 2.0 - 1.0;

    // Draw the second layer of flying forms with an offset phase (0.5)
    vec3 col = draw_flying_forms(
        wuv, form_count_2, size_min_2, size_max_2,
        group_count_2, group_size_2, group_radius_2, group_random_2, orbit_radius_2,
        group_offset_angle_2, group_speed_2, object_offset_angle_2,
        form_type_2, smoothness_2, rotation_2, rot_speed_2, 0.5, fore_color_2
    );

    // Small box blur applied to the accumulated colour + the previous layer
    vec3 base = texture(layer1, uv).rgb;
    vec3 acc = vec3(0.0);
    float radius = layer_blur * 4.0;
    float count = 0.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 off = vec2(x, y) * radius / iResolution.xy;
            if (abs(float(x)) <= blur_taps && abs(float(y)) <= blur_taps) {
                acc += texture(layer1, uv + off).rgb;
                count += 1.0;
            }
        }
    }
    vec3 blurred = (count > 0.0) ? acc / count : base;

    // Composite layer 2 over the blurred layer 1
    vec3 outcol = max(blurred, col);
    outcol = max(background, outcol);

    fragColor = vec4(outcol, 1.0);
}
