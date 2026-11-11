//@settings dtype=float32 format=rgba renderscale=0.25
// --- Particles, pass P: the grid of cells, one particle each (lib/common.glsl says how) ---
#include lib/common.glsl

uniform sampler2D feedback;
uniform sampler2D T;

// The forces on a particle at pos (cells) with velocity vel: the new velocity
vec2 integrate(vec2 pos, vec2 vel, vec2 grid) {
    vec2 uv = pos / grid;
    float h = grid.y;
    vec2 center = emitter_position * grid;
    vec2 toC = center - pos;
    float dist = max(length(toC), 1.0);
    vec2 dirC = toC / dist;

    vec2 f = vec2(0.0);
    // wind: curl noise, divergence free, so it swirls without bunching the particles up
    vec2 p = pos / h * flow_scale;
    f += flow_strength * 0.06 * curlNoise(p + vec2(0.0, iTime * flow_speed));
    f += gravity * 0.02;
    f += attract * 0.02 * dirC * min(dist / (0.25 * h), 1.0);
    f += orbit * 0.02 * vec2(-dirC.y, dirC.x);
    f -= beat_kick * 0.15 * texture(T, vec2(0.5)).b * dirC;
    if (field_push != 0.0) {
        vec2 e = 2.0 / grid;
        float lx = luminance(texture(field, uv + vec2(e.x, 0.0)).rgb) - luminance(texture(field, uv - vec2(e.x, 0.0)).rgb);
        float ly = luminance(texture(field, uv + vec2(0.0, e.y)).rgb) - luminance(texture(field, uv - vec2(0.0, e.y)).rgb);
        f += field_push * 0.25 * vec2(lx, ly);
    }
    vel = vel * (1.0 - drag) + f;
    float sp = length(vel);
    if (sp > VMAX)
        vel *= VMAX / sp;
    return vel;
}

// How likely an empty cell gives birth, and the start velocity
float birthChance(vec2 cell, vec2 grid, vec2 rnd, out vec2 vel) {
    vec2 center = emitter_position * grid;
    vec2 d = cell + 0.5 - center;
    float r = length(d) / grid.y;
    vec2 out_ = length(d) > 0.0 ? normalize(d) : vec2(1.0, 0.0);
    float a = rnd.x * TAU;
    vec2 randomDir = vec2(cos(a), sin(a));
    float speed = start_speed * (1.0 - spread * rnd.y);
    vel = normalize(mix(out_, randomDir, spread) + 1e-4) * speed;
    float chance = 0.0;
    if (emitter == 0) {
        vel = randomDir * speed;
        chance = emit_rate * 0.05;
    } else if (emitter == 1) {
        chance = emit_rate * (1.0 - smoothstep(emitter_size * 0.8, emitter_size, r));
    } else if (emitter == 2) {
        chance = emit_rate * (1.0 - smoothstep(0.0, 0.015, abs(r - emitter_size)));
    } else if (emitter == 3) {
        float x = abs(d.x) / grid.y;
        chance = emit_rate * (1.0 - smoothstep(emitter_size * 0.8, emitter_size, x)) * step(abs(d.y), 1.5);
        vel = normalize(vec2((rnd.x - 0.5) * spread, 1.0)) * speed * 2.0;
    } else {
        chance = emit_rate * 0.3 * luminance(texture(field, (cell + 0.5) / grid).rgb);
        vel = randomDir * speed * 0.5;
    }
    // the burst at the beat: the emitter fires outwards
    float burst = beat_burst * texture(T, vec2(0.5)).a;
    if (burst > 0.0 && emitter != 0 && emitter != 4) {
        float inside = 1.0 - smoothstep(emitter_size, emitter_size * 1.5 + 0.01, r);
        if (rnd.y < burst * inside) {
            vel = normalize(mix(out_, randomDir, 0.3 * spread) + 1e-4) * burst_speed * (0.5 + 0.5 * rnd.x);
            return 1.0;
        }
    }
    return chance;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 grid = textureSize(feedback, 0);
    vec2 gridF = vec2(grid);
    ivec2 c = ivec2(floor(fragCoord));
    Particle none;
    none.alive = false;
    if (reset || iFrame < 2 || grid != ivec2(iResolution.xy)) {
        fragColor = encodeCell(none);
        return;
    }

    // take over the particle that moves into this cell
    Particle best = none;
    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            ivec2 n = c + ivec2(x, y);
            if (edge_mode == 0)
                n = (n % grid + grid) % grid;
            else if (n.x < 0 || n.y < 0 || n.x >= grid.x || n.y >= grid.y)
                continue;
            Particle p = decodeCell(texelFetch(feedback, n, 0));
            if (!p.alive || ivec2(floor(p.pos)) != c)
                continue;
            if (!best.alive || p.age > best.age || (p.age == best.age && p.seed < best.seed))
                best = p;
        }
    }

    vec4 rnd = hash44(vec4(vec2(c), float(iFrame % 65536), 7.0));
    if (best.alive) {
        best.age += 1.0;
        if (best.age > lifeFrames(best.seed)) {
            fragColor = encodeCell(none);
            return;
        }
    } else {
        vec2 vel;
        float chance = birthChance(vec2(c), gridF, rnd.zw, vel);
        if (rnd.x >= chance) {
            fragColor = encodeCell(none);
            return;
        }
        best.alive = true;
        best.pos = vec2(c) + 0.05 + 0.9 * rnd.yz;
        best.vel = vel;
        best.age = 0.0;
        best.seed = floor(rnd.w * 4095.0);
    }

    // the particle is at best.pos now; work out where it is in the next frame
    best.vel = integrate(best.pos, best.vel, gridF);
    best.pos += best.vel;
    if (edge_mode == 0)
        best.pos = mod(best.pos, gridF);
    fragColor = encodeCell(best);
}
