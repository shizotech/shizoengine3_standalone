//@settings dtype=float32 format=rgba

//@slider min=0.020 max=0.060 value=0.037
uniform float feed_rate;

//@slider min=0.050 max=0.075 value=0.062
uniform float kill_rate;

//@slider min=0.8 max=1.2 value=1.0
uniform float diffA;

//@slider min=0.3 max=0.8 value=0.5
uniform float diffB;

//@slider min=0.0 max=1.0 value=0.15
uniform float step_speed;

//@int min=1 max=8 value=2
uniform int iterations;

//@button
uniform bool auto_seed;

uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;

    // Load previous sim state from feedback buffer
    vec4 s = texture(feedback, uv);
    float A = s.r;
    float B = s.g;

    // Seed an initial cluster on frame 0 so the sim actually starts
    if (auto_seed)
    {
        vec2 id = floor(fragCoord.xy);
        vec2 c = 0.5 * iResolution.xy;
        if (length(id - c) < 2.0)
        {
            A = 0.05;
            B = 1.0;
        }
    }

    float dt = step_speed;

    for (int it = 0; it < iterations; it++)
    {
        float A_lap = 0.0, B_lap = 0.0;

        // 8-neighbour Laplacian of A
        A_lap += texture(feedback, uv + vec2(texel.x, 0.0)).r;
        A_lap += texture(feedback, uv + vec2(-texel.x, 0.0)).r;
        A_lap += texture(feedback, uv + vec2(0.0, texel.y)).r;
        A_lap += texture(feedback, uv + vec2(0.0, -texel.y)).r;
        A_lap += texture(feedback, uv + vec2(texel.x, texel.y)).r;
        A_lap += texture(feedback, uv + vec2(-texel.x, texel.y)).r;
        A_lap += texture(feedback, uv + vec2(texel.x, -texel.y)).r;
        A_lap += texture(feedback, uv + vec2(-texel.x, -texel.y)).r;
        A_lap += A;
        A_lap -= 4.0 * A;

        // 8-neighbour Laplacian of B
        B_lap += texture(feedback, uv + vec2(texel.x, 0.0)).g;
        B_lap += texture(feedback, uv + vec2(-texel.x, 0.0)).g;
        B_lap += texture(feedback, uv + vec2(0.0, texel.y)).g;
        B_lap += texture(feedback, uv + vec2(0.0, -texel.y)).g;
        B_lap += texture(feedback, uv + vec2(texel.x, texel.y)).g;
        B_lap += texture(feedback, uv + vec2(-texel.x, texel.y)).g;
        B_lap += texture(feedback, uv + vec2(texel.x, -texel.y)).g;
        B_lap += texture(feedback, uv + vec2(-texel.x, -texel.y)).g;
        B_lap += B;
        B_lap -= 4.0 * B;

        // Gray-Scott reaction term: f*AB^2 - k*AB^2 - B
        float reaction = feed_rate * A * B * B - kill_rate * A * B * B - B;
        A += (diffA * A_lap + feed_rate - kill_rate * A * B * B) * dt;
        B += (diffB * B_lap + reaction) * dt;
        A = clamp(A, 0.0, 1.0);
        B = clamp(B, 0.0, 1.0);
    }

    // Output encodes sim state in RG for the next frame (feedback binding)
    fragColor = vec4(A, B, 0.0, 1.0);
}
