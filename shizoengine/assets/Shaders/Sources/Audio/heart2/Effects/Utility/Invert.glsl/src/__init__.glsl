// ==== Custom Uniform Controls ====

//@float min=0.0 max=1.0 value=1.0
uniform float invert_amount;

//@int min=0 max=1 value=0
uniform int invert_selective;

//@enum options=(RGB, R, G, B, A)
uniform int invert_channels;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    vec4 input = texture2D(iChannel0, uv);
    vec3 color = input.rgb;

    if (invert_selective == 0)
    {
        // Full inversion
        color = 1.0 - color;
    }
    else
    {
        // Selective channel inversion based on invert_channels
        if (invert_channels == 1) // R
        {
            color.r = 1.0 - color.r;
        }
        else if (invert_channels == 2) // G
        {
            color.g = 1.0 - color.g;
        }
        else if (invert_channels == 3) // B
        {
            color.b = 1.0 - color.b;
        }
        else if (invert_channels == 0) // RGB (same as full)
        {
            color = 1.0 - color;
        }
    }

    color = mix(input.rgb, color, invert_amount);

    fragColor = vec4(color, input.a);
}