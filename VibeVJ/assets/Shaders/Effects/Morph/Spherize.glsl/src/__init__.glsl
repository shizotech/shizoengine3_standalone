//@slider min=0.0 max=1.0 value=0.3
uniform float spherize_radius;

//@slider min=-2.0 max=2.0 value=1.0
uniform float spherize_strength;

//@slider min=0.0 max=1.0 value=0.5
uniform float spherize_center_x;

//@slider min=0.0 max=1.0 value=0.5
uniform float spherize_center_y;

//@slider min=-3.14 max=3.14 value=0.0
uniform float spherize_3d_rot_x;

//@slider min=-3.14 max=3.14 value=0.0
uniform float spherize_3d_rot_y;

//@slidervec2 min=0.0 max=1.0 value=0.7,0.7
uniform vec2 spherize_light_dir;

//@slider min=0.0 max=2.0 value=0.5
uniform float spherize_highlight;

uniform sampler2D tex;

vec3 calculateLighting(vec3 normal, vec2 light_dir, float highlight) {
    vec3 light = normalize(vec3(light_dir, 1.0));
    float diff = max(dot(normal, light), 0.0);
    float ambient = 0.3;
    
    // Specular highlight
    vec3 view_dir = vec3(0.0, 0.0, 1.0);
    vec3 half_dir = normalize(light + view_dir);
    float spec = pow(max(dot(normal, half_dir), 0.0), 32.0);
    
    return vec3(ambient + diff * 0.7 + spec * highlight);
}

// 3D rotation matrices
vec3 rotateX(vec3 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

vec3 rotateY(vec3 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    
    // Calculate offset from center
    vec2 center = vec2(spherize_center_x, spherize_center_y);
    vec2 offset = uv - center;
    float dist = length(offset);
    
    // Normalize distance
    float norm_dist = dist / (spherize_radius * 2.0);
    norm_dist = clamp(norm_dist, 0.0, 1.0);
    
    // Spherize displacement - projects 2D onto sphere
    float displacement = 0.0;
    if (norm_dist <= 1.0) {
        // Sphere projection formula
        displacement = sin(norm_dist * 3.14159265 * 0.5) * spherize_strength;
    }
    
    // Apply displacement
    vec2 new_uv;
    if (dist > 0.001) {
        new_uv = center + normalize(offset) * dist * (1.0 + displacement);
    } else {
        new_uv = center;
    }
    
    // Calculate 3D normal for lighting using finite differences
    vec2 dx = vec2(0.001, 0.0);
    vec2 dy = vec2(0.0, 0.001);
    
    vec2 offset_x = (uv + dx) - center;
    vec2 offset_y = (uv + dy) - center;
    float dist_x = length(offset_x);
    float dist_y = length(offset_y);
    
    float disp_x = 0.0;
    float disp_y = 0.0;
    if (dist_x / (spherize_radius * 2.0) <= 1.0) {
        disp_x = sin((dist_x / (spherize_radius * 2.0)) * 3.14159265 * 0.5) * spherize_strength;
    }
    if (dist_y / (spherize_radius * 2.0) <= 1.0) {
        disp_y = sin((dist_y / (spherize_radius * 2.0)) * 3.14159265 * 0.5) * spherize_strength;
    }
    
    vec2 new_uv_x;
    vec2 new_uv_y;
    if (dist_x > 0.001) {
        new_uv_x = center + normalize(offset_x) * dist_x * (1.0 + disp_x);
    } else {
        new_uv_x = center + dx;
    }
    if (dist_y > 0.001) {
        new_uv_y = center + normalize(offset_y) * dist_y * (1.0 + disp_y);
    } else {
        new_uv_y = center + dy;
    }
    
    // Calculate surface normal from UV displacement
    vec2 duv_x = new_uv_x - new_uv;
    vec2 duv_y = new_uv_y - new_uv;
    
    vec3 normal;
    normal.x = duv_y.y;
    normal.y = -duv_y.x;
    normal.z = duv_x.x * duv_y.y - duv_x.y * duv_y.x;
    normal = normalize(normal);
    
    // Apply 3D rotation to the normal
    normal = rotateX(normal, spherize_3d_rot_x);
    normal = rotateY(normal, spherize_3d_rot_y);
    
    // Sample texture at distorted UV
    vec4 color = vec4(0.0);
    if (new_uv.x >= 0.0 && new_uv.x <= 1.0 && new_uv.y >= 0.0 && new_uv.y <= 1.0) {
        color = texture(tex, new_uv);
    }
    
    // Apply lighting based on rotated normal
    vec3 lighting = calculateLighting(normal, spherize_light_dir, spherize_highlight);
    
    color.rgb *= lighting;
    
    fragColor = color;
}