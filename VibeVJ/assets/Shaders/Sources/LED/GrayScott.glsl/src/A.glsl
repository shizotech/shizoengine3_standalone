//@settings dtype=float32 format=rgba

// --- Gray-Scott reaction-diffusion: the simulation ---
// Two chemicals: u (R) is fed in, v (G) eats it and dies off.
//   u' = du * lap(u) - u v^2 + feed (1 - u)
//   v' = dv * lap(v) + u v^2 - (kill + feed) v
// lap() is the 9-point Laplacian (sides 0.2, corners 0.05, centre -1), as in Karl Sims' tutorial. The state lives
// in this pass's own output (feedback). An empty buffer (the start, a new render size) is filled with u = 1 and the
// seeds of Seed style; Auto seed keeps adding seeds while it is on.

// Cheap, deterministic 2D -> 1D hash in [0,1] for the Scatter seeds
float hash21(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

//@slider min=0.5 max=2.5 value=1.0
uniform float du;

//@slider min=0.2 max=2.5 value=0.5
uniform float dv;

//@slider min=0.01 max=0.1 value=0.055
uniform float feed;

//@slider min=0.03 max=0.08 value=0.062
uniform float kill;

//@slider min=0.1 max=1.0 value=1.0
uniform float sim_speed;

//@int min=1 max=8 value=2
uniform int iterations;

//@button
uniform bool auto_seed;

//@enum options=(Center, Scatter, Grid) value=1
uniform int seed_style;

// The state of the last frame: this pass's own output
uniform sampler2D feedback;

bool is_seed(vec2 fragCoord)
{
    vec2 id = floor(fragCoord);
    if (seed_style == 0)
        return length(fragCoord - 0.5 * iResolution.xy) < max(4.0, iResolution.y * 0.02);
    if (seed_style == 1)
        return hash21(floor(id / 6.0)) < 0.04;
    return mod(id.x, 64.0) < 4.0 && mod(id.y, 64.0) < 4.0;
}

vec2 state(vec2 uv)
{
    return texture(feedback, uv).rg;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 t = 1.0 / iResolution.xy;
    vec2 s = state(uv);

    // Empty buffer: start the simulation
    if (iFrame < 2 || s.x + s.y < 1e-5)
    {
        s = vec2(1.0, 0.0);
        if (is_seed(fragCoord))
            s = vec2(0.5, 1.0);
        fragColor = vec4(s, 0.0, 1.0);
        return;
    }
    if (auto_seed && is_seed(fragCoord))
        s.y = 1.0;

    vec2 lap = 0.2 * (state(uv + vec2(t.x, 0.0)) + state(uv - vec2(t.x, 0.0))
                    + state(uv + vec2(0.0, t.y)) + state(uv - vec2(0.0, t.y)))
             + 0.05 * (state(uv + t) + state(uv - t) + state(uv + vec2(t.x, -t.y)) + state(uv + vec2(-t.x, t.y)))
             - s;

    // The diffusion of this frame is fixed, the reaction is split into `iterations` smaller steps
    const int MAX_ITER = 8;
    int n = clamp(iterations, 1, MAX_ITER);
    float dt = sim_speed / float(n);
    for (int i = 0; i < MAX_ITER; i++)
    {
        if (i >= n)
            break;
        float uvv = s.x * s.y * s.y;
        s.x += (du * lap.x - uvv + feed * (1.0 - s.x)) * dt;
        s.y += (dv * lap.y + uvv - (kill + feed) * s.y) * dt;
        s = clamp(s, 0.0, 1.0);
    }

    fragColor = vec4(s, 0.0, 1.0);
}
