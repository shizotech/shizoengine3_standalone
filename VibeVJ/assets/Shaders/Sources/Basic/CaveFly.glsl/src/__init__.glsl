// FX2 CaveFly - Infinite cave flight source
// Shadertoy format
// Flies endlessly through a procedural cave. Wall pattern, wall colour and
// wall smoothness are all adjustable.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Which wall pattern
//@enum options=(Rings, Stripes, Spokes, Waves, Dots, Checker) value=0
uniform int wall_pattern;

// Wall colour
//@rgb value=(0.2,0.7,0.9)
uniform vec3 wall_color;

// Wall smoothness (default smooth)
//@slider min=0.0 max=1.0 value=0.8
uniform float wall_smoothness;

// Flight speed
//@slider min=0.0 max=4.0 value=0.5
uniform float fly_speed;

// Cave / tunnel zoom
//@slider min=0.3 max=3.0 value=1.0
uniform float cave_zoom;

// Number of tunnel sides (for polygon cave cross-section)
//@int min=3 max=12 value=8
uniform int cave_sides;

// Cave radius (fraction of the frame)
//@slider min=0.2 max=1.0 value=0.6
uniform float cave_radius;

// Background colour (kept non-black)
//@rgb value=(0.03,0.02,0.05)
uniform vec3 background;

// ---- hash helper ----
float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv = (uv - 0.5) * vec2(iResolution.x / iResolution.y, 1.0) / max(cave_zoom, 0.001);

    // radial / angular coords
    float r = length(uv);
    float a = atan(uv.y, uv.x);

    // depth coordinate that scrolls to simulate forward flight
    float t = iTime * fly_speed;

    // Cave cross-section: fold the angle into the polygon side cell
    float side_angle = 6.28318 / float(cave_sides);
    float afold = mod(a, side_angle) - side_angle * 0.5;

    // depth position along the tunnel axis (infinite loop via mod)
    float z = t;

    // wall pattern value (0..1)
    float pattern;
    if (wall_pattern == 0) {
        // Rings: bands along the flight direction
        float ring_freq = 3.0;
        pattern = 0.5 + 0.5 * sin(z * ring_freq * cave_radius * 4.0);
    } else if (wall_pattern == 1) {
        // Stripes: vertical facets
        float seg = floor(a * float(cave_sides) / 3.14159);
        pattern = mod(seg, 2.0);
    } else if (wall_pattern == 2) {
        // Spokes: radial lines from center
        pattern = 0.5 + 0.5 * sin(a * float(cave_sides) - z);
    } else if (wall_pattern == 3) {
        // Waves: undulating bands
        float wave = sin(z * 1.5 + sin(a * 3.0) * 0.5);
        pattern = 0.5 + 0.5 * wave;
    } else if (wall_pattern == 4) {
        // Dots: scattered glowing dots on the wall
        float aN = a / 6.28318;             // normalized angle 0..1
        float zN = mod(z, 2.0);
        vec2 dup = vec2(aN, zN);
        vec2 cell = floor(dup * 8.0);
        float seed = cell.x * 12.9898 + cell.y * 78.233;
        float h = hash1(seed);
        vec2 local = fract(dup * 8.0) - 0.5;
        float dotd = length(local);
        pattern = smoothstep(0.25, 0.0, dotd) * step(0.6, h);
    } else {
        // Checker: alternating segments
        float seg = floor(z * 2.0);
        float facet = mod(floor(a * float(cave_sides) / 3.14159), 2.0);
        pattern = mod(seg + facet, 2.0);
    }

    // Cave opening: fade the pattern toward the cave boundary
    // r in cave-space; 0 at center, 1 at cave edge
    float rn = r / max(cave_radius, 0.01);
    // smooth edge based on wall_smoothness (default smooth)
    float edge = 1.0 - smoothstep(1.0 - wall_smoothness, 1.0, rn);
    float depth_fade = smoothstep(0.0, 0.15, rn); // avoid harsh center

    // Brightness: fade with "distance" along the tunnel for depth
    float fog = 0.4 + 0.6 * (1.0 - rn);

    vec3 col = wall_color * pattern * edge * depth_fade * fog;

    // Vignette toward screen corners (outside the cave)
    float cr = length((fragCoord / iResolution.xy) - 0.5);
    float vig = 1.0 - smoothstep(cave_radius, cave_radius + 0.2, cr);

    vec3 bg = background;
    vec3 outcol = mix(bg, col, vig);
    outcol = max(bg, outcol);

    fragColor = vec4(outcol, 1.0);
}
