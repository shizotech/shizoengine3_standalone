//@settings dtype=float32 format=rgba

//@rgb value=(1.0, 0.8, 0.2)
uniform vec3 spark_color;

//@rgb value=(0.0, 0.0, 0.02)
uniform vec3 bg_color;

//@slider min=0.25 max=8.0 value=4.0
uniform float burst_interval;

//@int min=4 max=32 value=24
uniform int particle_count;

//@slider min=0.5 max=4.0 value=1.5
uniform float spark_life;

//@slider min=0.0 max=2.0 value=0.3
uniform float gravity;

//@slider min=0.2 max=3.0 value=1.0
uniform float spark_size;

//@slider min=0.0 max=1.0 value=0.15
uniform float spark_glow;

// Deterministic hash from (burst_index, particle index) -> [0,1]
float hash12(vec2 p)
{
    p *= 1000.0;
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    // Current burst cycle (iTime is measured in beats)
    float burst_index = floor(iTime / burst_interval);
    float age = iTime - burst_index * burst_interval;

    vec3 col = bg_color;

    // Pseudo-random launch origin for this burst
    float ox = hash12(vec2(burst_index, 7.31));
    float oy = hash12(vec2(burst_index, 13.77));
    vec2 origin = vec2(0.15 + 0.7 * ox, 0.35 + 0.5 * oy);

    // Sum additive sparks from up to particle_count particles
    for (int k = 0; k < 32; k++)
    {
        if (k >= particle_count) break;

        // Deterministic direction + speed per particle
        float hA = hash12(vec2(burst_index, float(k)));
        float hS = hash12(vec2(burst_index + 50.0, float(k)));
        float hV = hash12(vec2(burst_index + 90.0, float(k)));

        float angle = hA * 6.28318;
        float speed = 0.15 + 0.55 * hS;
        float vy_bias = hV; // 0.7 -> bias upward launch
        vec2 dir = vec2(cos(angle), sin(angle) * (0.4 + 0.6 * vy_bias));

        // Particle position (2D, in uv space)
        vec2 pos = origin + dir * age * speed;
        pos.y += 0.5 * gravity * age * age; // gravity pulls sparks downward

        // Lifetime fade: alpha decays over spark_life
        float life = clamp(1.0 - age / spark_life, 0.0, 1.0);

        // Distance based falloff (soft point + glow)
        vec2 d = uv - pos;
        float dist = length(d);
        float core = smoothstep(spark_size, 0.0, dist);
        float halo = exp(-dist * dist / (0.001 + 0.01 * spark_glow)) * spark_glow;
        float a = core * life + halo * life;

        col += spark_color * a;
    }

    fragColor = vec4(col, 1.0);
}
