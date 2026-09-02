//@settings dtype=float32 format=rgba rendersize=(1280,720)

//@rgb value=(0.04,0.03,0.06)
uniform vec3 background;
//@slider min=0.0 max=1.0 value=0.5
uniform float morph_strength;
//@slider min=0.1 max=3.0 value=1.0
uniform float scale;
//@slider min=0.5 max=1.0 value=0.9
uniform float smoothness;
//@int min=1 max=32 value=12
uniform int count;
//@slider min=0.0 max=0.99 value=0.4
uniform float trail_length;   // feedback fade (higher = longer trail)
//@int min=1 max=8 value=3
uniform int group_size;      // circles per orbiting group
//@slider min=0.0 max=1.0 value=0.08
uniform float group_radius;   // distance of a group's circles around the group's own center
//@slider min=0.0 max=1.0 value=0.3
uniform float group_random;   // randomness of the distance between groups (orbital radius)
//@slider min=0.0 max=1.0 value=0.4
uniform float orbit_radius;   // base orbital radius (independent of object size / scale)
//@rgb value=(1.0,0.5,0.05)
uniform vec3 fore_color;      // foreground colour of the fire objects
//@int min=1 max=16 value=4
uniform int group_count;       // number of groups; their start points are distributed on a circle around the center
//@slider min=0.0 max=6.28 value=0.0
uniform float group_offset_angle;  // angular offset of the group ring (shifts all group start points)
//@slider min=0.0 max=2.0 value=0.4
uniform float group_speed;         // rotation speed of the group circle
//@slider min=0.0 max=6.28 value=0.0
uniform float object_offset_angle; // angular offset of the objects within a group

// motion trails: bind to previous frame of this pass
uniform sampler2D feedback;

#define PI 3.141592653589793

float fire_glow(float d, float radius) {
    // d = distance to circle center, radius = fire radius
    float t = 1.0 - clamp(d / radius, 0.0, 1.0);
    return pow(t, 2.0) * smoothness;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv = uv * 2.0 - 1.0;

    float morph = morph_strength * (0.5 + 0.5 * sin(iTime * 0.6));
    // scale drives only the SIZE of the individual fire objects
    // orbital radius is set separately via orbit_radius (smaller default)
    float orbitR = orbit_radius * (0.7 + 0.3 * morph);
    float fireR = 0.12 * scale;
    float ng = float(max(group_size, 1));
    float nGroups = float(max(group_count, 1));

    vec3 col = vec3(0.0);

    for (int i = 0; i < 32; i++) {
        if (i >= count) break;
        float fi = float(i);
        // group the circles: circles within a group share a common orbit angle
        float group = floor(fi / ng);
        if (group >= nGroups) break;   // only the first group_count groups
        float inGroup = fi - group * ng;
        // randomized inter-group distance: each group's orbital radius varies
        float gseed = fract(sin((group + 1.0) * 12.9898) * 43758.5453);
        float groupR = orbitR * (1.0 + (gseed - 0.5) * 2.0 * group_random);
        // distribute group start points evenly on a circle around the center
        // group_offset_angle shifts all start points; group_speed rotates the ring
        float groupAngle = (6.2831853 * group / nGroups) + group_offset_angle + iTime * group_speed;
        vec2 groupCenter = vec2(cos(groupAngle), sin(groupAngle)) * groupR;
        // each circle sits at group_radius from its group's center, with object_offset_angle
        float a = (inGroup / ng) * (6.2831853 / ng) + object_offset_angle;
        vec2 center = groupCenter + vec2(cos(a), sin(a)) * (group_radius * scale);
        float d = length(uv - center);
        float g = fire_glow(d, fireR * (0.8 + 0.4 * morph));
        // fire color gradient: white/yellow core -> chosen foreground colour at the edge
        float t = clamp(1.0 - d / fireR, 0.0, 1.0);
        vec3 firecol = mix(vec3(1.0, 0.9, 0.4), fore_color, 1.0 - t);
        col += firecol * g;
    }

    // trail: keep previous frame faded by trail_length
    vec3 prev = texture(feedback, fragCoord / iResolution.xy, 0.0).rgb;
    vec3 bg = background;
    vec3 outcol = max(bg, max(col, prev * trail_length));

    fragColor = vec4(outcol, 1.0);
}
