//@slider min=-180.0 max=180.0 value=0.0
uniform float hsv_hue;

//@slider min=0.0 max=3.0 value=1.0
uniform float hsv_saturation;

//@slider min=0.0 max=3.0 value=1.0
uniform float hsv_value;

//@slider min=0.0 max=1.0 value=0.5
uniform float hsv_lum_threshold;

//@slider min=0.0 max=1.0 value=1.0
uniform float hsv_range_select;

//@slider min=0.0 max=360.0 value=0.0
uniform float hsv_target_hue;

//@slider min=0 max=2 value=0
uniform int hsv_clip;

uniform sampler2D hsv_input;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, 1.0/3.0, 2.0/3.0, -1.0/3.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(c.r, p.xyw), vec4(p.xyw, c.r), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 color = texture(hsv_input, uv);
    vec3 rgb = color.rgb;
    
    // Convert to HSV
    vec3 hsv = rgb2hsv(rgb);
    
    // Store original HSV for range select mixing
    vec3 original_hsv = hsv;
    
    // Apply hue shift
    hsv.x = fract(hsv.x + hsv_hue / 360.0);
    
    // Apply saturation
    hsv.y *= hsv_saturation;
    hsv.y = clamp(hsv.y, 0.0, 1.0);
    
    // Apply value
    hsv.z *= hsv_value;
    hsv.z = clamp(hsv.z, 0.0, 1.0);
    
    // Range select - only modify pixels within hue range
    if (hsv_range_select < 1.0) {
        float target_h = fract(hsv_target_hue / 360.0);
        float hue_diff = abs(original_hsv.x - target_h);
        hue_diff = min(hue_diff, 1.0 - hue_diff);
        float range_mask = smoothstep(hsv_range_select * 0.5, 0.0, hue_diff);
        hsv.x = mix(hsv.x, original_hsv.x, range_mask);
        hsv.y = mix(hsv.y, original_hsv.y, range_mask);
        hsv.z = mix(hsv.z, original_hsv.z, range_mask);
    }
    
    // Apply luminance threshold mask
    if (hsv_lum_threshold < 1.0) {
        float lum_mask = smoothstep(hsv_lum_threshold, 1.0, hsv.z);
        vec3 orig_hsv = rgb2hsv(rgb);
        hsv.x = mix(orig_hsv.x, hsv.x, lum_mask);
        hsv.y = mix(orig_hsv.y, hsv.y, lum_mask);
        hsv.z = mix(orig_hsv.z, hsv.z, lum_mask);
    }
    
    // Convert back to RGB
    vec3 output = hsv2rgb(hsv);
    
    // Apply clip
    if (hsv_clip == 1) {
        output = max(output, 0.0); // clip low
    } else if (hsv_clip == 2) {
        output = min(output, 1.0); // clip high
    }
    
    fragColor = vec4(output, color.a);
}
