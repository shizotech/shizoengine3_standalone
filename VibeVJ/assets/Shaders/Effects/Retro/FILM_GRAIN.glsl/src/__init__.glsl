


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;
    
    vec3 col = texture(iChannel0, uv).rgb;

    float invLum = clamp(1.0 - dot(vec3(0.299,0.587,0.114), col), 0.0, 1.0);

    float seed = (uv.x + 4.0) * (uv.y + 4.0) * (mod(iTime,10.0) + 12342.876);
    float grainR = fract((mod(seed, 13.0) + 1.0) * (mod(seed, 127.0) + 1.0)) - 0.5;
    float grainG = fract((mod(seed, 15.0) + 1.0) * (mod(seed, 109.0) + 1.0)) - 0.5;
    float grainB = fract((mod(seed,  7.0) + 1.0) * (mod(seed, 113.0) + 1.0)) - 0.5;
    vec3 grain = vec3(grainR, grainG, grainB);    
    
    grain *= smoothstep(0.1, 0.7, invLum*invLum);

    fragColor = vec4(col + 0.21 * grain, 1.0);
}
