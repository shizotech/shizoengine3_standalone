//@settings dtype=float32 format=rgba

//@slider min=0.0 max=5.0 value=0.6
uniform float speed;
//@rgb value=(0.1,0.55,1.0)
uniform vec3 color_a;
//@rgb value=(1.0,0.2,0.6)
uniform vec3 color_b;
//@slider min=0.0 max=2.0 value=1.0
uniform float intensity;
//@slider min=1.0 max=20.0 value=6.0
uniform float freq;

float audio(float x) {
    return texture(iChannel0, vec2(x, 0.0)).x;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    float t = iTime * speed;
    float bass = audio(0.0);
    float mid  = audio(0.5);
    float high = audio(1.0);

    float wave = 0.0;
    wave += sin((uv.x + t * 0.3) * freq);
    wave += sin((uv.y - t * 0.4) * (freq + 1.0));
    wave += sin((uv.x + uv.y + t) * (freq * 0.5));
    wave += sin(length(uv - vec2(0.5)) * (freq * 1.5) - t * 2.0);
    wave = wave * 0.25;

    wave = wave + bass * 2.0;

    float phase = fract(t * 0.1) + wave * mid;
    vec3 col = mix(color_a, color_b, 0.5 + 0.5 * sin(6.2831853 * phase));
    col = 0.3 + 0.7 * col;
    fragColor = vec4(col * intensity * (0.7 + 0.6 * bass), 1.0);
}
