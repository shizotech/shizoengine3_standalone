//@settings dtype=float32 format=rgba

#include shared_utils.glsl

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;
    const int steps = GLOW_SAMPLES;
    vec3 col = vec3(0.);
    
    for (int i = 0; i< steps; ++i)
    {
        float f = float(i)/float(steps);
        f = (f -.5)*2.;
        float factor = GLOW_DISTANCE;
        vec2 nuv = uv+vec2(0.,f*factor);
        if (nuv.y > 0. && nuv.y < 1.)
            col += texture(iChannel0, uv+vec2(0.,f*factor)).xyz/float(steps);
    }
    
    vec3 rgb = texture(iChannel1, uv).xyz+GLOW_OPACITY*pow(col, vec3(GLOW_POW));
    rgb = pow(rgb*1.2, vec3(2.2));
    vec2 cuv = (fragCoord-.5*iResolution.xy)/iResolution.xx;
    
    fragColor = vec4(rgb,1.0);
}
