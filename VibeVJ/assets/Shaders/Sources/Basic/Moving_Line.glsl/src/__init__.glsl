// ==== Moving_Line source shader ====
// Renders moving bars/lines across the screen.
// Shadertoy format: mainImage; engine injects iResolution, iTime, iFrame etc.

// ==== Custom Uniform Controls ====

//@enum options=(Horizontal, Vertikal)
uniform int move_direction;   // 0 = horizontal (links→rechts), 1 = vertikal (unten→oben)

//@enum options=(Vorwärts, Rückwärts, HinRück, InnenAußen, AußenInnen)
uniform int move_mode;        // 0..4

//@float min=0.005 max=0.2 value=0.02
uniform float bar_width;

//@int min=1 max=50 value=8
uniform int bar_count;

//@slider min=0.0 max=1.0 value=0.0
uniform float randomness;      // 0 = gleichmäßig, 1 = zufällig

//@slider min=0.0 max=1.0 value=0.5
uniform float softness;

//@slider min=0.0 max=1.0 value=0.0
uniform float curvature;       // Amplitude/Beugung für Wellenlinie/Bogen

//@enum options=(Gerade, Wellenlinie, Bogen)
uniform int line_shape;        // 0=Gerade, 1=Wellenlinie, 2=Bogen

//@rgb value=(1.0, 1.0, 1.0)
uniform vec3 color;

//@rgb value=(0.05, 0.05, 0.08)
uniform vec3 bg_color;

//@slider min=0.0 max=2.0 value=0.5
uniform float speed;

// ==== Helpers ====

// Deterministic per-bar hash (frame-stable, no flicker)
float barHash(int i) {
    float n = float(i);
    float h = fract(sin(n * 12.9898) * 43758.5453);
    return h;
}

// Triangle wave in [0,1] -> ping-pong
float pingPong(float x) {
    float f = fract(x);
    return 1.0 - abs(2.0 * f - 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    float t = iTime * speed;
    bool horizontal = (move_direction == 0);

    vec3 col = bg_color;

    // Constant upper bound for loop (GLSL requires constant loop limit);
    // break at bar_count.
    for (int i = 0; i < 50; i++) {
        if (i >= bar_count) break;

        // Base offset of bar i along the axis
        float basePos;
        if (randomness <= 0.5) {
            // evenly distributed
            basePos = (float(i) + 0.5) / float(bar_count);
        } else {
            // deterministic random distribution, mixed with even
            float rnd = barHash(i);
            basePos = mix((float(i) + 0.5) / float(bar_count), rnd, randomness);
        }

        // Per-bar phase offset so bars don't all move in unison
        float phase = barHash(i + 101) * 2.0 * 3.14159265359;

        // Position of bar i this frame, in [0,1] along the motion axis
        float pos;
        if (move_mode == 0) {
            pos = fract(basePos + t * 0.1 + phase * 0.05);
        } else if (move_mode == 1) {
            pos = fract(basePos - t * 0.1 + phase * 0.05);
        } else if (move_mode == 2) {
            pos = pingPong(basePos + t * 0.1 + phase * 0.05);
        } else if (move_mode == 3) {
            // center -> outside: start at 0.5 (center) and expand to the edges
            pos = 0.5 + 0.5 * sin(fract(t * 0.1 + phase * 0.1) * 6.28318530718);
        } else {
            // outside -> center: start at an edge and contract toward 0.5
            pos = 0.5 - 0.5 * sin(fract(t * 0.1 + phase * 0.1) * 6.28318530718);
        }

        // Coordinates along the motion axis
        float axisCoord = horizontal ? uv.x : uv.y;
        float otherCoord = horizontal ? uv.y : uv.x;

        // Line shape deformation along the perpendicular axis (in [0,1])
        float deform = 0.0;
        if (line_shape == 1) {
            // Wave line: sinusoidal offset, amplitude = curvature
            deform = sin((otherCoord + pos * 2.0 + phase) * 6.28318530718 * 1.0) * curvature * 0.1;
        } else if (line_shape == 2) {
            // Arc: parabolic offset, controlled by curvature
            float c = otherCoord - 0.5;
            deform = -c * c * curvature * 0.4;
        }

        // Shift the coordinate along the axis to account for the perpendicular deform
        float coordWithDeform = axisCoord + deform;

        // Signed distance to the infinite bar centered at 'pos'
        float halfW = bar_width * 0.5;
        float dist = abs(coordWithDeform - pos);
        float soft = max(softness * 0.05 + 0.001, 0.001);
        float density = 1.0 - smoothstep(halfW - soft, halfW + soft, dist);

        col = max(col, color * density);
    }

    fragColor = vec4(col, 1.0);
}
