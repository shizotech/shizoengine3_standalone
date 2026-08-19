//@settings dtype=float32 format=rgba

#include shared_utils.glsl

uniform sampler2D input1;

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
        vec2 nuv = uv+vec2(f*factor, 0.);
        if (nuv.x > 0. && nuv.x < 1.)
          col += texture(input1, uv+vec2(f*factor,0.)).xyz/float(steps);
    }
    fragColor = vec4(col,1.0);
}
