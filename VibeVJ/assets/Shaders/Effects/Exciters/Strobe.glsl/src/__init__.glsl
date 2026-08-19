// ==== Custom Uniform Controls ====

//@int min=0 max=1 value=1
uniform int enable_strobe;

//@int min=1 max=120 value=30
uniform int clean_frames;

//@int min=1 max=60 value=5
uniform int strobe_frames;

//@rgb value=(1.0,1.0,1.0)
uniform vec3 strobe_color;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    // Sample the original image from iChannel0
    vec4 original = texture(iChannel0, uv);

    // Default to original color
    vec3 resultColor = original.rgb;

    if (enable_strobe == 1)
    {
        int totalCycle = clean_frames + strobe_frames;
        int cyclePos = int(mod(float(iFrame), float(totalCycle)));

        // If we are in strobe phase, override with flash color
        if (cyclePos >= clean_frames)
        {
            resultColor = strobe_color;
        }
    }

    fragColor = vec4(resultColor, original.a);
}
