//@settings dtype=float32 format=rgba

// HG_SDF rotate function
#define r(p, a) {p = cos(a)*p + sin(a)*vec2(p.y,-p.x);}

// Cabbibo's HSV
vec3 hsv(float h, float s, float v) {
    return mix(vec3(1.0), clamp((abs(fract(h + vec3(3.0, 2.0, 1.0) / 3.0) * 6.0 - 3.0) - 1.0), 0.0, 1.0), s) * v;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float T = iTime;
    float PSD = abs(texture(iChannel0, vec2(0.5)).r) * abs(texture(iChannel0, vec2(0.5)).r);
    
    vec2 u = (-iResolution.xy + 2.0 * fragCoord.xy) / iResolution.y;
    vec3 ro = vec3(u, 1.0), rd = normalize(vec3(u, -1.0)), p;
    float d = 0.0, m;
    
    for (float i = 1.0; i > 0.0; i -= 0.02) {
        p = ro + rd * d;
        r(p.zy, T);
        r(p.zx, T);
        m = length(cos(abs(p) + sin(abs(p)) + T)) - (PSD + 0.5);
        d += m;
        fragColor = vec4(hsv(T, 1.0, 1.0) * i * i, 1.0);
        if (m < 0.02) break;
    }
}
