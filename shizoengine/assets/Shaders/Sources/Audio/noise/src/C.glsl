//@settings dtype=float32 format=rgba

#include helpers/shared.glsl

// Resolution reduction and horizontal blur

// shout-outs to https://twitter.com/mattdesl
// https://github.com/mattdesl/lwjgl-basics/wiki/shaderlesson5

vec4 blur_horizontal(sampler2D channel, vec2 uv, float scale)
{
    float h = scale / iResolution.x;
    vec4 sum = vec4(0.0);

    sum += texture(channel, fract(vec2(uv.x - 4.0*h, uv.y)) ) * 0.0162162162;
    sum += texture(channel, fract(vec2(uv.x - 3.0*h, uv.y)) ) * 0.0540540541;
    sum += texture(channel, fract(vec2(uv.x - 2.0*h, uv.y)) ) * 0.1216216216;
    sum += texture(channel, fract(vec2(uv.x - 1.0*h, uv.y)) ) * 0.1945945946;
    sum += texture(channel, fract(vec2(uv.x + 0.0*h, uv.y)) ) * 0.2270270270;
    sum += texture(channel, fract(vec2(uv.x + 1.0*h, uv.y)) ) * 0.1945945946;
    sum += texture(channel, fract(vec2(uv.x + 2.0*h, uv.y)) ) * 0.1216216216;
    sum += texture(channel, fract(vec2(uv.x + 3.0*h, uv.y)) ) * 0.0540540541;
    sum += texture(channel, fract(vec2(uv.x + 4.0*h, uv.y)) ) * 0.0162162162;

    return sum;
}

vec4 blur_horizontal_left_column(vec2 uv, int depth)
{
    float h = pow(2., float(depth)) / iResolution.x;    
    vec2 uv1, uv2, uv3, uv4, uv5, uv6, uv7, uv8, uv9;

    uv1 = fract(vec2(uv.x - 4.0 * h, uv.y) * 2.);
    uv2 = fract(vec2(uv.x - 3.0 * h, uv.y) * 2.);
    uv3 = fract(vec2(uv.x - 2.0 * h, uv.y) * 2.);
    uv4 = fract(vec2(uv.x - 1.0 * h, uv.y) * 2.);
    uv5 = fract(vec2(uv.x + 0.0 * h, uv.y) * 2.);
    uv6 = fract(vec2(uv.x + 1.0 * h, uv.y) * 2.);
    uv7 = fract(vec2(uv.x + 2.0 * h, uv.y) * 2.);
    uv8 = fract(vec2(uv.x + 3.0 * h, uv.y) * 2.);
    uv9 = fract(vec2(uv.x + 4.0 * h, uv.y) * 2.);

    if(uv.y > 0.5)
    {
        uv1 = upper_left(uv1);
        uv2 = upper_left(uv2);
        uv3 = upper_left(uv3);
        uv4 = upper_left(uv4);
        uv5 = upper_left(uv5);
        uv6 = upper_left(uv6);
        uv7 = upper_left(uv7);
        uv8 = upper_left(uv8);
        uv9 = upper_left(uv9);
    }
    else{
        uv1 = lower_left(uv1);
        uv2 = lower_left(uv2);
        uv3 = lower_left(uv3);
        uv4 = lower_left(uv4);
        uv5 = lower_left(uv5);
        uv6 = lower_left(uv6);
        uv7 = lower_left(uv7);
        uv8 = lower_left(uv8);
        uv9 = lower_left(uv9);
    }

    for(int level = 0; level < 8; level++)
    {
        if(level >= depth)
        {
            break;
        }

        uv1 = lower_right(uv1);
        uv2 = lower_right(uv2);
        uv3 = lower_right(uv3);
        uv4 = lower_right(uv4);
        uv5 = lower_right(uv5);
        uv6 = lower_right(uv6);
        uv7 = lower_right(uv7);
        uv8 = lower_right(uv8);
        uv9 = lower_right(uv9);
    }

    vec4 sum = vec4(0.0);

    sum += texture(iChannel3, uv1) * 0.05;
    sum += texture(iChannel3, uv2) * 0.09;
    sum += texture(iChannel3, uv3) * 0.12;
    sum += texture(iChannel3, uv4) * 0.15;
    sum += texture(iChannel3, uv5) * 0.16;
    sum += texture(iChannel3, uv6) * 0.15;
    sum += texture(iChannel3, uv7) * 0.12;
    sum += texture(iChannel3, uv8) * 0.09;
    sum += texture(iChannel3, uv9) * 0.05;

    return sum/0.98;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    if(uv.x < 0.5)
    {
        vec2 uv_half = fract(uv*2.);
        if(uv.y > 0.5)
        {
            fragColor = blur_horizontal(iChannel0, uv_half, 1.);
        }
        else
        {
            fragColor = blur_horizontal(iChannel1, uv_half, 1.);
        }
    }
    else
    {
        for(int level = 0; level < 8; level++)
        {
            if((uv.x > 0.5 && uv.y > 0.5) || (uv.x <= 0.5))
            {
                break;
            }
            vec2 uv_half = fract(uv*2.);
            fragColor = blur_horizontal_left_column(uv_half, level);
            uv = uv_half;
        }
    }
}