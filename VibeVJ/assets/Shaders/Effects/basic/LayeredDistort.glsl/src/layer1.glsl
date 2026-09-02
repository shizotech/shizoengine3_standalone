// FX2 LayeredDistort - Pass 1 (DISTORT)
// Shadertoy format
// Consumes the external input (iChannel0) and applies the layered
// form-based distortion (triangle / pixel / hex tiling).

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Which form tiling to layer
//@enum options=(Pixel, Triangle, Hex) value=0
uniform int form_type;

// Overall distortion strength
//@slider min=0.0 max=1.0 value=0.4
uniform float distort_strength;

// Number of stacked distortion layers
//@int min=1 max=4 value=2
uniform int layer_count;

// Randomness / phase offset per layer
//@slider min=0.0 max=1.0 value=0.3
uniform float layer_phase;

// Temporal wobble of the distortion
//@slider min=0.0 max=1.0 value=0.5
uniform float wobble;

// Background fill for out-of-bounds
//@rgb value=(0.03,0.03,0.06)
uniform vec3 background;

#include helper.glsl

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    vec2 work_uv = uv;

    // Stack up to 4 distortion layers; each layer warps the coordinates
    // toward the center of its tiling cell.
    for (int layer = 0; layer < 4; layer++) {
        if (layer >= layer_count) break;

        float phase = float(layer) * layer_phase * 6.2831853 + iTime * wobble * (0.5 + 0.5 * float(layer));
        // Each layer uses a slightly different cell scale so layers don't perfectly overlap
        float scale = 1.0 + 0.15 * float(layer);

        vec2 lu = work_uv;
        int cid;
        vec2 cell_center;
        if (form_type == 0)
            cell_center = pixel_form(lu, cid);
        else if (form_type == 1)
            cell_center = tri_form(lu, cid);
        else
            cell_center = hex_form(lu, cid);

        // Per-cell deterministic offset + temporal phase
        float seed = fract(sin(float(cid) * 12.9898) * 43758.5453);
        float pull = distort_strength * (0.6 + 0.4 * sin(phase + seed * 6.2831853));
        // Warp: pull the coordinate toward the cell center, scaled by the layer
        vec2 warped = mix(work_uv, cell_center * scale, pull);
        work_uv = warped;
    }

    work_uv = clamp(work_uv, vec2(0.0), vec2(1.0));

    vec3 color = texture(iChannel0, work_uv).rgb;
    vec3 bg = background;
    color = mix(bg, color, step(0.0, work_uv.x) * step(work_uv.x, 1.0) * step(0.0, work_uv.y) * step(work_uv.y, 1.0));

    fragColor = vec4(color, 1.0);
}
