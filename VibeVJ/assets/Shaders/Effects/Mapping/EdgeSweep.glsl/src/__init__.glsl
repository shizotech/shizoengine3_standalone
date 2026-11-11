//@settings dtype=float32 format=rgba
// --- EdgeSweep (#586, projection mapping building blocks) ---
// Lights the outlines of the input picture and / or of a mask and runs light along them: sweeps across the picture,
// rings from a point, a radar around it, comets that trace every contour, a flash at each pulse, sparkles.
// The outlines are found at half size (passes M, E) and spread to every pixel by a jump flood (J1..J10), so the
// line width and the glow are exact in pixels and cost the same however many outlines there are.
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D M;
uniform sampler2D J10;
uniform sampler2D R;
uniform sampler2D T;

//@slider min=0.5 max=24.0 value=2.5
uniform float line_width;      // pixels
//@slider min=0.0 max=120.0 value=18.0
uniform float glow_width;      // pixels
//@slider min=0.0 max=2.0 value=0.6
uniform float glow_amount;
//@slider min=0.0 max=1.0 value=0.12
uniform float base_level;      // how bright the outlines are without a sweep
//@slider min=0.0 max=4.0 value=1.6
uniform float sweep_intensity;
//@slider min=-180.0 max=180.0 value=0.0
uniform float sweep_angle;     // Linear: the direction it travels, in degrees
//@slidervec2 min=(0,0) max=(1,1) value=(0.5,0.5)
uniform vec2 sweep_center;     // Radial and Around
//@slider min=-4.0 max=4.0 value=0.25
uniform float sweep_speed;     // sweeps per beat (Sync) or per second (Free); negative runs back
//@slider min=0.0 max=1.0 value=0.0
uniform float sweep_position;  // moves the sweep by hand: speed 0 and a fader or MIDI knob on this
//@slider min=0.01 max=1.0 value=0.25
uniform float sweep_length;    // the length of the tail, as a share of the way
//@int min=1 max=8 value=1
uniform int sweep_count;       // sweeps at the same time
//@slider min=0.0 max=2.0 value=0.5
uniform float pulse_amount;    // all outlines flash at a pulse (Pulse every, Trigger)
//@enum options=(Two colours, Input colours, Rainbow) value=0
uniform int color_mode;
//@rgb value=(0.25, 0.85, 1.0)
uniform vec3 color_a;          // the head of a sweep
//@rgb value=(1.0, 0.2, 0.7)
uniform vec3 color_b;          // the tail
//@slider min=0.0 max=1.0 value=0.35
uniform float input_level;     // the picture under the light (Over input)
//@enum options=(Over input, Lines only, Lines of the input) value=0
uniform int output_mode;
//@slider min=0.0 max=1.0 value=0.0
uniform float show_mask;       // calibration: the mask in red over the picture
//@enum options=(Final, Distance to the outlines, Comets of Trace) value=0
uniform int debug_view;

// The brightness of a sweep at x (0..1 along its way): the head at the front, the tail behind it. One sweep runs in
// and out completely; several repeat across the way.
float sweep_band(float x) {
    float L = max(sweep_length, 0.01);
    float ph = iTime * sweep_speed + sweep_position;
    float f;
    if (sweep_count <= 1) {
        float xx = sweep_speed < 0.0 ? 1.0 - x : x;
        f = fract(sweep_speed < 0.0 ? -ph : ph) * (1.0 + L) - xx;
        if (f < 0.0 || f > L) return 0.0;
    } else {
        f = fract(ph - x * float(sweep_count));
        if (sweep_speed < 0.0) f = 1.0 - f;
    }
    float b = f < L ? pow(1.0 - f / L, 2.0) : 0.0;
    return b * smoothstep(0.0, 0.004, f) + smoothstep(0.996, 1.0, f);
}

