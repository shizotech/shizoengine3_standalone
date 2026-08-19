// ==== Custom Uniform Controls ====

//@rgb value=(0.2,0.0,0.5)
uniform vec3 colorA;

//@rgb value=(1.0,0.9,0.2)
uniform vec3 colorB;

//@float min=0.1 max=3.0 value=1.0
uniform float contrast;

//@float min=0.0 max=0.5 value=0.05
uniform float preserve_black_threshold;

//@float min=0.0 max=0.2 value=0.02
uniform float preserve_fade;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    vec3 col = texture(iChannel0, uv).rgb;

    // Compute luminance (perceived brightness)
    float lum = dot(col, vec3(0.299, 0.587, 0.114));

    // Adjust luminance using contrast control
    float mappedLum = pow(lum, contrast);

    // Colorize based on luminance
    vec3 colorized = mix(colorA, colorB, mappedLum);

    // Preserve black: blend toward black for very dark areas
    float preserve = smoothstep(preserve_black_threshold, 
                                preserve_black_threshold + preserve_fade, lum);
    colorized *= preserve;

    fragColor = vec4(colorized, 1.0);
}
