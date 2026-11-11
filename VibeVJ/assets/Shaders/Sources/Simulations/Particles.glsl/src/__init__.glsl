// --- Particles: GPU particles - a cloud of up to 130 000 points blown by forces (the Particle SOP / particlesGPU) ---
// Pass P simulates them (lib/common.glsl says how); this pass draws them, with trails if wanted.
#include lib/common.glsl

uniform sampler2D P;
uniform sampler2D feedback;

//@slider min=0.5 max=12.0 value=2.0
uniform float particle_size;        // radius in pixels of a 1080p picture
//@slider min=0.0 max=6.0 value=1.5
uniform float streak;               // draws each particle as a line along its motion, this many frames long
//@slider min=0.0 max=4.0 value=1.2
uniform float brightness;
//@slider min=0.0 max=2.0 value=0.4
uniform float glow;                 // a soft halo around each particle
//@enum options=(By age, By speed, Random, From field, Single color) value=0
uniform int color_mode;             // By age / By speed: from Color A to Color B; From field: the colour of the port Field
//@rgb value=(1.0, 0.75, 0.3)
uniform vec3 color_a;
//@rgb value=(0.2, 0.4, 1.0)
uniform vec3 color_b;
//@slider min=0.0 max=0.99 value=0.0
uniform float trails;               // keeps this share of the last frame: long trails near 1
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;

float segmentDistance(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 grid = textureSize(P, 0);
    vec2 gridF = vec2(grid);
    float cellPx = iResolution.y / gridF.y;              // pixels per cell
    vec2 pc = fragCoord / cellPx;                         // this pixel in cells
    ivec2 c = ivec2(floor(pc));
    float sizePx = particle_size / 1080.0 * iResolution.y;
    float reach = (sizePx * (1.0 + 2.0 * glow)) / cellPx + streak * VMAX;
    int r = int(clamp(ceil(reach), 1.0, 3.0));

    vec3 col = vec3(0.0);
    for (int y = -3; y <= 3; y++) {
        if (abs(y) > r)
            continue;
        for (int x = -3; x <= 3; x++) {
            if (abs(x) > r)
                continue;
            ivec2 n = c + ivec2(x, y);
            if (edge_mode == 0)
                n = (n % grid + grid) % grid;
            else if (n.x < 0 || n.y < 0 || n.x >= grid.x || n.y >= grid.y)
                continue;
            Particle p = decodeCell(texelFetch(P, n, 0));
            if (!p.alive)
                continue;
            vec2 cur = p.pos - p.vel;                     // P stores the next position
            if (edge_mode == 0)
                cur += gridF * floor((pc - cur) / gridF + 0.5);
            float d = segmentDistance(pc, cur, cur - p.vel * streak) * cellPx;
            float life = clamp(p.age / lifeFrames(p.seed), 0.0, 1.0);
            float fade = smoothstep(0.0, 0.08, life) * (1.0 - smoothstep(0.7, 1.0, life));
            float s = sizePx * (0.6 + 0.8 * hash11(p.seed));
            float core = 1.0 - smoothstep(s * 0.5, s, d);
            float halo = glow * exp(-d * d / (2.0 * s * s * (1.0 + 4.0 * glow)));
            float a = (core + 0.3 * halo) * fade;
            if (a <= 0.0)
                continue;
            vec3 tint;
            if (color_mode == 0)
                tint = mix(color_a, color_b, life);
            else if (color_mode == 1)
                tint = mix(color_b, color_a, clamp(length(p.vel) / (0.5 * VMAX), 0.0, 1.0));
            else if (color_mode == 2)
                tint = mix(color_a, color_b, hash11(p.seed + 3.0));
            else if (color_mode == 3)
                tint = texture(field, cur / gridF).rgb;
            else
                tint = color_a;
            col += tint * a;
        }
    }
    col *= brightness;

    vec3 last = iFrame < 2 ? background : texture(feedback, fragCoord / iResolution.xy).rgb;
    vec3 base = mix(background, last, trails);
    fragColor = vec4(clamp(base + col, 0.0, 1.0), 1.0);
}
