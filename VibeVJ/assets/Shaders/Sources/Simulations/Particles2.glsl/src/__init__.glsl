//@settings dtype=float32 format=rgba
// --- Particles 2: up to a million GPU particles in 3D, drawn as real points (the particlesGPU look) ---
// S simulates them (lib/common.glsl says how), D draws them as GL points that add up (a point pass, SHADER_GUIDE.MD),
// this pass tonemaps the sum and keeps trails. Unlike Particles, no particle is lost and the count is a control.

uniform sampler2D D;
uniform sampler2D feedback;

//@slider min=0.0 max=4.0 value=1.0
uniform float exposure;             // how bright the sum of the points gets before it saturates
//@slider min=0.0 max=0.99 value=0.0
uniform float trails;               // keeps this share of the last frame: long trails near 1
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 sum = max(texture(D, uv).rgb, vec3(0.0));
    vec3 col = 1.0 - exp(-sum * exposure * 2.0);
    vec3 last = iFrame < 2 ? background : texture(feedback, uv).rgb;
    vec3 base = mix(background, last, trails);
    fragColor = vec4(clamp(max(base, background + col), 0.0, 1.0), 1.0);
}
