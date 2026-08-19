// ==== Custom Uniform Controls ====

//@vec2 min=(0.01,0.01) max=(1.0,1.0) value=(0.2,0.2)
uniform vec2 dotgrid_spacing;

//@float min=0.001 max=0.5 value=0.05
uniform float dot_size;

//@float min=0.0 max=0.5 value=0.05
uniform float dot_softness;

//@enum options=(Circle, Square, Diamond)
uniform int dot_shape;

//@rgb value=(0.0,0.0,0.0)
uniform vec3 dot_color;

//@rgb value=(1.0,1.0,1.0)
uniform vec3 bg_color;

//@float min=-180.0 max=180.0 value=0.0
uniform float dot_rotation;

//@float min=0.1 max=10.0 value=1.0
uniform float zoom;

//@vec2 min=(-2.0,-2.0) max=(2.0,2.0) value=(0.0,0.0)
uniform vec2 pan;

//@vec2 min=(0.0,0.0) max=(1.0,1.0) value=(0.0,0.0)
uniform vec2 dot_phase;

//@int min=0 max=1 value=0
uniform int enable_warp;

//@int min=0 max=1 value=1
uniform int warp_animate;

//@float min=-10.0 max=10.0 value=1.0
uniform float warp_anim_speed;

//@float min=0.0 max=1.0 value=0.1
uniform float warp_amplitude_x;

//@float min=0.0 max=1.0 value=0.1
uniform float warp_amplitude_y;

//@float min=0.1 max=50.0 value=10.0
uniform float warp_frequency_x;

//@float min=0.1 max=50.0 value=10.0
uniform float warp_frequency_y;

//@float min=0.0 max=6.283185 value=0.0
uniform float warp_phase_x;

//@float min=0.0 max=6.283185 value=0.0
uniform float warp_phase_y;

//@enum options=(Sine, Cosine, Sine+Cosine)
uniform int warp_mode;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv -= 0.5;
    uv.x *= iResolution.x / iResolution.y;

    // Apply zoom and pan
    uv *= zoom;
    uv += pan;

    // Apply rotation
    float angle = radians(dot_rotation);
    mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
    uv = rot * uv;

    // Apply phase offset
    uv += dot_phase;

    // Time value (beat synced)
    float time = iTime * warp_anim_speed * 6.283185;

    if (enable_warp == 1)
    {
        float warpX = 0.0;
        float warpY = 0.0;

        if (warp_mode == 0) // sine
        {
            warpX = sin(uv.y * warp_frequency_x + time + warp_phase_x) * warp_amplitude_x;
            warpY = sin(uv.x * warp_frequency_y + time + warp_phase_y) * warp_amplitude_y;
        }
        else if (warp_mode == 1) // cosine
        {
            warpX = cos(uv.y * warp_frequency_x + time + warp_phase_x) * warp_amplitude_x;
            warpY = cos(uv.x * warp_frequency_y + time + warp_phase_y) * warp_amplitude_y;
        }
        else if (warp_mode == 2) // sine + cosine
        {
            warpX = (sin(uv.y * warp_frequency_x + time + warp_phase_x) + cos(uv.y * warp_frequency_x * 1.5 + time * 1.3)) * 0.5 * warp_amplitude_x;
            warpY = (sin(uv.x * warp_frequency_y + time + warp_phase_y) + cos(uv.x * warp_frequency_y * 1.5 + time * 1.3)) * 0.5 * warp_amplitude_y;
        }

        uv.x += warpX;
        uv.y += warpY;
    }

    // Compute dot grid cell position
    vec2 cell = mod(uv, dotgrid_spacing) - 0.5 * dotgrid_spacing;
    float dist = length(cell);

    float mask = 0.0;
    if (dot_shape == 0) {
        // Circle
        mask = smoothstep(dot_size, dot_size - dot_softness, dist);
    } else if (dot_shape == 1) {
        // Square
        vec2 d = abs(cell);
        vec2 edge = smoothstep(dot_size, dot_size - dot_softness, d);
        mask = max(edge.x, edge.y);
    } else if (dot_shape == 2) {
        // Diamond (manhattan distance)
        float mdist = abs(cell.x) + abs(cell.y);
        mask = smoothstep(dot_size, dot_size - dot_softness, mdist);
    }

    vec3 color = mix(dot_color, bg_color, mask);
    fragColor = vec4(color, 1.0);
}
