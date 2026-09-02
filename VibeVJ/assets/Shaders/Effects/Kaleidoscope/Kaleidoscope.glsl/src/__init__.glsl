// Kaleidoscope Effect
// Shadertoy format

//@slider min=2 max=16 value=8
uniform int kalie_segments;

//@slider min=-3.14 max=3.14 value=0.0
uniform float kalie_rotation;

//@slider min=0 max=2 value=1
uniform int kalie_mirror;

//@slider min=0.1 max=5.0 value=1.0
uniform float kalie_zoom;

//@slider min=0.0 max=2.0 value=0.5
uniform float kalie_speed;

//@slider min=0.0 max=1.0 value=0.5
uniform float kalie_offset_x;

//@slider min=0.0 max=1.0 value=0.5
uniform float kalie_offset_y;

//@slider min=0.0 max=1.0 value=0.0
uniform float kalie_blur;

uniform sampler2D input;

vec3 kaleidoscope(vec2 uv, float segments, float rotation, int mirror, float zoom, float time, float blur, float offset_x, float offset_y) {
    vec2 center = vec2(offset_x, offset_y);
    vec2 centered_uv = (uv - center) * zoom + center;
    
    float angle = atan(centered_uv.y - center.y, centered_uv.x - center.x);
    float dist = length(centered_uv - center);
    
    float segment_angle = 3.14159265358979 * 2.0 / segments;
    float rot = rotation + time * kalie_speed * 0.3;
    
    angle = mod(angle + rot, segment_angle);
    
    if (mirror == 1) {
        if (angle > segment_angle * 0.5) {
            angle = segment_angle - angle;
        }
    } else if (mirror == 2) {
        float bloom_shift = sin(time * kalie_speed + dist * 10.0) * 0.1;
        float bloom_angle = angle + bloom_shift;
        angle = mod(bloom_angle, segment_angle);
        if (angle > segment_angle * 0.5) {
            angle = segment_angle - angle;
        }
    }
    
    angle = angle + segment_angle * 0.5;
    
    vec2 new_uv;
    new_uv.x = dist * cos(angle) + center.x;
    new_uv.y = dist * sin(angle) + center.y;
    
    if (blur > 0.0) {
        vec3 color = vec3(0.0);
        float samples = 5.0;
        float offset_amt = blur * 0.003;
        for (float i = -2.0; i <= 2.0; i++) {
            vec2 sample_uv = new_uv + vec2(i * offset_amt, i * offset_amt * 0.5);
            if (sample_uv.x >= 0.0 && sample_uv.x <= 1.0 && sample_uv.y >= 0.0 && sample_uv.y <= 1.0) {
                color += texture(input, sample_uv).rgb;
            }
        }
        color /= samples;
        return color;
    }
    
    if (new_uv.x >= 0.0 && new_uv.x <= 1.0 && new_uv.y >= 0.0 && new_uv.y <= 1.0) {
        return texture(input, new_uv).rgb;
    }
    
    return vec3(0.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime * kalie_speed;
    
    vec3 color = kaleidoscope(uv, float(kalie_segments), kalie_rotation, kalie_mirror, kalie_zoom, time, kalie_blur, kalie_offset_x, kalie_offset_y);
    
    fragColor = vec4(color, 1.0);
}
