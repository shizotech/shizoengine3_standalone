//@settings dtype=float32 format=rgba

// FixtureGlow: the lamps of the fixture setup as soft glows, in the colour they are sent.
// Link the Out of a FixtureState generator into the input "fixtures". Each lamp sits where it hangs on the stage
// plan: left to right by its x, up by its height (z); a Phaser on the lamps (or on virtual lamps) plays here too.
// FixtureState texture: one column per lamp; row 0 = colour x dimmer (rgb) and dimmer (a), row 1 = x, y, z in metres.

uniform sampler2D fixtures;

//@slider min=0.01 max=0.5 value=0.12
uniform float glow_size;

//@slider min=0.0 max=4.0 value=1.5
uniform float intensity;

//@slider min=0.0 max=1.0 value=0.5
uniform float height_amount;

//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 bg_color;

const int MAX_LAMPS = 128;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / max(iResolution.y, 1.0);
    int count = min(textureSize(fixtures, 0).x, MAX_LAMPS);

    // The extent of the rig on the plan, so the lamps fill the width
    float min_x = 1e6, max_x = -1e6, max_z = 0.0;
    for (int i = 0; i < count; i++) {
        vec3 pos = texelFetch(fixtures, ivec2(i, 1), 0).xyz;
        min_x = min(min_x, pos.x);
        max_x = max(max_x, pos.x);
        max_z = max(max_z, pos.z);
    }
    float span = max(max_x - min_x, 1.0);

    vec3 col = bg_color;
    for (int i = 0; i < count; i++) {
        vec4 light = texelFetch(fixtures, ivec2(i, 0), 0);
        if (light.a <= 0.0 && dot(light.rgb, vec3(1.0)) <= 0.0)
            continue;
        vec3 pos = texelFetch(fixtures, ivec2(i, 1), 0).xyz;
        // One lamp in the middle, several spread over 10 % .. 90 % of the width
        float x = count > 1 ? mix(0.1, 0.9, (pos.x - min_x) / span) : 0.5;
        float y = 0.5 + height_amount * (max_z > 0.0 ? (pos.z / max_z - 0.5) * 0.6 : 0.0);
        vec2 d = (uv - vec2(x, y)) * vec2(aspect, 1.0);
        float r = length(d) / glow_size;
        col += light.rgb * intensity * exp(-r * r * 2.0);
    }

    fragColor = vec4(col, 1.0);
}
