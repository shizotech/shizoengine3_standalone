//@settings dtype=float32 format=rgba

//@slider min=10.0 max=400.0 value=120.0
uniform float particle_count;
//@slider min=0.0 max=3.0 value=0.8
uniform float speed;
//@slider min=0.0 max=2.0 value=1.0
uniform float spread;
//@rgb value=(0.3,0.7,1.0)
uniform vec3 core_color;
//@rgb value=(1.0,0.4,0.7)
uniform vec3 arm_color;
//@slider min=0.0 max=1.0 value=0.5
uniform float audio_react;

float hash(float n) {
    float s = fract(sin(n * 12.9898) * 43758.5453);
    return s;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord.xy - 0.5 * iResolution.xy) / iResolution.y;
    float t = iTime * speed;
    float bass = texture(iChannel0, vec2(0.0, 0.0)).x;
    float mid  = texture(iChannel0, vec2(0.5, 0.0)).x;

    vec3 col = vec3(0.0);
    float count = clamp(particle_count, 10.0, 400.0);
    for (float i = 0.0; i < count; i++) {
        float fi = float(i);
        float r = hash(fi * 12.9898 + 1.3) * spread;
        float a = fi * 2.39996 + t * 0.2 + hash(fi * 78.233) * 6.28;
        vec2 p = vec2(cos(a), sin(a)) * (r * (1.0 + 0.4 * audio_react * bass));
        float d = length(uv - p);
        float size = 0.004 + 0.004 * hash(fi * 3.7);
        float particle = smoothstep(size, size * 0.3, d);
        vec3 pc = mix(arm_color, core_color, 1.0 - r);
        col += particle * pc * (0.6 + 0.8 * mid * audio_react);
    }
    col = clamp(col, 0.0, 1.0);
    fragColor = vec4(col, 1.0);
}
