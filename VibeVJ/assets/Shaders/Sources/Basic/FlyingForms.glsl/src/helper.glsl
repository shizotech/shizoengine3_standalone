// Shared helper for the FlyingForms source effect (SFX1)
// Draws forms flying across the screen in multiple layers,
// using FireCircles-style group orbiting (groups orbit around center,
// forms orbit within each group).

// distance-based SDF for a shape, returning a signed distance from center
float sd_shape(vec2 uv, int form_type, float size) {
    uv = uv / size;
    float d;
    if (form_type == 0) {
        // Circle
        d = length(uv) - 1.0;
    } else if (form_type == 1) {
        // Square
        vec2 a = abs(uv) - 1.0;
        d = length(max(a, 0.0)) + min(max(a.x, a.y), 0.0) - 1.0;
    } else if (form_type == 2) {
        // Diamond
        vec2 a = abs(uv);
        d = (a.x + a.y) - 1.0;
    } else {
        // Triangle
        d = (abs(uv.x) + uv.y) - 1.0;
    }
    return d * size;
}

// Draws all flying forms for one layer using FireCircles-style grouping:
//  - group_count groups orbit around the screen center at orbit_radius
//  - Each group contains group_size forms at group_radius around the group center
//  - Per-form deterministic size between size_min and size_max
//  - Per-form rotation driven by rot_speed
// FireCircles-style controls:
//  - group_count, group_size, group_radius, group_random, orbit_radius
//  - group_offset_angle, group_speed, object_offset_angle
vec3 draw_flying_forms(vec2 uv,
                        int count, float size_min, float size_max,
                        int group_count, int group_size, float group_radius,
                        float group_random, float orbit_radius,
                        float group_offset_angle, float group_speed, float object_offset_angle,
                        int form_type, float smoothness, float rotation, float rot_speed,
                        float layer_phase, vec3 base_color) {
    vec3 col = vec3(0.0);
    float ng = float(max(group_size, 1));
    float nGroups = float(max(group_count, 1));

    for (int i = 0; i < 32; i++) {
        if (i >= count) break;
        float fi = float(i);

        // Group this form into a group (FireCircles-style)
        float group = floor(fi / ng);
        if (group >= nGroups) break;   // only first group_count groups
        float inGroup = fi - group * ng;

        // Randomized inter-group orbital radius (FireCircles group_random)
        float gseed = fract(sin((group + 1.0) * 12.9898) * 43758.5453);
        float groupR = orbit_radius * (1.0 + (gseed - 0.5) * 2.0 * group_random);

        // Distribute group start points evenly on a circle around the center
        // group_offset_angle shifts all start points; group_speed rotates the ring
        float groupAngle = (6.2831853 * group / nGroups) + group_offset_angle + iTime * group_speed + layer_phase * 0.7;
        vec2 groupCenter = vec2(cos(groupAngle), sin(groupAngle)) * groupR;

        // Each form sits at group_radius from its group center (FireCircles-style)
        float a = (inGroup / ng) * (6.2831853 / ng) + object_offset_angle;
        vec2 center = groupCenter + vec2(cos(a), sin(a)) * group_radius;

        // Per-form size chosen between size_min and size_max (deterministic per form)
        float sizeSeed = fract(sin(fi * 12.9898 + layer_phase * 7.13) * 43758.5453);
        float size = mix(size_min, size_max, sizeSeed) * (0.8 + 0.2 * sin(iTime * 0.4 + fi));

        // Per-form rotation (FireCircles-style)
        float ang = rotation * 6.2831853 + iTime * rot_speed + fi * 0.5;
        float ca = cos(ang);
        float sa = sin(ang);
        vec2 duv = uv - center;
        vec2 ruv = vec2(duv.x * ca - duv.y * sa, duv.x * sa + duv.y * ca);

        float d = sd_shape(ruv, form_type, size);
        float cover = 1.0 - smoothstep(-smoothness, smoothness, d);
        col += base_color * cover * 1.2;
    }
    return col;
}
