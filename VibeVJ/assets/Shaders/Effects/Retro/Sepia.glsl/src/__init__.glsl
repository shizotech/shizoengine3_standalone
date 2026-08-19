// ==== Custom Uniform Controls ====

//@float min=0.0 max=1.0 value=1.0
uniform float sepia_intensity;

//@float min=0.0 max=2.0 value=1.0
uniform float sepia_brightness;

//@float min=0.0 max=2.0 value=1.0
uniform float sepia_contrast;

//@float min=0.0 max=1.0 value=0.5
uniform float blend;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    vec4 input = texture2D(iChannel0, uv);
    vec3 color = input.rgb;

    // Apply contrast
    color = (color - 0.5) * sepia_contrast + 0.5;

    // Sepia transform matrix
    float r = dot(color, vec3(0.393, 0.769, 0.189));
    float g = dot(color, vec3(0.349, 0.686, 0.168));
    float b = dot(color, vec3(0.272, 0.534, 0.131));

    vec3 sepia_color = vec3(r, g, b);

    // Apply brightness
    sepia_color *= sepia_brightness;

    // Blend between original and sepia
    vec3 final_color = mix(color, sepia_color, sepia_intensity * blend);

    fragColor = vec4(final_color, input.a);
}