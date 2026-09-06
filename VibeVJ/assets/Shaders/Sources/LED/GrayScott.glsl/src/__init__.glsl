//@settings dtype=float32 format=rgba

// --- Gray-Scott reaction-diffusion simulation pass ---
// This pass iterates the PDE and writes the sim state (R=u, G=v) into the
// feedback buffer so the next frame can continue the simulation.

// Cheap, deterministic 2D -> 1D hash in [0,1] (inlined). Used for the
// "Scatter" seed style so seed positions are reproducible and bounded.
float hash21(vec2 p)
{
    float h = dot(p, vec2(127.1, 311.7));
    return clamp(fract(sin(h) * 43758.5453), 0.0, 1.0);
}

//@slider min=0.5 max=2.5 value=1.0
uniform float du;

//@slider min=0.5 max=2.5 value=0.5
uniform float dv;

//@slider min=0.05 max=0.08 value=0.062
uniform float feed;

//@slider min=0.01 max=0.08 value=0.061
uniform float kill;

//@slider min=0.1 max=2.0 value=0.5
uniform float sim_speed;

//@int min=1 max=8 value=2
uniform int iterations;

//@button
uniform bool auto_seed;

//@enum options=(Center, Scatter, Grid)
uniform int seed_style;

// TWO colors: dark background + bright accent. Used for a live preview
// (written to the B channel) so the sim pass is viewable on its own. The
// simulation reads only R/G, so the B-channel preview is harmless to the
// feedback mechanism.
//@rgb value=(0.02, 0.02, 0.05)
uniform vec3 background_color;

//@rgb value=(0.3, 0.9, 1.0)
uniform vec3 foreground_color;

// Feedback buffer: auto-binds to this shader's own output (the sim state).
uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;

    // Load previous sim state from the feedback buffer.
    vec4 s = texture(feedback, uv);
    float u = s.r;
    float v = s.g;

    // Seed the initial condition on frame 0 so the sim actually starts.
    // iFrame is an engine-injected uniform (auto-incremented, starts at 0).
    if (auto_seed && iFrame == 0)
    {
        if (seed_style == 0)
        {
            // Center: a single central cluster.
            vec2 c = 0.5 * iResolution.xy;
            if (length(fragCoord.xy - c) < 3.0)
            {
                u = 0.05;
                v = 1.0;
            }
        }
        else if (seed_style == 1)
        {
            // Scatter: a few deterministic random clusters (uses the 2D hash).
            vec2 id = floor(fragCoord.xy);
            vec2 p = id / iResolution.xy;
            float h = hash21(p);
            if (h < 0.12)
            {
                u = 0.05;
                v = 1.0;
            }
        }
        else
        {
            // Grid: a regular lattice of clusters (deterministic).
            vec2 id = floor(fragCoord.xy);
            if (mod(id.x, 64.0) < 3.0 && mod(id.y, 64.0) < 3.0)
            {
                u = 0.05;
                v = 1.0;
            }
        }
    }

    float dt = sim_speed;
    // 4-neighbour Laplacian with an explicit, bounded normalisation factor.
    // The neighbour count (4) is a fixed, non-zero constant denominator.
    const float NEIGHBOURS = 4.0;

    // Sample neighbours from the feedback buffer ONCE. Each iteration of the
    // sub-step loop then integrates the local (u, v) state forward using the
    // pre-sampled Laplacian. This keeps the work bounded and the fields clamped.
    float u_lap = texture(feedback, uv + vec2(texel.x, 0.0)).r - u;
    u_lap += texture(feedback, uv + vec2(-texel.x, 0.0)).r - u;
    u_lap += texture(feedback, uv + vec2(0.0, texel.y)).r - u;
    u_lap += texture(feedback, uv + vec2(0.0, -texel.y)).r - u;

    float v_lap = texture(feedback, uv + vec2(texel.x, 0.0)).g - v;
    v_lap += texture(feedback, uv + vec2(-texel.x, 0.0)).g - v;
    v_lap += texture(feedback, uv + vec2(0.0, texel.y)).g - v;
    v_lap += texture(feedback, uv + vec2(0.0, -texel.y)).g - v;

    // Normalise by the neighbour count (safe constant denominator).
    u_lap /= NEIGHBOURS;
    v_lap /= NEIGHBOURS;

    // NOTE: use a CONSTANT loop bound (8) with a break guard. A uniform
    // used directly as the bound can fail in strict GLSL, so we follow the
    // safe pattern (constant max + break).
    const int MAX_ITER = 8;
    for (int it = 0; it < MAX_ITER; it++)
    {
        if (it >= iterations) break;

        // Gray-Scott reaction terms:
        //   du = du*D(u) + f - k*u*v*v
        //   dv = dv*D(v) + f*u*v*v - v
        // Use the *local* (u, v) at this sub-step, not the previous frame.
        float reaction = feed * u * v * v - v;
        float du_rate = du * u_lap + feed - kill * u * v * v;
        float dv_rate = dv * v_lap + reaction;

        u += du_rate * dt;
        v += dv_rate * dt;

        // NUMERICAL STABILITY: clamp both fields into [0,1] every sub-step
        // so neither can run away or produce NaN.
        u = clamp(u, 0.0, 1.0);
        v = clamp(v, 0.0, 1.0);
    }

    // Live preview (B channel): tint the sim state with the two colors.
    // This is harmless to the feedback mechanism (sim reads only R/G).
    float intensity = smoothstep(0.0, 0.5, v);
    vec3 preview = mix(background_color, foreground_color, clamp(intensity, 0.0, 1.0));

    // Encode the next frame's sim state in the RG channels for the feedback
    // binding and for the render pass (A.glsl) via main_image. The B channel
    // carries a two-color preview so the pass is viewable standalone.
    fragColor = vec4(u, v, clamp(preview.b, 0.0, 1.0), 1.0);
}
