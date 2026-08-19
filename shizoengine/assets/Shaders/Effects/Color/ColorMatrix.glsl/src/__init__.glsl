// ==== Custom Uniform Controls ====

//@rgb value=(1.0,0.0,0.0)
uniform vec3 cm_r;

//@rgb value=(0.0,1.0,0.0)
uniform vec3 cm_g;

//@rgb value=(0.0,0.0,1.0)
uniform vec3 cm_b;

//@rgb value=(0.0,0.0,0.0)
uniform vec3 cm_offset;

//@slider min=0.0 max=3.0 value=1.0
uniform float cm_contrast;

//@slider min=-1.0 max=1.0 value=0.0
uniform float cm_brightness;

/**
 * Color Matrix Transform
 * Applies a full 3x3 color matrix transformation with controls
 * for channel mixing, offset, contrast, and brightness.
 * Shadertoy format.
 */

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 color = texture(iChannel0, uv);
    vec3 pixel = color.rgb;
    
    // Apply contrast around center
    pixel = (pixel - 0.5) * cm_contrast + 0.5;
    
    // Apply color matrix transformation
    vec3 output;
    output.r = dot(cm_r, pixel);
    output.g = dot(cm_g, pixel);
    output.b = dot(cm_b, pixel);
    
    // Apply offset
    output += cm_offset;
    
    // Apply brightness
    output += cm_brightness;
    
    fragColor = vec4(output, color.a);
}