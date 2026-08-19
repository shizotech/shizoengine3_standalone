

//@slider min=0.0 max=1.0 value=0.5
uniform float pixel_sort_threshold;

//@slider min=1 max=100 value=20
uniform float pixel_sort_distance;

//@slider min=0 max=1 value=0
uniform int pixel_sort_direction;

//@slider min=0.0 max=1.0 value=0.8
uniform float pixel_sort_intensity;

//@slider min=0.0 max=1.0 value=0.5
uniform float pixel_sort_color_hold;

//@slider min=0 max=3 value=0
uniform int pixel_sort_lum_func;



float calculateLuminance(vec3 color) {
    if (pixel_sort_lum_func == 0) {
        // RGB average
        return (color.r + color.g + color.b) / 3.0;
    } else if (pixel_sort_lum_func == 1) {
        // Grayscale
        return dot(color, vec3(0.299, 0.587, 0.114));
    } else if (pixel_sort_lum_func == 2) {
        // Max channel
        return max(max(color.r, color.g), color.b);
    } else {
        // Min channel
        return min(min(color.r, color.g), color.b);
    }
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    fragColor = vec4(0,0,0,0);
    vec2 uv = fragCoord / iResolution.xy;
    vec3 currentColor = texture(iChannel0, uv).rgb;
    float luminance = calculateLuminance(currentColor);
    
    if (luminance > pixel_sort_threshold) {
        vec3 sortedColor = currentColor;
        
        if (pixel_sort_direction == 0) {
            // Horizontal sort
            for (float i = 1.0; i <= pixel_sort_distance; i++) {
                vec2 offset_uv = uv + vec2(i / textureSize(iChannel0, 0).x, 0.0);
                if (offset_uv.x > 1.0) break;
                
                vec3 neighborColor = texture(iChannel0, offset_uv).rgb;
                float neighborLum = calculateLuminance(neighborColor);

                if (neighborLum > luminance) {
                    float blend = pixel_sort_intensity;
                    sortedColor = mix(sortedColor, neighborColor, blend * pixel_sort_color_hold);
                }
            }
        } else {
            // Vertical sort
            for (float i = 1.0; i <= pixel_sort_distance; i++) {
                vec2 offset_uv = uv + vec2(0.0, i / textureSize(iChannel0, 0).y);
                if (offset_uv.y > 1.0) break;
                
                vec3 neighborColor = texture(iChannel0, offset_uv).rgb;
                float neighborLum = calculateLuminance(neighborColor);

                if (neighborLum > luminance) {
                    float blend = pixel_sort_intensity;
                    sortedColor = mix(sortedColor, neighborColor, blend * pixel_sort_color_hold);
                }
            }
        }
        
        fragColor = vec4(sortedColor, texture(iChannel0, uv).a);
    } else {
        fragColor = texture(iChannel0, uv);
    }
}
