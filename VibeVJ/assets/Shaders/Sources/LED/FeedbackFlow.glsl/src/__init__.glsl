//@settings dtype=float32 format=rgba

//@slider min=0.0 max=4.0 value=1.0
uniform float flow_speed;

//@slider min=0.0 max=2.0 value=0.6
uniform float swirl;

//@slider min=0.0 max=1.0 value=0.9
uniform float memory;

//@slider min=0.1 max=3.0 value=1.0
uniform float flow_scale;

//@int min=1 max=12 value=5
uniform int shape_count;

//@slider min=0.05 max=0.5 value=0.2
uniform float shape_size;

//@slider min=0.0 max=3.0 value=1.0
uniform float intensity;

//@enum options=(Blob, Ring, Capsule, Star) value=0
uniform float pattern;

//@rgb value=(0.5, 0.9, 1.0)
uniform vec3 foreground_color;

//@rgb value=(0.01, 0.02, 0.08)
uniform vec3 background_color;

uniform sampler2D feedback;

#include "math/sdflib.glsl"

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;
    float t = iTime * flow_speed;

    // --- 1. Fade the previous frame (decaying trail via feedback buffer) ---
    vec4 prev = texture(feedback, uv);
    vec3 col = prev.rgb * memory;
    // Hard clamp the accumulation every frame so trails can never run away.
    col = clamp(col, vec3(0.0), vec3(1.0));

    // --- 2. Sample the divergence-free flow field (curl-noise + vortex) ---
    vec2 fp = uv * flow_scale * 3.0 + vec2(t * 0.15, t * -0.1);
    vec2 v = ff_flow(fp);

    // --- 3. Advection: trace the flow field backward by a few texels ---
    vec2 texel = 1.0 / iResolution.xy;
    vec2 src_uv = uv - v * texel * 6.0;
    // Add a soft "smearing" glow by sampling the trailed buffer along the field
    vec3 trail = texture(feedback, src_uv).rgb * 0.5;
    col = clamp(col + trail, vec3(0.0), vec3(1.0));

    // --- 4. Advect SDF shapes through the field and paint new ink ---
    for (int i = 0; i < 12; i++)
    {
        if (i >= shape_count) break;
        float fi = float(i);
        // Each shape follows a deterministic Lissajous orbit, offset per-shape
        vec2 center = 0.7 * vec2(
            cos(t * 0.6 + fi * 1.7),
            sin(t * 0.8 + fi * 2.3));
        // Slight per-shape size variation (note: properly closed parentheses)
        float s = shape_size * (0.7 + 0.6 * ff_hash(vec2(fi, 7.0)));
        // Local flow velocity at the shape centre gives it a "swim" offset
        vec2 cv = ff_flow(uv * flow_scale * 3.0 + vec2(t * 0.15, t * -0.1) + center * 0.2);
        vec2 q = p - center + cv * 0.15;
        float d = ff_shape(q, s);
        float cover = 1.0 - smoothstep(0.0, 0.12, d);
        // Paint new ink on top of the faded trail (additive glow, clamped)
        col = clamp(col + foreground_color * cover * intensity, vec3(0.0), vec3(1.0));
    }

    // --- 5. Blend to background where there is no ink ---
    col = mix(background_color, col, clamp(length(prev.rgb) * 3.0, 0.0, 1.0));
    col = clamp(col, vec3(0.0), vec3(1.0));

    fragColor = vec4(col, 1.0);
}