float sweep_value(vec2 suv, out float along) {
    float a = iResolution.x / iResolution.y;
    vec2 asp = vec2(a, 1.0);
    along = 0.0;
    if (sweep_mode == 0) {
        vec2 dir = vec2(cos(radians(sweep_angle)), sin(radians(sweep_angle)));
        float half_extent = 0.5 * (abs(dir.x) * a + abs(dir.y));
        along = dot((suv - 0.5) * asp, dir) / (2.0 * half_extent) + 0.5;
        return sweep_band(along);
    }
    if (sweep_mode == 1) {
        vec2 far = max(sweep_center, 1.0 - sweep_center) * asp;
        along = length((suv - sweep_center) * asp) / max(length(far), 0.01);
        return sweep_band(along);
    }
    if (sweep_mode == 2) {
        vec2 p = (suv - sweep_center) * asp;
        along = atan(p.y, p.x) / MP_TAU + 0.5;
        return sweep_band(along);
    }
    if (sweep_mode == 3) {
        vec2 r = mp_bilinear_uv(R, suv).rg;
        along = suv.x;
        return clamp(max(r.x, r.y), 0.0, 1.0);
    }
    if (sweep_mode == 4) {
        along = 0.0;
        return 0.0;
    }
    // Sparkle: short flashes on pieces of the outlines
    vec2 cell = floor(suv * asp * 40.0);
    float ph = mp_rand2(ivec2(cell));
    float t = iTime * abs(sweep_speed) * 4.0 + ph * 8.0;
    along = ph;
    float on = step(0.6, mp_rand2(ivec2(cell) + ivec2(int(floor(t)) * 131, 7)));
    return on * pow(1.0 - fract(t), 3.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 src = texture(input, uv);

    vec2 suv;
    vec2 n;
    float strength;
    float d = jfa_lookup(J10, fragCoord, suv, n, strength);

    float hw = max(line_width, 0.5) * 0.5;
    float core = 1.0 - smoothstep(hw - 0.75, hw + 0.75, d);
    float glow = glow_width > 0.0 ? exp(-max(d - hw, 0.0) / (glow_width * 0.35)) : 0.0;
    float edge_gain = mix(0.55, 1.0, strength);

    float along;
    float s = sweep_value(suv, along);
    // The glow of a short light (a comet, a sparkle) is the light of the outline around its seed: averaged along
    // the tangent over a stretch that grows with the distance, so it is a round halo, not a streak across the line
    float s_glow = s;
    if ((sweep_mode == 3 || sweep_mode == 5) && d > hw && glow > 0.01) {
        vec2 t = vec2(-n.y, n.x) / iResolution.xy;
        float a2;
        float sum = s;
        for (int k = 1; k <= 3; k++) {
            float o = float(k) * (d - hw) * 0.45;
            sum += sweep_value(suv + t * o, a2) + sweep_value(suv - t * o, a2);
        }
        s_glow = sum / 4.0;
    }
    vec3 pl = mp_pulse(T);
    float energy = (base_level + sweep_intensity * s + pulse_amount * pl.x) * edge_gain;
    float energy_glow = (base_level + sweep_intensity * s_glow + pulse_amount * pl.x) * edge_gain;

    vec3 col;
    if (color_mode == 1) {
        vec3 c = texture(input, suv).rgb;
        col = c / max(max(c.r, max(c.g, c.b)), 0.2);
    } else if (color_mode == 2) {
        col = mp_hue(along + iTime * 0.05);
    } else {
        col = mix(color_b, color_a, clamp(s * 1.2, 0.0, 1.0));
    }
    // the head of a sweep turns white hot
    col = mix(col, vec3(1.0), clamp(s * s * s, 0.0, 1.0) * 0.6);

    float halo = glow_amount * glow * (1.0 - core);
    float shape = core + halo;
    vec3 light = col * (energy * core + energy_glow * halo);

    vec3 rgb;
    float alpha = 1.0;
    if (output_mode == 1) {
        rgb = light;
        alpha = clamp(max(light.r, max(light.g, light.b)), 0.0, 1.0);
    } else if (output_mode == 2) {
        rgb = src.rgb * clamp(shape, 0.0, 1.0) * (energy + 0.3) * 1.5;
        alpha = clamp(shape, 0.0, 1.0);
    } else {
        rgb = src.rgb * input_level + light;
        alpha = max(src.a, clamp(max(light.r, max(light.g, light.b)), 0.0, 1.0));
    }

    if (show_mask > 0.0) {
        float m = mp_bilinear_uv(M, uv).r;
        rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.4 * m);
        alpha = max(alpha, show_mask);
    }
    if (debug_view == 1) {
        float bands = fract(d / 20.0);
        rgb = vec3(0.5 + 0.5 * cos(d * 0.02 + vec3(0.0, 2.0, 4.0))) * (0.6 + 0.4 * step(0.5, bands));
        alpha = 1.0;
    } else if (debug_view == 2) {
        vec2 r = mp_bilinear_uv(R, uv).rg;
        rgb = vec3(r, 0.0) + vec3(0.0, 0.0, 0.25) * core;
        alpha = 1.0;
    }
    fragColor = vec4(min(rgb, vec3(4.0)), alpha);
}
