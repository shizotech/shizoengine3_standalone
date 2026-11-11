//@settings dtype=float32 format=rgba
// --- RuttEtra: a video as glowing scanlines bent by its brightness, in 3D (the Rutt/Etra synthesizer) ---
// lib/common.glsl says how it works. This pass adds the lines (L), their glow (B, B2) and the background.
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D L;
uniform sampler2D B;
uniform sampler2D B2;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 lit = max(texelFetch(L, ivec2(fragCoord), 0).rgb, vec3(0.0));
    float g = glow_size;
    vec3 halo = passSoft(B, uv).rgb * mix(1.6, 0.8, g) + passSoft(B2, uv).rgb * mix(0.6, 2.2, g);
    vec3 light = lit + glow * halo;
    vec3 col = 1.0 - exp(-light * exposure);
    float a = clamp(max(col.r, max(col.g, col.b)) * 1.5, 0.0, 1.0);
    if (background_mode == 1) {
        fragColor = vec4(col, a);
        return;
    }
    vec3 bg = background_mode == 2 ? texture(input, uv).rgb * picture_behind : background_color;
    // the lines are light: they add to the background (screen, so a bright background does not burn out)
    fragColor = vec4(1.0 - (1.0 - bg) * (1.0 - col), 1.0);
}
