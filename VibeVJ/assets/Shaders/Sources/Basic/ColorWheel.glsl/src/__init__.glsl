// SFX3 ColorWheel - Rotating Color Wheel Source
// Shadertoy format
// A colour wheel that shows every hue around a center, with adjustable
// rotation, zoom and softness/saturation.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Wheel radius (fraction of the frame)
//@slider min=0.1 max=1.0 value=0.45
uniform float wheel_radius;

// Rotation speed (rad/beat)
//@slider min=-4.0 max=4.0 value=0.3
uniform float rotation_speed;

// Static rotation offset (0..1 = 0..360deg)
//@slider min=0.0 max=1.0 value=0.0
uniform float rotation;

// Zoom (scale of the wheel)
//@slider min=0.2 max=3.0 value=1.0
uniform float zoom;

// Saturation of the wheel colours
//@slider min=0.0 max=1.0 value=1.0
uniform float saturation;

// Softness / blur of the wheel edge
//@slider min=0.0 max=1.0 value=0.2
uniform float softness;

// Background colour (kept non-black)
//@rgb value=(0.10,0.08,0.15)
uniform vec3 background;

// ---- HSV -> RGB ----
// branch-based scalar implementation (avoids abs(vec3, float, float)
// which the engine compiler cannot resolve)
vec3 hsv2rgb(vec3 c) {
    float h = fract(c.x) * 6.0;
    float s = c.y;
    float v = c.z;
    float hi = floor(h);
    float f = h - hi;
    float p = v * (1.0 - s);
    float q = v * (1.0 - s * f);
    float t = v * (1.0 - s * (1.0 - f));
    vec3 rgb;
    if (hi < 1.0)      rgb = vec3(v, t, p);
    else if (hi < 2.0) rgb = vec3(q, v, p);
    else if (hi < 3.0) rgb = vec3(p, v, t);
    else if (hi < 4.0) rgb = vec3(p, q, v);
    else if (hi < 5.0) rgb = vec3(t, p, v);
    else                 rgb = vec3(v, p, q);
    return rgb;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = (uv - 0.5) / max(zoom, 0.001);
    p.x *= iResolution.x / iResolution.y;

    float ang = atan(p.y, p.x);
    float dist = length(p);

    // Hue = angle offset by rotation + time
    float rot = rotation * 6.2831853 + iTime * rotation_speed;
    float hue = mod((ang + rot) / 6.2831853, 1.0);

    // Saturation applied to the hue colour
    vec3 col = hsv2rgb(vec3(hue, saturation, 1.0));

    // Fade the wheel from the center to its edge based on softness
    float falloff = 1.0 - smoothstep(wheel_radius * (1.0 - softness), wheel_radius, dist);
    col *= falloff;

    vec3 bg = background;
    vec3 outcol = mix(bg, col, falloff);
    outcol = max(bg, outcol);

    fragColor = vec4(outcol, 1.0);
}
