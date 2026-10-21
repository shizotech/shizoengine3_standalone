//@settings dtype=float32 format=rgba

// --- Reaction-diffusion (Gray-Scott): the simulation ---
//   A' = diffA * lap(A) - A B^2 + feed (1 - A)
//   B' = diffB * lap(B) + A B^2 - (kill + feed) B
// lap() is the 9-point Laplacian (sides 0.2, corners 0.05, centre -1). The state lives in this pass's own output
// (feedback). An empty buffer (the start, a new render size) gets A = 1 and a seed in the middle; Auto seed keeps
// feeding that seed while it is on.

//@slider min=0.010 max=0.100 value=0.037
uniform float feed_rate;

//@slider min=0.030 max=0.075 value=0.06
uniform float kill_rate;

//@slider min=0.8 max=1.2 value=1.0
uniform float diffA;

//@slider min=0.3 max=0.8 value=0.5
uniform float diffB;

//@slider min=0.0 max=1.0 value=1.0
uniform float step_speed;

//@int min=1 max=8 value=2
uniform int iterations;

//@button
uniform bool auto_seed;

// The state of the last frame: this pass's own output
uniform sampler2D feedback;

vec2 state(vec2 uv)
{
    return texture(feedback, uv).rg;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 t = 1.0 / iResolution.xy;
    vec2 s = state(uv);
    bool seed = length(fragCoord - 0.5 * iResolution.xy) < max(4.0, iResolution.y * 0.03);

    // Empty buffer: start the simulation
    if (iFrame < 2 || s.x + s.y < 1e-5)
    {
        fragColor = vec4(seed ? vec2(0.5, 1.0) : vec2(1.0, 0.0), 0.0, 1.0);
        return;
    }
    if (auto_seed && seed)
        s.y = 1.0;

    vec2 lap = 0.2 * (state(uv + vec2(t.x, 0.0)) + state(uv - vec2(t.x, 0.0))
                    + state(uv + vec2(0.0, t.y)) + state(uv - vec2(0.0, t.y)))
             + 0.05 * (state(uv + t) + state(uv - t) + state(uv + vec2(t.x, -t.y)) + state(uv + vec2(-t.x, t.y)))
             - s;

    // The diffusion of this frame is fixed, the reaction is split into `iterations` smaller steps
    const int MAX_ITER = 8;
    int n = clamp(iterations, 1, MAX_ITER);
    float dt = step_speed / float(n);
    for (int i = 0; i < MAX_ITER; i++)
    {
        if (i >= n)
            break;
        float abb = s.x * s.y * s.y;
        s.x += (diffA * lap.x - abb + feed_rate * (1.0 - s.x)) * dt;
        s.y += (diffB * lap.y + abb - (kill_rate + feed_rate) * s.y) * dt;
        s = clamp(s, 0.0, 1.0);
    }

    fragColor = vec4(s, 0.0, 1.0);
}
