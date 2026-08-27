//@settings dtype=float32 format=rgba

//@slider min=0.0 max=3.0 value=0.5
uniform float speed;
//@slider min=1.0 max=12.0 value=6.0
uniform float rings;
//@rgb value=(0.2,1.0,0.9)
uniform vec3 ring_color;
//@slider min=0.0 max=2.0 value=1.0
uniform float glow;
//@slider min=0.0 max=1.0 value=0.5
uniform float pulse;
//@slider min=1.0 max=8.0 value=6.0
uniform float symmetry;

float audio(float x) {
    return texture(iChannel0, vec2(x, 0.0)).x;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord.xy - 0.5 * iResolution.xy) / iResolution.y;
    float t = iTime * speed;

    float bass = audio(0.0);
    float mid  = audio(0.5);

    float ang = atan(uv.x, uv.y);
    float rad = length(uv) + 0.2;

    float sym = symmetry;
    float sector = 6.2831853 / sym;
    float folded = mod(ang + t * 0.2, sector) - sector * 0.5;

    float ringsPulse = 1.0 + pulse * bass;
    float ringPhase = rad * rings * ringsPulse - t * 3.0;
    float ring = 0.5 + 0.5 * sin(ringPhase);
    ring = pow(ring, 2.0 + 4.0 * mid);

    float edgeFade = smoothstep(1.2, 0.4, length(uv));

    vec3 col = ring_color * ring * glow;
    col += ring_color * 0.15 * smoothstep(0.0, 1.0, 1.0 - abs(folded / sector));

    fragColor = vec4(col * edgeFade * (0.8 + 0.5 * bass), 1.0);
}
