// TV Bubble/Arc Effect
// Shadertoy format

uniform float time;
uniform vec2 resolution;

//@slider min=0.01 max=3.0 value=0.5
uniform float bubble_speed;

//@slider min=1 max=20 value=5
uniform int bubble_count;

//@rgb value=(0.8,0.4,1.0)
uniform vec3 bubble_colors;

//@slider min=0.01 max=0.5 value=0.15
uniform float bubble_size;

//@slider min=0.0 max=2.0 value=0.5
uniform float bubble_stroke;

//@slider min=0.0 max=1.0 value=0.3
uniform float bubble_wobble;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / resolution;
    
    vec3 color = vec3(0.0);
    
    for (int i = 0; i < 20; i++) {
        if (i >= bubble_count) break;
        
        float t = float(i);
        float bubble_time = time * bubble_speed + t * 0.7;
        
        // Create bubble positions - moving arcs from bottom to top
        float angle = t * 0.5 + bubble_time * 0.3;
        float x_pos = 0.5 + sin(angle) * 0.3;
        float y_pos = fract(bubble_time * 0.1 + t * 0.1);
        
        // Add wobble
        x_pos += sin(bubble_time * 2.0 + t) * bubble_wobble * 0.1;
        y_pos += cos(bubble_time * 1.5 + t * 0.5) * bubble_wobble * 0.05;
        
        // Distance from bubble center
        vec2 diff = uv - vec2(x_pos, y_pos);
        float dist = length(diff);
        
        // Bubble ring
        float ring = abs(dist - bubble_size) / bubble_stroke;
        float bubble = 1.0 - smoothstep(0.0, 1.0, ring);
        
        // Arc effect - only show part of the bubble
        float arc_angle = atan(diff.y, diff.x);
        float arc = smoothstep(0.5, 0.0, abs(arc_angle - bubble_time));
        bubble *= arc;
        
        // Color with gradient
        float hue = fract(t * 0.1 + bubble_time * 0.05);
        vec3 bubble_color = hsv2rgb(vec3(hue, 0.8, 1.0)) * bubble_colors;
        
        color += bubble * bubble_color;
    }
    
    fragColor = vec4(color, 1.0);
}