// Pixel Sorting Effect
// Non-Shadertoy format with uniform sampler2D input

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

uniform sampler2D input;

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

void main() {
    vec2 uv = v_uv;
    vec3 currentColor = texture(input, uv).rgb;
    vec3 luminance = calculateLuminance(currentColor);
    
    if (luminance.r > pixel_sort_threshold) {
        vec3 sortedColor = currentColor;
        
        if (pixel_sort_direction == 0) {
            // Horizontal sort
            for (float i = 1.0; i <= pixel_sort_distance; i++) {
                vec2 offset_uv = uv + vec2(i / textureSize(input, 0).x, 0.0);
                if (offset_uv.x > 1.0) break;
                
                vec3 neighborColor = texture(input, offset_uv).rgb;
                vec3 neighborLum = calculateLuminance(neighborColor);
                
                if (neighborLum.r > luminance.r) {
                    float blend = pixel_sort_intensity;
                    sortedColor = mix(sortedColor, neighborColor, blend * pixel_sort_color_hold);
                }
            }
        } else {
            // Vertical sort
            for (float i = 1.0; i <= pixel_sort_distance; i++) {
                vec2 offset_uv = uv + vec2(0.0, i / textureSize(input, 0).y);
                if (offset_uv.y > 1.0) break;
                
                vec3 neighborColor = texture(input, offset_uv).rgb;
                vec3 neighborLum = calculateLuminance(neighborColor);
                
                if (neighborLum.r > luminance.r) {
                    float blend = pixel_sort_intensity;
                    sortedColor = mix(sortedColor, neighborColor, blend * pixel_sort_color_hold);
                }
            }
        }
        
        fragColor = vec4(sortedColor, texture(input, uv).a);
    } else {
        fragColor = texture(input, uv);
    }
}
