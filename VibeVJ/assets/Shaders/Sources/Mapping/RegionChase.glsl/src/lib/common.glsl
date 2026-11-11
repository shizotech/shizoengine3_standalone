// --- RegionChase: what every pass shares ---
#define MASK_AUTO 2
#include mapping.glsl
#include mask.glsl
#include beat.glsl

//@enum options=(Connected shapes, Colours of an ID map) value=0
uniform int region_source;    // a white shape is a region; or every flat colour of an ID map is one (black: none)

const float RC_W = 8192.0;    // the order of the labels: y * RC_W + x

float rc_index(vec2 l) { return l.y * RC_W + l.x; }

// The region key at a uv of the picture: 0 none, 1 a white shape, or 1 + the colour of an ID map (4 bits each)
float rc_key(vec2 uv) {
    if (region_source == 0 || mp_mask_mode() != 1) return mp_mask(uv) > 0.5 ? 1.0 : 0.0;
    vec2 m = mp_mask_uv(uv);
    if (m.x < 0.0 || m.y < 0.0 || m.x > 1.0 || m.y > 1.0) return 0.0;
    ivec2 ts = textureSize(mask, 0);
    // nearest, so the colours of two regions are never mixed
    vec4 c = texelFetch(mask, clamp(ivec2(m * vec2(ts)), ivec2(0), ts - 1), 0);
    if (max(c.r, max(c.g, c.b)) < mask_threshold) return 0.0;
    vec3 q = floor(c.rgb * 15.0 + 0.5);
    return 1.0 + q.r * 256.0 + q.g * 16.0 + q.b;
}
