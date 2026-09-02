// SFX2 EvolvingBlob - Continuous Blob Source
// Shadertoy format
// Produces a continuous, always-non-black output: a soft, evolving blob-like
// structure that fills the frame. More shape generation options than CenterBlob.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Blob base radius (fraction of the frame)
//@slider min=0.1 max=1.0 value=0.45
uniform float blob_radius;

// Noise-driven deformation strength
//@slider min=0.0 max=1.0 value=0.5
uniform float deform_amount;

// Number of lobes / spokes (0 = off)
//@int min=0 max=8 value=3
uniform int lobe_count;

// Which base shape to use
//@enum options=(Circle, Star, Polygon) value=0
uniform int base_shape;

// Number of sides for the Polygon option
//@int min=3 max=10 value=5
uniform int poly_sides;

// Colour depth (0 = background, 1 = full colour)
//@slider min=0.0 max=1.0 value=0.9
uniform float color_depth;

// Background colour (kept bright so the frame is never black)
//@rgb value=(0.15,0.10,0.22)
uniform vec3 background;

// Main blob colour
//@rgb value=(0.45,0.8,0.95)
uniform vec3 blob_color;

// Accent colour
//@rgb value=(0.95,0.6,0.15)
uniform vec3 accent_color;

// ---- helpers ----
float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p.yx + vec2(34.23, 3.35));
    return fract((p.x + p.y) * p.x);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Signed distance to a regular n-gon (centered at origin)
float sd_poly(vec2 p, float r, int n) {
    float a = 6.2831853 / float(n);
    float an = atan(p.y, p.x);
    float m = mod(an, a);
    m = abs(m - a * 0.5);
    return r * cos(a * 0.5) / cos(m) - length(p);
}

// Signed distance to an n-pointed star
float sd_star(vec2 p, float r, int points) {
    float a = 6.2831853 / float(points);
    float an = atan(p.y, p.x) + a * 0.5;
    float m = mod(an, a);
    m = abs(m - a * 0.5);
    float d = r * cos(a * 0.5) / cos(m) - length(p);
    return d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = (uv - 0.5) * vec2(iResolution.x / iResolution.y, 1.0);

    // Temporal noise-driven deformation of the radius
    float t = iTime * 0.5;
    float n = vnoise(vec2(p.x * 1.5, p.y * 1.5) + t * 0.3);
    float r = blob_radius;

    // Add lobes / spokes to make the shape more interesting
    if (lobe_count > 0) {
        float ang = atan(p.y, p.x);
        r += 0.15 * deform_amount * sin(float(lobe_count) * ang + iTime * 0.8);
    }

    // Apply the noise-driven deformation
    r += (n - 0.5) * 2.0 * deform_amount;

    // Pick the base shape
    float d;
    if (base_shape == 0) {
        d = length(p) - r;
    } else if (base_shape == 1) {
        d = sd_star(p, r, lobe_count > 0 ? lobe_count : 4);
    } else {
        d = sd_poly(p, r, poly_sides);
    }

    // Soft edge
    float cover = 1.0 - smoothstep(-0.15, 0.15, d);

    // Mix blob_color and accent_color by radial gradient
    float rad = clamp(length(p) / max(blob_radius * 1.4, 0.01), 0.0, 1.0);
    vec3 col = mix(accent_color, blob_color, 1.0 - rad);
    col = mix(col, vec3(1.0), cover * 0.3);

    vec3 bg = background;
    vec3 outcol = mix(bg, col, cover * color_depth);
    outcol = max(bg, outcol);

    fragColor = vec4(outcol, 1.0);
}
