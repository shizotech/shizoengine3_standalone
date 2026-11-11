// --- MaskRain: what every pass shares ---
#define MASK_AUTO 2
#include mapping.glsl
#include mask.glsl
#include beat.glsl

//@slider min=-60.0 max=60.0 value=8.0
uniform float fall_angle;     // degrees from straight down: wind
//@button value=1
uniform bool ground;          // the bottom of the picture is a floor the drops splash on

// The direction the drops fall, in pixels (y up)
vec2 rn_dir() {
    float a = radians(fall_angle);
    return vec2(sin(a), -cos(a));
}

// The fall map H (a pass of the doubling): distance along the fall to the next surface, in texels of the pass
// (1e5: none). Out of the picture: nothing, below it the floor when ground is on.
float rn_fetch(sampler2D H, vec2 q) {
    ivec2 s = textureSize(H, 0);
    ivec2 i = ivec2(floor(q));
    if (i.x < 0 || i.x >= s.x || i.y >= s.y) return 1e5;
    if (i.y < 0) return ground ? 0.0 : 1e5;
    return texelFetch(H, i, 0).r;
}
