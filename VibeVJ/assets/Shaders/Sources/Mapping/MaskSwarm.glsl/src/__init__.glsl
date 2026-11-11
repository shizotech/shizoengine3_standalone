//@settings dtype=float32 format=rgba
// --- MaskSwarm (#586, projection mapping building blocks: simulations in the mask) ---
// A flock of a few thousand boids that streams around the mapped objects (or stays inside them), gathers along their
// outlines, follows a target and scatters on a pulse. The boids live on a grid of cells at an eighth of the size
// (pass B: separation, alignment, cohesion, the walls of the mask from a jump flood at a quarter of the size, passes M,
// E, J1..J10), pass C counts them, pass R draws their trails; this pass draws each boid as a bird, a fish, a dot, a
// streak or a firefly.
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D B;
uniform sampler2D R;
uniform sampler2D C;
uniform sampler2D M;
uniform sampler2D J10;
uniform sampler2D T;

//@enum options=(Birds, Fish, Dots, Streaks, Fireflies) value=0
uniform int shape;
//@slider min=1.0 max=14.0 value=6.0
uniform float boid_size;      // pixels at 1080p
//@slider min=0.0 max=2.0 value=0.4
uniform float glow;
//@slider min=0.0 max=3.0 value=1.0
uniform float brightness;
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;
//@enum options=(Black, Colour, Outline, Transparent, Boids over it) value=0
uniform int obstacle_view;    // what the walls show: on a real object Black keeps it dark
//@rgb value=(0.12, 0.12, 0.15)
uniform vec3 obstacle_color;
//@enum options=(Final, Cells, Distance field, Count) value=0
uniform int debug_view;
//@slider min=0.0 max=1.0 value=0.0
uniform float show_mask;      // calibration: the mask in red over the picture

float seg_dist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

// The distance (pixels) from p (pixels, in the frame of a boid: x forward) to its shape, size s
float boid_shape(vec2 p, float s, float spd, float seed, out float soft) {
    float t = float(iFrame) * 0.25 + seed * 1.7;
    soft = 1.0;
    if (shape == 0) {
        // a bird: two wings that flap
        float flap = 0.45 + 0.4 * sin(t * (1.5 + spd * 2.0));
        vec2 tip = vec2(s * 0.6, 0.0);
        float d = min(seg_dist(p, tip, vec2(-s * 0.5, s * flap)), seg_dist(p, tip, vec2(-s * 0.5, -s * flap)));
        return d - s * 0.12;
    }
    if (shape == 1) {
        // a fish: a body and a tail that wags
        float wag = sin(t * 1.3) * 0.35;
        vec2 q = p;
        q.y -= wag * smoothstep(0.0, -s, q.x) * s * 0.4;
        float body = (length(q / vec2(s * 0.75, s * 0.28)) - 1.0) * s * 0.28;
        vec2 tp = q - vec2(-s * 0.85, 0.0);
        float tail = max(abs(tp.y) - (s * 0.05 + max(-tp.x, 0.0) * 0.9), max(tp.x - s * 0.1, -tp.x - s * 0.45));
        return min(body, tail);
    }
    if (shape == 3) return seg_dist(p, vec2(0.0), vec2(-s * (1.0 + spd * 6.0), 0.0)) - s * 0.15;
    if (shape == 4) {
        soft = 0.5 + 0.5 * sin(t * 0.7 + seed * 5.0);
        return length(p) - s * 0.25;
    }
    return length(p) - s * 0.35;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    ivec2 grid = textureSize(B, 0);
    float cell = iResolution.x / float(grid.x);       // pixels in a cell
    vec2 gp = fragCoord / cell;
    ivec2 c0 = ivec2(floor(gp));
    float s = boid_size * iResolution.y / 1080.0;
    float reach = s * (1.0 + glow * 1.5 + (shape == 3 ? 6.0 * speed : 0.0)) / cell;
    int r = int(clamp(ceil(reach), 1.0, 2.0));

    vec3 rgb = background + mp_bilinear_uv(R, uv).rgb;
    for (int y = -2; y <= 2; y++) {
        if (abs(y) > r) continue;
        for (int x = -2; x <= 2; x++) {
            if (abs(x) > r) continue;
            ivec2 n = c0 + ivec2(x, y);
            if (borders == 0) n = (n % grid + grid) % grid;
            else if (n.x < 0 || n.y < 0 || n.x >= grid.x || n.y >= grid.y) continue;
            Boid b = sw_decode(texelFetch(B, n, 0));
            if (!b.alive) continue;
            vec2 cur = b.pos - b.vel;                    // B keeps the place of the next frame
            vec2 d = (gp - cur) * cell;
            if (borders == 0) d -= vec2(grid) * cell * floor(d / (vec2(grid) * cell) + 0.5);
            float sp = length(b.vel);
            vec2 f = sp > 1e-5 ? b.vel / sp : vec2(1.0, 0.0);
            vec2 lp = vec2(dot(d, f), dot(d, vec2(-f.y, f.x)));
            float soft;
            float dist = boid_shape(lp, s, sp, b.seed, soft);
            float core = 1.0 - smoothstep(-0.6, 0.6, dist);
            float halo = glow * exp(-max(dist, 0.0) / max(s * 0.5, 1.0)) * 0.5;
            rgb += sw_color(b, speed) * (core + halo) * soft * brightness;
        }
    }

    // the mask from the passes (M, the jump flood), not from the port: in the main pass the unlinked port Mask was seen
    // reading another texture (#586)
    float m = smoothstep(0.3, 0.7, mp_bilinear_uv(M, uv).r);
    float sw = sw_wall_of(m);
    float alpha = 1.0;
    if (obstacle_view == 0) rgb *= 1.0 - sw;
    else if (obstacle_view == 1) rgb = mix(rgb, obstacle_color, sw);
    else if (obstacle_view == 2) {
        vec2 nrm;
        float sd = jfa_signed(J10, M, fragCoord, nrm);
        float line = 1.0 - smoothstep(1.0, 2.5, abs(sd));
        rgb = mix(rgb * (1.0 - sw), obstacle_color * 4.0, line);
    } else if (obstacle_view == 3) alpha = 1.0 - sw;

    if (debug_view == 1) {
        Boid b = sw_decode(texelFetch(B, clamp(c0, ivec2(0), grid - 1), 0));
        rgb = b.alive ? sw_color(b, speed) : vec3(0.05) + 0.2 * vec3(sw);
    } else if (debug_view == 2) {
        vec2 nrm;
        float sd = jfa_signed(J10, M, fragCoord, nrm);
        rgb = vec3(0.5 + 0.5 * sin(sd * 0.2)) * (sd < 0.0 ? vec3(1.0, 0.4, 0.3) : vec3(0.4, 0.8, 1.0));
    } else if (debug_view == 3) {
        float share = texelFetch(C, ivec2(0, 0), 0).r;
        rgb = mix(rgb, vec3(0.2, 1.0, 0.3), step(uv.x, share / max(population, 1e-3) * 0.5) * step(uv.y, 0.02));
        rgb = mix(rgb, vec3(1.0), step(abs(uv.x - 0.5), 0.002) * step(uv.y, 0.03));
    }

    if (show_mask > 0.0) {
        rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * m);
        alpha = max(alpha, show_mask);
    }
    fragColor = vec4(rgb, alpha);
}
