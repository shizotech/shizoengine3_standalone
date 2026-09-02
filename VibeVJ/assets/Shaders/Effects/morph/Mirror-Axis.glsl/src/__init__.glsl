// Mirror-Axis Effect
// Shadertoy format
// Mirrors the input texture (iChannel0) across a configurable axis.

//@slidervec2 min=(0,0) max=(1,1) value=(0.5,0.5)
uniform vec2 axis_offset;

//@int min=1 max=4 value=1
uniform int num_axes;

//@slider min=-180.0 max=180.0 value=0.0
uniform float axis_tilt_deg;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // Centered coordinates relative to the axis position (0..1)
    vec2 center = clamp(axis_offset, vec2(0.0), vec2(1.0));
    vec2 c = uv - center;

    // Rotate the coordinate space by the tilt angle (in degrees)
    float tilt_rad = radians(axis_tilt_deg);
    float ca = cos(tilt_rad);
    float sa = sin(tilt_rad);
    vec2 r = vec2(c.x * ca - c.y * sa, c.x * sa + c.y * ca);

    // Fold the rotated space into 2^N mirror segments on each axis,
    // where N = num_axes. Each doubling doubles the mirror repeats.
    float span = pow(2.0, float(num_axes));

    float fx = r.x * span;
    fx = mod(fx, span * 2.0);            // wrap into [0, 2*span]
    fx = min(fx, span * 2.0 - fx);       // fold back = mirror
    r.x = fx / span;

    float fy = r.y * span;
    fy = mod(fy, span * 2.0);
    fy = min(fy, span * 2.0 - fy);
    r.y = fy / span;

    vec2 out_uv = center + r;

    // Sample within bounds; clamp the coordinate.
    out_uv = clamp(out_uv, vec2(0.0), vec2(1.0));

    vec3 color = texture(iChannel0, out_uv).rgb;
    fragColor = vec4(color, 1.0);
}
