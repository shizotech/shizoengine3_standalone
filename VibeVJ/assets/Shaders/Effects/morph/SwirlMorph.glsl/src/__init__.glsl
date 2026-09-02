// SwirlMorph FX (FX4)
// Shadertoy format
// Swirls the input texture (iChannel0) into a vortex toward the center point.
// Morph strength, zoom and swirl size are all adjustable.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Morph strength (how hard the vortex pulls)
//@slider min=0.0 max=1.0 value=0.6
uniform float morph_strength;

// Zoom factor
//@slider min=0.2 max=3.0 value=1.0
uniform float zoom;

// Swirl radius (size of the vortex)
//@slider min=0.05 max=1.0 value=0.5
uniform float swirl_size;

// Number of full rotations through the vortex
//@slider min=0.0 max=4.0 value=2.0
uniform float swirl_turns;

// Background fill outside the input
//@rgb value=(0.02,0.02,0.05)
uniform vec3 background;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv = uv * 2.0 - 1.0;

    // Center the coordinate space
    vec2 c = uv / max(zoom, 0.001);
    float r = length(c);
    float ang = atan(c.y, c.x);

    // Vortex profile: full inside the swirl radius, fades to 0 outside
    float falloff = 1.0 - smoothstep(swirl_size, swirl_size * 1.3, r);
    float rotation = -swirl_turns * falloff;

    // Apply the swirl
    float newAng = ang + rotation * morph_strength * 6.2831853 * 0.5;
    vec2 swirled = vec2(cos(newAng), sin(newAng)) * r;
    swirled = swirled * zoom;
    swirled = swirled * 0.5 + 0.5;
    swirled = clamp(swirled, vec2(0.0), vec2(1.0));

    vec3 color = texture(iChannel0, swirled).rgb;
    vec3 bg = background;
    color = mix(bg, color, step(0.0, swirled.x) * step(swirled.x, 1.0) * step(0.0, swirled.y) * step(swirled.y, 1.0));

    fragColor = vec4(color, 1.0);
}
