// AxisWarp FX (FX3)
// Shadertoy format
// Warps a region between two parallel source axes toward two parallel
// target axes. Position and spacing of both axis pairs are adjustable.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// --- Source axes (input space, horizontal lines) ---
// Y position of the upper source axis
//@slider min=0.0 max=1.0 value=0.3
uniform float src_axis_top;

// Spacing (distance) between the two source axes
//@slider min=0.02 max=0.6 value=0.2
uniform float src_spacing;

// --- Target axes (output space, horizontal lines) ---
// Y position of the upper target axis
//@slider min=0.0 max=1.0 value=0.4
uniform float tgt_axis_top;

// Spacing (distance) between the two target axes
//@slider min=0.02 max=0.8 value=0.4
uniform float tgt_spacing;

// Warp strength (how strongly the band maps to the target band)
//@slider min=0.0 max=1.0 value=0.7
uniform float warp_strength;

// Smoothness of the mapping edges
//@slider min=0.05 max=1.0 value=0.3
uniform float smoothness;

// Angle of the axes (0 = horizontal, 90 = vertical)
//@slider min=0.0 max=180.0 value=0.0
uniform float axis_angle;

// Background fill outside the input
//@rgb value=(0.02,0.02,0.05)
uniform vec3 background;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Rotate the sampling space so the axes are horizontal in a local frame
    float ang = radians(axis_angle);
    float ca = cos(ang);
    float sa = sin(ang);
    vec2 p = uv - 0.5;
    vec2 lp = vec2(p.x * ca - p.y * sa, p.x * sa + p.y * ca);
    vec2 lu = lp + 0.5;

    float y = lu.y;

    // Source band: between src_axis_top and src_axis_top + src_spacing
    float sTop = src_axis_top;
    float sBot = src_axis_top + src_spacing;
    // Target band: between tgt_axis_top and tgt_axis_top + tgt_spacing
    float tTop = tgt_axis_top;
    float tBot = tgt_axis_top + tgt_spacing;

    // Normalized position within the source band (0 at top, 1 at bottom)
    float sNorm = clamp((y - sTop) / max(src_spacing, 0.001), 0.0, 1.0);
    // Map onto the target band
    float tNorm = mix(tTop, tBot, sNorm);

    // Blend the original Y with the warped Y based on strength and smoothness
    float edge = smoothstep(0.0, smoothness, clamp((y - sTop) / max(smoothness, 0.05), 0.0, 1.0));
    edge *= smoothstep(0.0, smoothness, clamp((sBot - y) / max(smoothness, 0.05), 0.0, 1.0));
    float wy = mix(y, tNorm, warp_strength * edge);
    lu.y = wy;

    // Rotate back to screen space
    vec2 rp = lu - 0.5;
    vec2 out_uv = vec2(rp.x * ca + rp.y * sa, -rp.x * sa + rp.y * ca) + 0.5;
    out_uv = clamp(out_uv, vec2(0.0), vec2(1.0));

    vec3 color = texture(iChannel0, out_uv).rgb;
    vec3 bg = background;
    color = mix(bg, color, step(0.0, out_uv.x) * step(out_uv.x, 1.0) * step(0.0, out_uv.y) * step(out_uv.y, 1.0));

    fragColor = vec4(color, 1.0);
}
