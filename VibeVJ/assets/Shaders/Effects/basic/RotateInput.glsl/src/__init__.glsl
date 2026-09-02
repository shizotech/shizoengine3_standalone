// Rotate Input FX (FX1)
// Shadertoy format
// Rotates the input texture (iChannel0) around a freely movable center point,
// with adjustable zoom and rotation speed.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Center of rotation, movable across the frame (0..1 uv space)
//@slidervec2 min=(0,0) max=(1,1) value=(0.5,0.5)
uniform vec2 center;

// Zoom factor around the center
//@slider min=0.2 max=3.0 value=1.0
uniform float zoom;

// Base rotation angle (0..1 = 0..360deg)
//@slider min=0.0 max=1.0 value=0.0
uniform float rotation;

// Continuous rotation speed (radians/sec scale)
//@slider min=-4.0 max=4.0 value=0.5
uniform float rot_speed;

// Strength of the rotation morph
//@slider min=0.0 max=1.0 value=0.5
uniform float morph_strength;

// Edge fill outside the input
//@rgb value=(0.02,0.02,0.05)
uniform vec3 background;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Centered coordinates relative to the movable center
    vec2 c = uv - center;

    // Total rotation = static base + continuous spin, scaled by morph strength
    float total_rot = (rotation * 6.2831853 + iTime * rot_speed) * morph_strength;
    float cs = cos(total_rot);
    float sn = sin(total_rot);

    // Rotate the offset around the center
    vec2 r = vec2(c.x * cs - c.y * sn, c.x * sn + c.y * cs);

    // Apply zoom around the center
    r = r / max(zoom, 0.001);

    vec2 out_uv = center + r;
    out_uv = clamp(out_uv, vec2(0.0), vec2(1.0));

    vec3 color = texture(iChannel0, out_uv).rgb;
    // Fallback to background color if the sampled coordinate is out of the valid input range
    vec3 bg = background;
    color = mix(bg, color, step(0.0, out_uv.x) * step(out_uv.x, 1.0) * step(0.0, out_uv.y) * step(out_uv.y, 1.0));

    fragColor = vec4(color, 1.0);
}
