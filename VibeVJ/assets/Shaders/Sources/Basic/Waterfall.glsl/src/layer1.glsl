// FX3 Waterfall - Pass 1 (BASE FLOW)
// Shadertoy format
// The base waterfall: a vertical flow with selectable material and thickness.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Water / material type
//@enum options=(Water, Ice, Lava, Smoke, Plasma) value=0
uniform int material;

// Thickness of the waterfall (fraction of the frame width)
//@slider min=0.1 max=1.0 value=0.5
uniform float thickness;

// Rotation of the waterfall (0..1 = 0..360deg)
//@slider min=0.0 max=1.0 value=0.0
uniform float rotation;

// Overall scale
//@slider min=0.2 max=3.0 value=1.0
uniform float scale;

// Flow speed
//@slider min=0.0 max=4.0 value=1.0
uniform float speed;

// Main colour of the waterfall
//@rgb value=(0.3,0.7,1.0)
uniform vec3 base_color;

// Highlight colour (foam / sparkle)
//@rgb value=(0.9,0.95,1.0)
uniform vec3 hi_color;

// Background colour (kept non-black)
//@rgb value=(0.04,0.05,0.10)
uniform vec3 background;

// ---- helpers ----
float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = uv - 0.5;
    p.x *= iResolution.x / iResolution.y;

    // rotate the whole thing
    float ang = rotation * 6.2831853;
    float ca = cos(ang);
    float sa = sin(ang);
    vec2 rp = vec2(p.x * ca - p.y * sa, p.x * sa + p.y * ca) / max(scale, 0.001);

    float t = iTime * speed;

    // Waterfall body: a vertical band across the frame
    // |x| <= thickness/2
    float halfW = thickness * 0.5;
    float inband = 1.0 - smoothstep(halfW - 0.05, halfW + 0.05, abs(rp.x));

    // Vertical flow coordinate (scrolls downward)
    float flow = rp.y - t;

    // Streaky / flowing texture based on the selected material
    float pattern;
    float foam;
    if (material == 0) {
        // Water: fast vertical streaks + foam specks
        float s = fract(rp.x * 40.0 + flow * 2.0);
        pattern = 0.5 + 0.5 * sin((rp.y - t) * 8.0 + hash1(rp.x * 6.28) * 6.28);
        float fh = hash1(rp.x * 12.9898 + iFrame * 0.02);
        foam = smoothstep(0.05, 0.0, abs(fract(rp.x * 30.0) - 0.5) * 0.5) * step(0.85, fh);
    } else if (material == 1) {
        // Ice: slow, crystalline
        pattern = 0.5 + 0.5 * sin(rp.y * 3.0 - t * 0.3 + hash1(rp.x * 6.28) * 6.28);
        foam = 0.0;
    } else if (material == 2) {
        // Lava: bright core, slow bubbling
        pattern = 0.5 + 0.5 * sin(rp.y * 5.0 - t * 0.5 + hash1(rp.x * 6.28) * 6.28);
        foam = hash1(rp.x * 78.233 + iTime * 0.5) * step(0.9, hash1(rp.y * 12.9898));
    } else if (material == 3) {
        // Smoke: soft rising (invert flow direction)
        pattern = 0.5 + 0.5 * sin(rp.y * 4.0 + t * 0.4 + hash1(rp.x * 6.28) * 6.28);
        foam = 0.0;
    } else {
        // Plasma: fast swirling streaks
        float swirl = sin(rp.y * 6.0 - t + hash1(rp.x * 6.28) * 6.28);
        pattern = 0.5 + 0.5 * swirl;
        foam = smoothstep(0.1, 0.0, abs(fract(rp.x * 20.0) - 0.5)) * step(0.8, hash1(rp.y * 12.9898 + iFrame * 0.01));
    }

    // Combine: base colour modulated by pattern, plus highlights
    vec3 col = base_color * (0.4 + 0.6 * pattern) * inband;
    col += hi_color * foam * inband * 0.8;

    // Thin leading edge highlight at the top of the fall
    float topedge = smoothstep(0.1, 0.0, abs(rp.y - 0.5));
    col += hi_color * topedge * inband * 0.5;

    vec3 bg = background;
    col = max(bg, col);
    fragColor = vec4(col, 1.0);
}
