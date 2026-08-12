// FILM_GRAIN2 - FX Shader
// Original: old/FILM_GRAIN2.ogl

float rand(vec2 uv, float t) {
    return fract(sin(dot(uv, vec2(1225.6548, 321.8942))) * 4251.4865 + t);
}

void mainImage(out vec4 color, vec2 coord) {
    vec2 ps = vec2(1.0) / iResolution.xy;
    vec2 uv = coord * ps;
    
    float scale = 50.0;
    if (iMouse.z > 0.0)
        scale *= iMouse.x * ps.x * 2.0;
    
    vec2 offset = (rand(uv, iTime) - 0.5) * 2.0 * ps * scale;
    
    vec3 noise = texture(iChannel0, uv + offset).rgb;
    color = texture(iChannel0, uv);
    
    float amount = 0.5;
    if (iMouse.z > 0.0)
        amount = iMouse.y * ps.y;
    
    color.rgb = mix(color.rgb, noise, amount);
}
