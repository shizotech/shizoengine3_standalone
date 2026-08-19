//@float min=0.1 max=4.0 value=1.0
uniform float beat_freq;
//@int min=0 max=4 value=2
uniform int beat_division;
//@float min=0.0 max=1.0 value=0.0
uniform float beat_jitter;
//@float min=0.0 max=1.0 value=0.6
uniform float randomness;
//@rgb value=(1.0, 0.5, 0.3)
uniform vec3 base_color;
//@float min=0.0 max=1.0 value=0.3
uniform float color_variation;
//@int min=1 max=64 value=8
uniform int grid_x;
//@int min=1 max=64 value=8
uniform int grid_y;
//@float min=0.0 max=1.0 value=1.0
uniform float block_opacity;
//@enum options=(Instant, Linear, Smoothstep, Sine Pulse)
uniform int interp_mode;
//@float min=0.1 max=5.0 value=1.0
uniform float interp_smoothness;
//@float min=0.0 max=1.0 value=0.0
uniform float beat_phase_offset;

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

    // Core beat timing
    float baseFreq = beat_freq * pow(2.0, float(beat_division));
    float beatTime = iTime * baseFreq;

    // Per-cell jittered beat offset
    float jitter = beat_jitter * hash(cellUV);
    float beatPhase = beatTime + jitter + beat_phase_offset;
    float beatIndex = floor(beatPhase);
    float beatProgress = fract(beatPhase);

    // Random activation per beat and cell
    float cellActive = step(hash(cellUV + vec2(beatIndex)), randomness);

    // Animation interpolation
    float fade = interpolate(1.0 - abs(2.0 * beatProgress - 1.0) * interp_smoothness);

    vec3 color = vec3(0.0);
    if (cellActive > 0.0) {
        float box = step(abs(localCoord.x), 0.5) * step(abs(localCoord.y), 0.5);
        vec3 variation = (randomColor(cellUV + vec2(beatIndex)) - 0.5) * 2.0 * color_variation;
        color = (base_color + variation) * box * fade;
    }

    fragColor = vec4(color, block_opacity);
}
