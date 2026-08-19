//@float min=0.1 max=4.0 value=1.0
uniform float beat_freq;
//@int min=1 max=64 value=8
uniform int grid_x;
//@int min=1 max=64 value=4
uniform int grid_y;
//@rgb value=(1.0,0.6,0.2)
uniform vec3 base_color;
//@float min=0.0 max=1.0 value=0.2
uniform float color_variation;
//@float min=0.0 max=1.0 value=1.0
uniform float block_opacity;
//@float min=0.1 max=5.0 value=1.0
uniform float interp_smoothness;
//@enum options=(Instant, Linear, Smoothstep, Sine Pulse)
uniform int interp_mode;
//@enum options=(Left to Right, Right to Left)
uniform int direction;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 randomColor(vec2 seed) {
    return vec3(
        hash(seed + 1.0),
        hash(seed + 2.0),
        hash(seed + 3.0)
    );
}

float interpolate(float t) {
    t = clamp(t, 0.0, 1.0);
    if (interp_mode == 0) return step(0.5, t);
    if (interp_mode == 1) return t;
    if (interp_mode == 2) return smoothstep(0.0, 1.0, t);
    if (interp_mode == 3) return 0.5 + 0.5 * sin(t * 3.14159);
    return t;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    vec2 grid = vec2(float(grid_x), float(grid_y));
    vec2 cellUV = floor(uv * grid);
    vec2 localCoord = fract(uv * grid) - 0.5;

    // Beat-synced step index
    float beatTime = iTime * beat_freq;
    float stepIndex = mod(floor(beatTime), grid.x);
    float fadeTime = fract(beatTime);

    // Direction control
    if (direction == 1) {
        stepIndex = grid.x - 1.0 - stepIndex;
    }

    // Check if this block is currently the active one
    float isActive = step(abs(cellUV.x - stepIndex), 0.5);  // 1.0 if same column

    // Smooth fade
    float fade = interpolate(1.0 - fadeTime * interp_smoothness);

    // Color variation
    vec3 color = vec3(0.0);
    if (isActive > 0.5) {
        float box = step(abs(localCoord.x), 0.5) * step(abs(localCoord.y), 0.5);
        vec3 variation = (randomColor(cellUV) - 0.5) * 2.0 * color_variation;
        color = (base_color + variation) * box * fade;
    }

    fragColor = vec4(color, block_opacity);
}

