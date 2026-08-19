
// ==== Custom Uniform Controls ===
//@slider min=0.0 max=2.0 value=1.0
uniform float fisheye_strength;

//@slider min=10.0 max=180.0 value=90.0
uniform float fisheye_fov;

//@slider min=0.0 max=1.0 value=0.5
uniform float fisheye_center_x;

//@slider min=0.0 max=1.0 value=0.5
uniform float fisheye_center_y;

//@slider min=0.0 max=1.0 value=0.0
uniform float fisheye_asymmetric;

//@slider min=-1.0 max=1.0 value=0.0
uniform float fisheye_barrel;

//@slider min=0.0 max=3.0 value=1.0
uniform float fisheye_vignette;

//@slider min=0.0 max=1.0 value=0.0
uniform float fisheye_chromatic;

uniform sampler2D in;

/**
 * Fisheye Lens Distortion Effect
 */
// Custom format.

void main() {
    vec2 uv = v_uv;
    
    // Calculate offset from center
    vec2 center = vec2(fisheye_center_x, fisheye_center_y);
    vec2 offset = uv - center;
    
    // Add asymmetric distortion
    offset.x *= 1.0 + fisheye_asymmetric * offset.y;
    offset.y *= 1.0 + fisheye_asymmetric * offset.x;
    
    float dist = length(offset);
    float angle = atan(offset.y, offset.x);
    
    // Fisheye distortion using fov
    float fov_rad = fisheye_fov * 3.14159265 / 180.0;
    float norm_dist = dist * 2.0;
    
    // Barrel/pincushion distortion
    float barrel_dist = 1.0 + fisheye_barrel * norm_dist * norm_dist;
    
    // Apply fisheye projection
    float fisheye_radius = 0.5 * sin(fov_rad * 0.5) / sin(3.14159265 * 0.5 - fov_rad * 0.5);
    float r = atan(norm_dist, 1.0) * fisheye_strength * fisheye_radius * 2.0;
    r *= barrel_dist;
    
    // Map back to texture coordinates
    vec2 new_uv = center + vec2(cos(angle) * r, sin(angle) * r);
    
    // Chromatic aberration
    vec3 color;
    if (fisheye_chromatic > 0.0) {
        float aberration = fisheye_chromatic * dist;
        vec2 aberration_offset = normalize(offset) * aberration / textureSize(in, 0).xy;
        
        float r_ch = texture(in, new_uv + aberration_offset).r;
        float g = texture(in, new_uv).g;
        float b_ch = texture(in, new_uv - aberration_offset).b;
        
        color = vec3(r_ch, g, b_ch);
    } else {
        color = texture(in, new_uv).rgb;
    }
    
    // Vignette effect
    float vignette_dist = length(uv - center) * fisheye_vignette;
    float vignette = 1.0 - vignette_dist;
    vignette = clamp(vignette, 0.0, 1.0);
    
    color *= vignette;
    
    fragColor = vec4(color, texture(in, uv).a);
}